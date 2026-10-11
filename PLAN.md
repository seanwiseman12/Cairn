# Explorer Log App: iOS MVP Plan

## Context
Apps like Yak only let you log hikes on big-name, curated mountain lists. This app lets explorers log almost any adventure: any peak on Earth, a custom pin anywhere, or an imported GPS track. Every log lands on an interactive 3D globe. Users level up from effort and exploration, and compete with friends.

**Decisions so far:** working MVP · native iOS (SwiftUI) · Supabase backend (free tier) · user is new to Swift/Xcode, so the architecture stays simple and each step gets explained · pure honor system (no verification) · XP from effort, exploration breadth and social competition.

## Name ideas (working title: **Cairn**)
- **Cairn**: the stone stacks hikers leave to mark summits and routes. Short and meaningful.
- **Waypoint**: clean and nav-flavored.
- **Wayfarer**: the explorer identity.
- **Ridgeline**: mountain-forward.
- **Summitbook**: says exactly what it does.
- **Pinpoint / Pinned**: plays on the globe pins.

Check App Store and trademark availability before committing. The code uses `Cairn` as a placeholder that's easy to rename.

## Tech stack
- **SwiftUI on iOS 17+** with the Observation framework (`@Observable`). This is the simplest modern setup for a beginner.
- **MapKit (built in, free)** for the globe. SwiftUI's `Map` becomes a 3D globe when zoomed out, so there's no third-party map SDK or API key. Logs show as `Annotation` pins, and tapping one opens it.
- **supabase-swift** (Swift Package Manager) for auth (email plus Sign in with Apple), the Postgres database, and Storage for photos.
- **PostGIS** in Supabase for "peaks near this point" searches.
- **CoreLocation `CLGeocoder`** to reverse-geocode each log to a country, which drives exploration XP.
- **Swift's built-in `XMLParser`** to read GPX files (distance, elevation gain, start and end points).

## MVP features
1. **Accounts**: sign up or sign in, plus a profile (username, avatar, home country).
2. **Globe (home tab)**: 3D globe with a pin for each adventure, color-coded by type. A stats header shows countries, continents, summits and total elevation.
3. **Log an adventure**, three ways:
   - **Search a peak** by name or "near me". Data comes from OpenStreetMap `natural=peak` (named, with elevation).
   - **Drop a custom pin** by long-pressing the map, then choosing a name and type.
   - **Import a GPX track** from the Files app or the share sheet (Strava, Garmin and AllTrails exports). Stats fill in automatically and the route draws as a line.
   - Every log has: type (hike, summit, climb, trek, expedition, volcano, canyon, other), date, photos, notes, and optional distance and elevation.
4. **Leveling**:
   - **Effort XP**: a base amount per type, plus +1 per 10 m of elevation gain, +10 per km, and a bonus for summit height bands (over 3,000 m, 5,000 m, 7,000 m).
   - **Exploration XP**: +500 for a first log in a new country, +1,500 for a new continent, +200 for a new mountain range or region.
   - Levels follow a smooth curve, with titles: Trailhead → Wanderer → Pathfinder → Mountaineer → Explorer → Legend.
   - XP is calculated **server-side** in a Postgres function so it stays consistent, even under the honor system.
5. **Social**:
   - Find friends by username, and send and accept friend requests.
   - **Friends feed** of recent adventures.
   - **Leaderboards** among friends: XP (this week and all time), countries, and total elevation.
   - **Head-to-head comparison** screen with stats side by side and both globes.

**Out of MVP (later):** badges and challenge collections, live GPS recording, Android, offline mode, public profiles.

## Data model (Supabase / Postgres)
- `profiles`: id (= auth user), username, avatar_url, home_country, total_xp, level
- `peaks`: id, osm_id, name, elevation_m, country, `location geography(Point)` with a GiST index. Seeded once from an OSM extract (named peaks with elevation, which keeps it within the 500 MB free tier).
- `adventures`: id, user_id, type, title, date, peak_id (nullable), `location geography`, country_code, continent, distance_m, elevation_gain_m, `route geography(LineString)` (nullable), notes, xp_awarded
- `adventure_photos`: adventure_id, storage_path
- `friendships`: requester_id, addressee_id, status (pending / accepted)
- Row-level security on every table: you can write only your own rows, and you can read your friends' adventures.
- Postgres function `award_xp(adventure_id)`, triggered on insert, plus views for the leaderboards.

## App structure (Xcode project `Cairn`)
```
Cairn/
  App/          CairnApp.swift, RootView (auth gate + TabView)
  Services/     SupabaseClient, AuthService, AdventureService, PeakService, FriendService, GPXParser, Geocoder
  Models/       Profile, Adventure, Peak, Friendship (Codable structs)
  Features/
    Globe/      GlobeView, AdventurePin, StatsHeader
    Log/        LogAdventureView, PeakSearchView, DropPinView, GPXImportView
    Adventure/  AdventureDetailView
    Social/     FriendsView, FeedView, LeaderboardView, CompareView
    Profile/    ProfileView, LevelBadge
supabase/       migrations/*.sql, seed scripts (peak import)
```
Tabs: **Globe · Log (+) · Feed · Leaderboard · Profile**

## Build phases (each one ends with something runnable)
1. **Setup**: create the project folder (e.g. `~/Documents/Cairn`), the Xcode project and the Supabase project. Add the supabase-swift package. Sign in and sign up working.
2. **Database**: SQL migrations for the tables, RLS rules and the XP function. Import the OSM peaks.
3. **Globe + custom pin logging**: log an adventure by dropping a pin and see it on the globe.
4. **Peak search + GPX import + photos.**
5. **XP and levels**: country and continent detection, a level badge and a level-up moment.
6. **Social**: friends, feed, leaderboards, compare.
7. **Polish**: app icon, empty states, then a TestFlight build ($99/yr Apple Developer account needed only at this point).

## Prerequisites to confirm before Phase 1
- A Mac with **Xcode** installed (free from the Mac App Store).
- A free **Supabase** account.
- Your iPhone, for on-device testing (free builds last 7 days), or use the Simulator.

## Verification
- After each phase, build and run in the **iOS Simulator** (I can drive it and take screenshots), and walk through that phase's flow end to end.
- Check data in the Supabase dashboard: rows appear, RLS blocks other users' writes, and XP values match the formula.
- Unit tests (Swift Testing) for `GPXParser` (distance and elevation on a sample .gpx file) and the XP and level curve math.
- Social testing: two test accounts that friend each other, then check the feed and leaderboard.
