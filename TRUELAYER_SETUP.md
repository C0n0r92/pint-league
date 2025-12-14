# TrueLayer Configuration for Pints League

## 🔐 Add These Secrets to Supabase

Go to: **https://supabase.com/dashboard/project/hsdhlnjpwbendlwfoyqp/settings/vault**

Add the following secrets:

| Secret Name | Value |
|-------------|-------|
| `TRUELAYER_CLIENT_ID` | `sandbox-pintleague-f161a3` |
| `TRUELAYER_CLIENT_SECRET` | `d70dcb6f-d9e7-4889-ba9a-6b71550fac18` |
| `TOKEN_ENCRYPTION_KEY` | (Generate a random 32-character string) |

---

## 🔑 Generate Encryption Key

Run this command to generate a secure encryption key:

```bash
openssl rand -base64 32
```

Or use this one (CHANGE FOR PRODUCTION):
```
dG9rZW5fa2V5X2ZvcF9lbmNyeXB0aW9uXzEyMzQ1Njc4
```

---

## ⚙️ Update TrueLayer Redirect URLs

In your TrueLayer Console (https://console.truelayer.com/settings/application):

**Add this redirect URL:**
```
pintsleague://truelayer/callback
```

Your final list should include:
- ✅ `https://console.truelayer.com/redirect-page` (already there)
- ✅ `http://localhost:3000/callback` (already there)
- ✅ `pintsleague://truelayer/callback` (ADD THIS)

---

## 🚀 Deploy Edge Functions

Once secrets are added, deploy the TrueLayer functions:

```bash
cd ~/Desktop/pints_league
supabase functions deploy truelayer-auth
supabase functions deploy refresh-bank-token
supabase functions deploy sync-bank-transactions
```

---

## 🧪 Test the Integration

1. **In the app**: Tap "Connect Bank" on home screen
2. **Select a bank**: Choose "Mock Bank" in sandbox
3. **Login**: Use any credentials (sandbox accepts anything)
4. **Authorize**: Grant permissions
5. **Check**: You should see "Bank connected!" message

---

## 📊 What Happens Next

After connecting:

1. **Immediate**: Last 90 days of transactions synced
2. **Auto-matching**: Pub transactions → auto-logged pints
3. **Ongoing**: New transactions checked every 6 hours
4. **Bonus points**: +5 pts for verified transactions

---

## 🔒 Security Notes

- ✅ Tokens encrypted with AES-256-GCM
- ✅ Read-only access (can't move money)
- ✅ User can disconnect anytime
- ✅ GDPR compliant

---

## 📝 Next Steps

1. Add secrets to Supabase Vault ⬆️
2. Add redirect URL to TrueLayer ⬆️
3. Deploy Edge Functions
4. Test in sandbox
5. Move to production when ready

