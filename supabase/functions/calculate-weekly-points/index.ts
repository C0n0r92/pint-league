import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

/**
 * Calculate Weekly Points Edge Function
 * 
 * Runs via Supabase Cron every Monday at 1 AM UTC to calculate
 * the previous week's points for all users.
 * 
 * Scoring Rules:
 * - Base: 10 points per pint
 * - Unique pub bonus: +5 points for first pint at a new pub
 * - Social bonus: +2 points per friend tagged
 * - Streak bonus: +10 points for 3+ day streak, +25 for 7+ days
 * - Verification bonus: +3 points for bank-verified pints
 */

interface ScoringRules {
  pointsPerPint: number
  uniquePubBonus: number
  socialBonusPerTag: number
  streak3Bonus: number
  streak7Bonus: number
  verificationBonus: number
}

const SCORING_RULES: ScoringRules = {
  pointsPerPint: 10,
  uniquePubBonus: 5,
  socialBonusPerTag: 2,
  streak3Bonus: 10,
  streak7Bonus: 25,
  verificationBonus: 3,
}

Deno.serve(async (req) => {
  // This function should only be called by cron or service role
  const authHeader = req.headers.get('Authorization')
  
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  // Get the week to calculate (previous week by default)
  const now = new Date()
  const daysSinceMonday = (now.getUTCDay() + 6) % 7 // 0 = Monday
  const thisMonday = new Date(now)
  thisMonday.setUTCDate(now.getUTCDate() - daysSinceMonday)
  thisMonday.setUTCHours(0, 0, 0, 0)
  
  const lastMonday = new Date(thisMonday)
  lastMonday.setUTCDate(lastMonday.getUTCDate() - 7)
  
  const weekStart = lastMonday.toISOString().split('T')[0]
  const weekEnd = thisMonday.toISOString().split('T')[0]
  
  console.log(`Calculating points for week: ${weekStart} to ${weekEnd}`)

  // Get all users who logged pints this week
  const { data: weekPints, error: pintsError } = await supabase
    .from('pints')
    .select('user_id, pub_id, quantity, source, friends_tagged, logged_at')
    .gte('logged_at', weekStart)
    .lt('logged_at', weekEnd)
    .order('user_id')
    .order('logged_at')

  if (pintsError) {
    console.error('Failed to fetch pints:', pintsError)
    return new Response(JSON.stringify({ error: pintsError.message }), { status: 500 })
  }

  // Group by user
  const userPints: Record<string, typeof weekPints> = {}
  for (const pint of weekPints || []) {
    if (!userPints[pint.user_id]) {
      userPints[pint.user_id] = []
    }
    userPints[pint.user_id].push(pint)
  }

  const results: { userId: string; points: number; breakdown: Record<string, number> }[] = []

  // Calculate points for each user
  for (const [userId, pints] of Object.entries(userPints)) {
    // Get user's historical pubs (before this week)
    const { data: historicalPubs } = await supabase
      .from('pints')
      .select('pub_id')
      .eq('user_id', userId)
      .lt('logged_at', weekStart)
      .not('pub_id', 'is', null)
    
    const previousPubIds = new Set((historicalPubs || []).map(p => p.pub_id))
    const weekPubIds = new Set<string>()
    
    let basePoints = 0
    let uniquePubPoints = 0
    let socialPoints = 0
    let verificationPoints = 0

    // Track days with pints for streak calculation
    const daysWithPints = new Set<string>()

    for (const pint of pints) {
      // Base points
      basePoints += pint.quantity * SCORING_RULES.pointsPerPint

      // Track day
      const day = pint.logged_at.split('T')[0]
      daysWithPints.add(day)

      // Unique pub bonus (first time visiting this pub ever OR first time this week)
      if (pint.pub_id) {
        if (!previousPubIds.has(pint.pub_id) && !weekPubIds.has(pint.pub_id)) {
          uniquePubPoints += SCORING_RULES.uniquePubBonus
        }
        weekPubIds.add(pint.pub_id)
      }

      // Social bonus
      if (pint.friends_tagged && pint.friends_tagged.length > 0) {
        socialPoints += pint.friends_tagged.length * SCORING_RULES.socialBonusPerTag
      }

      // Verification bonus (bank-verified)
      if (pint.source === 'bank_auto') {
        verificationPoints += SCORING_RULES.verificationBonus
      }
    }

    // Calculate streak bonus
    let streakPoints = 0
    const sortedDays = Array.from(daysWithPints).sort()
    let maxStreak = 1
    let currentStreak = 1
    
    for (let i = 1; i < sortedDays.length; i++) {
      const prevDate = new Date(sortedDays[i - 1])
      const currDate = new Date(sortedDays[i])
      const diffDays = (currDate.getTime() - prevDate.getTime()) / (1000 * 60 * 60 * 24)
      
      if (diffDays === 1) {
        currentStreak++
        maxStreak = Math.max(maxStreak, currentStreak)
      } else {
        currentStreak = 1
      }
    }

    if (maxStreak >= 7) {
      streakPoints = SCORING_RULES.streak7Bonus
    } else if (maxStreak >= 3) {
      streakPoints = SCORING_RULES.streak3Bonus
    }

    const totalPoints = basePoints + uniquePubPoints + socialPoints + verificationPoints + streakPoints

    const breakdown = {
      base: basePoints,
      unique_pubs: uniquePubPoints,
      social: socialPoints,
      verification: verificationPoints,
      streak: streakPoints,
    }

    // Upsert weekly points
    const { error: upsertError } = await supabase
      .from('weekly_points')
      .upsert({
        user_id: userId,
        week_start: weekStart,
        total_points: totalPoints,
        breakdown,
        updated_at: new Date().toISOString(),
      }, {
        onConflict: 'user_id,week_start',
      })

    if (upsertError) {
      console.error(`Failed to upsert points for ${userId}:`, upsertError)
    } else {
      results.push({ userId, points: totalPoints, breakdown })
    }

    // Update user's total points
    const { data: userProfile } = await supabase
      .from('profiles')
      .select('total_points')
      .eq('id', userId)
      .single()
    
    if (userProfile) {
      await supabase
        .from('profiles')
        .update({ 
          total_points: (userProfile.total_points || 0) + totalPoints,
          updated_at: new Date().toISOString(),
        })
        .eq('id', userId)
    }

    // Update league standings
    const { data: memberships } = await supabase
      .from('league_members')
      .select('id, total_points')
      .eq('user_id', userId)
    
    for (const membership of memberships || []) {
      await supabase
        .from('league_members')
        .update({ 
          weekly_points: totalPoints,
          total_points: (membership.total_points || 0) + totalPoints,
        })
        .eq('id', membership.id)
    }
  }

  // Recalculate league ranks
  const { data: leagues } = await supabase.from('leagues').select('id')
  
  for (const league of leagues || []) {
    const { data: members } = await supabase
      .from('league_members')
      .select('id, total_points')
      .eq('league_id', league.id)
      .order('total_points', { ascending: false })
    
    for (let i = 0; i < (members || []).length; i++) {
      await supabase
        .from('league_members')
        .update({ rank: i + 1 })
        .eq('id', members![i].id)
    }
  }

  return new Response(JSON.stringify({
    success: true,
    week: weekStart,
    usersProcessed: results.length,
    results,
  }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
