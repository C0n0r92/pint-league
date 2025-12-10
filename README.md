# Pints League 🍺

A Flutter mobile app for tracking pub visits and competing with friends in fantasy-style leagues. Built with Supabase backend.

## Features

- **Automatic Pint Tracking**: GPS geofencing detects pub visits automatically
- **Manual Logging**: Log pints with pub search and drink selection
- **Fantasy Leagues**: Create/join leagues and compete with friends
- **Open Banking** (Optional): Verify visits with payment data via TrueLayer
- **Social Features**: Friends system, activity feed, achievements
- **Scoring Engine**: Points for pints, unique pubs, pub crawls, and more

## Tech Stack

- **Frontend**: Flutter (iOS + Android)
- **Backend**: Supabase (Postgres, Auth, Edge Functions, Realtime)
- **Location**: Geolocator + Workmanager for background tracking
- **Push Notifications**: Firebase Cloud Messaging (FCM v1 API)
- **State Management**: Riverpod
- **Navigation**: GoRouter

## Setup

### Prerequisites

- Flutter 3.0+
- Xcode (for iOS)
- Android Studio (for Android)
- Supabase account
- Firebase project

### 1. Clone & Install Dependencies

```bash
cd ~/Desktop/pints_league
flutter pub get
```

### 2. Environment Setup

Create a `.env` file in the project root:

```bash
cp .env.example .env
```

Edit `.env` with your keys:
```
SUPABASE_URL=https://hsdhlnjpwbendlwfoyqp.supabase.co
SUPABASE_ANON_KEY=your_anon_key
```

### 3. Run the App

```bash
# iOS
flutter run -d ios

# Android
flutter run -d android

# With environment variables
flutter run --dart-define=SUPABASE_URL=https://hsdhlnjpwbendlwfoyqp.supabase.co --dart-define=SUPABASE_ANON_KEY=your_key
```

### 4. Database Setup

The database schema has been applied. If you need to re-run it:

1. Go to https://supabase.com/dashboard/project/hsdhlnjpwbendlwfoyqp/sql/new
2. Paste contents of `supabase/migrations/00001_initial_schema.sql`
3. Click Run

### 5. Seed Pub Data

To populate pubs from OpenStreetMap:

1. Deploy the Edge Function:
```bash
supabase functions deploy seed-pubs
```

2. Call the function (this takes ~10-15 minutes):
```bash
curl -X POST https://hsdhlnjpwbendlwfoyqp.supabase.co/functions/v1/seed-pubs \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

## Project Structure

```
lib/
├── app/
│   ├── router.dart          # GoRouter configuration
│   └── theme.dart           # App theme and colors
├── core/
│   ├── models/              # Data models
│   ├── providers/           # Riverpod providers
│   ├── services/
│   │   ├── contacts_service.dart
│   │   ├── geofence_service.dart
│   │   ├── notification_service.dart
│   │   └── supabase_service.dart
│   └── utils/               # Utilities
├── features/
│   ├── auth/                # Login, signup, onboarding
│   ├── friends/             # Friends list and discovery
│   ├── home/                # Home dashboard
│   ├── leagues/             # Leagues and leaderboards
│   ├── pints/               # Pint logging and history
│   ├── sessions/            # Visit confirmation
│   └── settings/            # Settings and profile
├── shared/
│   └── widgets/             # Shared widgets
└── main.dart

supabase/
├── migrations/
│   └── 00001_initial_schema.sql
├── functions/
│   ├── seed-pubs/           # OpenStreetMap pub seeding
│   ├── truelayer-auth/      # Bank OAuth flow
│   ├── calculate-weekly-points/
│   └── send-notification/
└── config.toml
```

## Database Schema

- **profiles**: User profiles (extends auth.users)
- **pubs**: Pub locations from OpenStreetMap
- **sessions**: Detected pub visits
- **pints**: Logged drinks
- **leagues**: Leagues for competition
- **league_members**: League membership and rankings
- **weekly_points**: Calculated weekly scores
- **friendships**: Friend connections
- **bank_connections**: TrueLayer OAuth tokens
- **bank_transactions**: Payment data for verification
- **achievements**: Achievement definitions
- **user_achievements**: Earned achievements
- **device_tokens**: FCM push notification tokens
- **phone_hashes**: Hashed phone numbers for friend discovery

## Scoring Rules

| Action | Points |
|--------|--------|
| Each pint | 1 pt |
| Unique pub | 3 pts |
| Pub crawl (3+ pubs/day) | 5 pts bonus |
| Monday pint | 2 pts bonus |
| Verified pint (GPS/bank) | 1 pt bonus |

## Security

- Row Level Security (RLS) on all tables
- Bank tokens encrypted with AES-256-GCM
- Phone numbers hashed for privacy
- Service role key only used server-side

## License

MIT
