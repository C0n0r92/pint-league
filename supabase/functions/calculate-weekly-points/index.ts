// Weekly Points Calculation
// Run via Supabase Cron every Sunday at midnight

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface PointsBreakdown {
  base_pints: number
  unique_pubs: number
  social_bonus: number
  pub_crawl_bonus: number
  monday_bonus: number
  verified_bonus: number
}

Deno.serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  // Calculate week boundaries
  const now = new Date()
  const weekStart = new Date(now)
  weekStart.setDate(now.getDate() - now.getDay() + 1) // Monday
  weekStart.setHours(0, 0, 0, 0)
  
  const weekEnd = new Date(weekStart)
  weekEnd.setDate(weekStart.getDate() + 7)

  console.log(`Calculating points for week: ${weekStart.toISOString()} to ${weekEnd.toISOString()}`)

  // Get all users with pints this week
  const { data: weeklyPints, error: pintsError } = await supabase
    .from('pints')
    .select('user_id, pub_id, quantity, source, logged_at')
    .gte('logged_at', weekStart.toISOString())
    .lt('logged_at', weekEnd.toISOString())

  if (pintsError) {
    console.error('Failed to fetch pints:', pintsError)
    return new Response(JSON.stringify({ error: 'Failed to fetch pints' }), { status: 500 })
  }

  // Group pints by user
  const userPints = new Map<string, typeof weeklyPints>()
  for (const pint of weeklyPints || []) {
    const existing = userPints.get(pint.user_id) || []
    existing.push(pint)
    userPints.set(pint.user_id, existing)
  }

  const results: { user_id: string; points: number }[] = []

  // Calculate points for each user
  for (const [userId, pints] of userPints) {
    const breakdown: PointsBreakdown = {
      base_pints: 0,
      unique_pubs: 0,
      social_bonus: 0,
      pub_crawl_bonus: 0,
      monday_bonus: 0,
      verified_bonus: 0,
    }

    // Base points: 1 point per pint
    const totalPints = pints.reduce((sum, p) => sum + (p.quantity || 1), 0)
    breakdown.base_pints = totalPints

    // Unique pubs bonus: 3 points per unique pub
    const uniquePubs = new Set(pints.map(p => p.pub_id).filter(Boolean))
    breakdown.unique_pubs = uniquePubs.size * 3

    // Pub crawl bonus: 5 points for 3+ pubs in a day
    const pintsByDay = new Map<string, Set<string>>()
    for (const pint of pints) {
      const day = pint.logged_at.split('T')[0]
      const pubs = pintsByDay.get(day) || new Set()
      if (pint.pub_id) pubs.add(pint.pub_id)
      pintsByDay.set(day, pubs)
    }
    for (const [_, pubs] of pintsByDay) {
      if (pubs.size >= 3) {
        breakdown.pub_crawl_bonus += 5
      }
    }

    // Monday bonus: 2 points for drinking on Monday
    const hasMonday = pints.some(p => {
      const date = new Date(p.logged_at)
      return date.getDay() === 1
    })
    if (hasMonday) breakdown.monday_bonus = 2

    // Verified bonus: 1 extra point per verified pint (bank/GPS auto)
    const verifiedCount = pints.filter(p => 
      p.source === 'geo_auto' || p.source === 'bank_auto'
    ).reduce((sum, p) => sum + (p.quantity || 1), 0)
    breakdown.verified_bonus = verifiedCount

    // Social bonus placeholder (would need to check friends_tagged)
    // breakdown.social_bonus = 0

    const totalPoints = 
      breakdown.base_pints +
      breakdown.unique_pubs +
      breakdown.social_bonus +
      breakdown.pub_crawl_bonus +
      breakdown.monday_bonus +
      breakdown.verified_bonus

    // Upsert weekly points
    const { error: upsertError } = await supabase.from('weekly_points').upsert({
      user_id: userId,
      week_start: weekStart.toISOString().split('T')[0],
      total_points: totalPoints,
      breakdown,
      updated_at: new Date().toISOString(),
    }, { onConflict: 'user_id,week_start' })

    if (upsertError) {
      console.error(`Failed to update points for ${userId}:`, upsertError)
    }

    // Update profile total points
    await supabase.rpc('increment_profile_points', {
      user_id_param: userId,
      points_to_add: totalPoints
    }).catch(() => {
      // Fallback if RPC doesn't exist
      supabase.from('profiles')
        .update({ total_points: totalPoints })
        .eq('id', userId)
    })

    // Update league member points
    const { data: memberships } = await supabase
      .from('league_members')
      .select('id, total_points')
      .eq('user_id', userId)

    for (const membership of memberships || []) {
      await supabase.from('league_members').update({
        weekly_points: totalPoints,
        total_points: (membership.total_points || 0) + totalPoints,
      }).eq('id', membership.id)
    }

    results.push({ user_id: userId, points: totalPoints })
  }

  // Update league rankings
  const { data: leagues } = await supabase.from('leagues').select('id')
  
  for (const league of leagues || []) {
    // Get all members ordered by total points
    const { data: members } = await supabase
      .from('league_members')
      .select('id')
      .eq('league_id', league.id)
      .order('total_points', { ascending: false })

    // Update ranks
    for (let i = 0; i < (members?.length || 0); i++) {
      await supabase.from('league_members')
        .update({ rank: i + 1 })
        .eq('id', members![i].id)
    }
  }

  return new Response(
    JSON.stringify({ 
      success: true, 
      week_start: weekStart.toISOString().split('T')[0],
      users_processed: results.length,
      results 
    }),
    { headers: { 'Content-Type': 'application/json' } }
  )
})

