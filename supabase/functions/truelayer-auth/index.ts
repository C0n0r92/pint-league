// TrueLayer OAuth Flow Handler
// Handles auth link generation and token exchange

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const TRUELAYER_CLIENT_ID = Deno.env.get('TRUELAYER_CLIENT_ID')!
const TRUELAYER_CLIENT_SECRET = Deno.env.get('TRUELAYER_CLIENT_SECRET')!
const ENCRYPTION_KEY = Deno.env.get('TOKEN_ENCRYPTION_KEY')! // 32-byte key for AES-256
const REDIRECT_URI = 'pintsleague://truelayer/callback'

// Token encryption using AES-256-GCM
async function encryptToken(token: string, keyString: string): Promise<string> {
  const keyBytes = new TextEncoder().encode(keyString.padEnd(32, '0').slice(0, 32))
  const key = await crypto.subtle.importKey(
    'raw',
    keyBytes,
    { name: 'AES-GCM' },
    false,
    ['encrypt']
  )
  const iv = crypto.getRandomValues(new Uint8Array(12))
  const encrypted = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv },
    key,
    new TextEncoder().encode(token)
  )
  // Return iv + ciphertext as base64
  const combined = new Uint8Array(iv.length + encrypted.byteLength)
  combined.set(iv)
  combined.set(new Uint8Array(encrypted), iv.length)
  return btoa(String.fromCharCode(...combined))
}

async function decryptToken(encrypted: string, keyString: string): Promise<string> {
  const keyBytes = new TextEncoder().encode(keyString.padEnd(32, '0').slice(0, 32))
  const key = await crypto.subtle.importKey(
    'raw',
    keyBytes,
    { name: 'AES-GCM' },
    false,
    ['decrypt']
  )
  const combined = Uint8Array.from(atob(encrypted), c => c.charCodeAt(0))
  const iv = combined.slice(0, 12)
  const ciphertext = combined.slice(12)
  const decrypted = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv },
    key,
    ciphertext
  )
  return new TextDecoder().decode(decrypted)
}

Deno.serve(async (req) => {
  const url = new URL(req.url)
  
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  // Verify user is authenticated
  const authHeader = req.headers.get('Authorization')
  const { data: { user }, error: authError } = await supabase.auth.getUser(
    authHeader?.replace('Bearer ', '')
  )
  
  if (authError || !user) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { 
      status: 401,
      headers: { 'Content-Type': 'application/json' }
    })
  }

  // GET - Generate auth link
  if (req.method === 'GET') {
    const authUrl = new URL('https://auth.truelayer.com/')
    authUrl.searchParams.set('response_type', 'code')
    authUrl.searchParams.set('client_id', TRUELAYER_CLIENT_ID)
    authUrl.searchParams.set('redirect_uri', REDIRECT_URI)
    authUrl.searchParams.set('scope', 'accounts balance transactions')
    authUrl.searchParams.set('providers', 'uk-ob-all ie-ob-all')
    authUrl.searchParams.set('state', user.id)

    return new Response(
      JSON.stringify({ auth_url: authUrl.toString() }),
      { headers: { 'Content-Type': 'application/json' } }
    )
  }

  // POST - Exchange code for tokens
  if (req.method === 'POST') {
    try {
      const { code } = await req.json()

      if (!code) {
        return new Response(
          JSON.stringify({ error: 'Missing authorization code' }),
          { status: 400, headers: { 'Content-Type': 'application/json' } }
        )
      }

      // Exchange authorization code for tokens
      const tokenResponse = await fetch('https://auth.truelayer.com/connect/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          grant_type: 'authorization_code',
          client_id: TRUELAYER_CLIENT_ID,
          client_secret: TRUELAYER_CLIENT_SECRET,
          redirect_uri: REDIRECT_URI,
          code,
        }),
      })

      if (!tokenResponse.ok) {
        const errorText = await tokenResponse.text()
        console.error('TrueLayer token exchange failed:', errorText)
        return new Response(
          JSON.stringify({ error: 'Token exchange failed', details: errorText }),
          { status: 400, headers: { 'Content-Type': 'application/json' } }
        )
      }

      const tokens = await tokenResponse.json()
      // tokens = { access_token, refresh_token, expires_in, token_type }

      // Encrypt tokens before storing
      const encryptedAccess = await encryptToken(tokens.access_token, ENCRYPTION_KEY)
      const encryptedRefresh = await encryptToken(tokens.refresh_token, ENCRYPTION_KEY)
      const expiresAt = new Date(Date.now() + tokens.expires_in * 1000)

      // Store in database
      const { error: dbError } = await supabase.from('bank_connections').upsert({
        user_id: user.id,
        provider: 'truelayer',
        access_token_encrypted: encryptedAccess,
        refresh_token_encrypted: encryptedRefresh,
        expires_at: expiresAt.toISOString(),
        status: 'active',
        last_synced_at: new Date().toISOString(),
      }, { onConflict: 'user_id' })

      if (dbError) {
        console.error('Failed to save bank connection:', dbError)
        return new Response(
          JSON.stringify({ error: 'Failed to save connection' }),
          { status: 500, headers: { 'Content-Type': 'application/json' } }
        )
      }

      return new Response(
        JSON.stringify({ success: true }),
        { headers: { 'Content-Type': 'application/json' } }
      )
      
    } catch (error) {
      console.error('TrueLayer auth error:', error)
      return new Response(
        JSON.stringify({ error: 'Internal error' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }
  }

  return new Response('Method not allowed', { status: 405 })
})

