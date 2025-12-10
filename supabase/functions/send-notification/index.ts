// Push Notification Sender using FCM HTTP v1 API
// Requires Firebase Service Account

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface NotificationPayload {
  userId: string
  title: string
  body: string
  data?: Record<string, string>
}

// Get OAuth2 access token from service account
async function getAccessToken(): Promise<string> {
  const serviceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT') || '{}')
  
  const now = Math.floor(Date.now() / 1000)
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging'
  }

  // Create JWT
  const header = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const claims = btoa(JSON.stringify(payload))
  const signatureInput = `${header}.${claims}`

  // Import private key and sign
  const privateKey = serviceAccount.private_key
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(privateKey),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  )

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(signatureInput)
  )

  const jwt = `${signatureInput}.${arrayBufferToBase64Url(signature)}`

  // Exchange JWT for access token
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt
    })
  })

  const tokenData = await tokenResponse.json()
  return tokenData.access_token
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\n/g, '')
  const binary = atob(base64)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i)
  }
  return bytes.buffer
}

function arrayBufferToBase64Url(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer)
  let binary = ''
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i])
  }
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
}

async function sendPushNotification(payload: NotificationPayload): Promise<{ sent: number }> {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  // Get user's device tokens
  const { data: tokens } = await supabase
    .from('device_tokens')
    .select('token, platform')
    .eq('user_id', payload.userId)

  if (!tokens?.length) return { sent: 0 }

  const projectId = Deno.env.get('FIREBASE_PROJECT_ID') || 'pints-league'
  const accessToken = await getAccessToken()

  let sent = 0

  for (const { token, platform } of tokens) {
    const fcmPayload = {
      message: {
        token,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: payload.data || {},
        android: {
          priority: 'high',
          notification: {
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            sound: 'default',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              'mutable-content': 1,
            },
          },
        },
      },
    }

    try {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(fcmPayload),
        }
      )

      if (response.ok) {
        sent++
      } else {
        const error = await response.text()
        console.error(`FCM send failed for ${platform}:`, error)
      }
    } catch (error) {
      console.error(`FCM send error:`, error)
    }
  }

  return { sent }
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  try {
    const { userId, title, body, data, type } = await req.json()

    // Handle different notification types
    if (type === 'visit_confirmation') {
      const result = await sendPushNotification({
        userId,
        title: title || `Visited ${data.pub_name}?`,
        body: body || `We detected a visit. Log ${data.estimated_pints} pint(s)?`,
        data: {
          type: 'visit_confirmation',
          session_id: data.session_id,
          pub_id: data.pub_id,
          pub_name: data.pub_name,
          estimated_pints: String(data.estimated_pints),
        },
      })
      return new Response(JSON.stringify(result), {
        headers: { 'Content-Type': 'application/json' }
      })
    }

    // Generic notification
    const result = await sendPushNotification({ userId, title, body, data })
    return new Response(JSON.stringify(result), {
      headers: { 'Content-Type': 'application/json' }
    })
    
  } catch (error) {
    console.error('Notification error:', error)
    return new Response(
      JSON.stringify({ error: 'Failed to send notification' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})

