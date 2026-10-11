# Explorer Log App: iOS MVP Plan

## Context
Apps like Yak only let you log hikes on big-name, curated mountain lists. This app lets explorers log almost any adventure: any peak on Earth, a custom pin anywhere, or an imported GPS track. Every log lands on an interactive 3D globe. Users level up from effort and exploration, and compete with friends.

**Decisions so far:** working MVP · native iOS (SwiftUI) · Supabase backend (free tier) · user is new to Swift/Xcode, so the architecture stays simple and each step gets explained · pure honor system (no verification) · XP from effort, exploration breadth and social competition · **very easy logging: the app suggests and the user confirms** (about 3 taps per log, globe already filled on day one) · **"Topographic Field Journal" visual style** · 3 tabs plus a floating + button.

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
- **supabase-swift** (Swift Package Manager) for auth (email now, Sign in with Apple in Phase 7), the Postgres database, and Storage for photos.
- **PostGIS** in Supabase for "peaks near this point" searches.
- **CoreLocation `CLGeocoder`** to reverse-geocode each log to a country, which drives exploration XP.
- **Swift's built-in `XMLParser`** to read GPX files (distance, elevation gain, start and end points).
- **PhotoKit (`PHAsset`)** to read each photo's location and date, for photo-first logging and the camera-roll scan.
- **HealthKit (`HKWorkout` + `HKWorkoutRoute`)** to import hikes recorded on an Apple Watch or iPhone. Check early that a free Apple ID signing account can use it on a device.

## MVP features
1. **Accounts**: sign up or sign in, plus a profile (username, avatar, home country).
2. **Navigation: 3 tabs plus a floating + button**
   - **Globe** (home): globe with ink-stamp pins color-coded by type, a stats strip (countries, continents, summits, elevation), a level bar, the **Suggested adventures** inbox, and the + button.
   - **Friends**: Feed | Leaderboard segmented control; Compare opens from a friend.
   - **You**: profile, level and rank, passport stamps, settings, sign out.
3. **Log an adventure**: the + button opens a sheet with three large choices:
   - **From a photo** (the default): pick photos; location and date come from the photos. The app suggests the nearest peak (PostGIS, within about 1 km) or a reverse-geocoded place name, guesses the type, and fills the title. Tap Save.
   - **Search**: one field for both peaks (OSM `natural=peak`, named, with elevation) and places (`MKLocalSearch`). Shows peaks "near me" before typing.
   - **Drop a pin**: long-press the globe.
   - **More… → GPX import** from Files or the share sheet (Strava, Garmin and AllTrails exports).
   - Every source opens **one prefilled form**: title, type (an icon row: hike, summit, climb, trek, expedition, volcano, canyon, other), date and photos. Distance, elevation and notes sit under a collapsed "Add details" section.
4. **Suggested adventures inbox**: cards with **Add** / **Dismiss**, fed by:
   - **Apple Health**: hiking and walking workouts with routes; distance, elevation and the route fill in automatically.
   - **Camera roll ("Fill your globe")**: offered during onboarding and re-runnable from You. Groups photos by place and day into trips, keeps trips far from home or near a known peak, ranks peaks first, and caps at about 30. Runs on the phone; only accepted trips upload.
   - Nothing is suggested twice (each log stores the workout or photo ID it came from; dismissals are stored too).
5. **Onboarding** (about 4 screens, all skippable): username → home country (prefilled from the phone's region) → fill your globe from photos? → connect Apple Health? → the globe, with suggestions waiting.
6. **Leveling**:
   - **Effort XP**: a base amount per type, plus +1 per 10 m of elevation gain, +10 per km, and a bonus for summit height bands (over 3,000 m, 5,000 m, 7,000 m).
   - **Exploration XP**: +500 for a first log in a new country, +1,500 for a new continent, +200 for a new mountain range or region.
   - Levels follow a smooth curve, with titles: Trailhead → Wanderer → Pathfinder → Mountaineer → Explorer → Legend.
   - XP is calculated **server-side** in a Postgres function so it stays consistent, even under the honor system.
   - **Reward moments**: an XP breakdown card after each Save ("+120 effort · +500 new country!"), a passport-stamp animation with a haptic tap for a new country, and a full-screen level-up.
7. **Social**:
   - Find friends by username, and send and accept friend requests.
   - **Friends feed** of recent adventures.
   - **Leaderboards** among friends: XP (this week and all time), countries, and total elevation.
   - **Head-to-head comparison** screen with stats side by side and both globes.

**Out of MVP (later):** badges and challenge collections, live GPS recording, Android, offline mode, public profiles.

## Visual style: Topographic Field Journal
Based on a hand-drawn "Topographic Maps by Hand" style reference: taupe ground, dark-brown contour lines, cream lettering. Built from native SwiftUI so it stays easy to build. Tokens and helpers live in `Cairn/Design/`.
- **Colors** (`Theme.swift`, each with a dark-mode "night map" value):
  - Light: khaki ground `#968D7D` (a touch darker than the reference's `#A39B8B` so cream titles keep 3:1 contrast), contour lines `#4A3F2C`, cream `#F8F6EA`, ink `#3B3223`, faded ink `#6F6450`, forest `#2F5D46` (primary), rust `#B5562E` (accent and the + button), sky `#4F7A94`.
  - Dark: ground `#2A241B`, lines `#54473A`, cream lettering, cards `#3A3227`.
- **Type** (bundled, SIL Open Font License):
  - **Bebas Neue**: screen titles, numbers, labels, buttons.
  - **IM Fell English Italic**: names, taglines and card titles (its old-style "1" looks like "I", so numbers always use Bebas).
  - SF Pro for body text and form fields.
- **Titles**: a small italic "kicker" over a huge cream Bebas word with a speckled letterpress texture (for example *the explorer* / YOU).
- **Contour background**: real contour lines traced (marching squares) from generated terrain, drawn behind every screen. Content sits on cream "journal page" cards.
- **Globe**: MapKit `.imagery(elevation: .realistic)` (the only style that renders a true 3D globe), with journal cards on top; ink-stamp pins; routes as dashed rust lines.
- **Passport stamps**: one rotated rubber-stamp badge per country (Bebas country name, italic year).
- **Ranks**: level titles shown in the italic, with a pencil-stroke progress bar.
- **Icons**: SF Symbols, one per adventure type.
- **Accessibility**: custom fonts scale with Dynamic Type, small text on the ground uses dark brown instead of cream, and a "reduce texture" option comes in Phase 7.

## Data model (Supabase / Postgres)
- `profiles`: id (= auth user), username, avatar_url, home_country, total_xp, level
- `peaks`: id, osm_id, name, elevation_m, country, `location geography(Point)` with a GiST index. Seeded once from an OSM extract (named peaks with elevation, which keeps it within the 500 MB free tier).
- `adventures`: id, user_id, type, title, date, peak_id (nullable), `location geography`, country_code, continent, distance_m, elevation_gain_m, `route geography(LineString)` (nullable), notes, xp_awarded, source (photo / health / search / pin / gpx), external_id (Health workout or photo asset ID, unique per user, for dedupe)
- `adventure_photos`: adventure_id, storage_path
- `friendships`: requester_id, addressee_id, status (pending / accepted)
- `dismissed_suggestions`: user_id, external_id
- Row-level security on every table: you can write only your own rows, and you can read your friends' adventures.
- Postgres function `award_xp(adventure_id)`, triggered on insert, plus views for the leaderboards.
- Postgres function `nearest_peak(lat, lng, radius_m)` for photo, pin and camera-roll suggestions.

## App structure (Xcode project `Cairn`)
```
Cairn/
  App/          CairnApp.swift, RootView (auth gate + 3 tabs)
  Design/       Theme, ContourBackground, StampBadge, JournalCard
  Services/     SupabaseClient, AuthService, AdventureService, PeakService, FriendService,
                PhotoLocationService, HealthImportService, SuggestionService, GPXParser, Geocoder
  Models/       Profile, Adventure, Peak, Friendship, Suggestion (Codable structs)
  Features/
    Auth/       AuthView
    Onboarding/ OnboardingView
    Globe/      GlobeView, AdventurePin, StatsStrip, SuggestionsInbox
    Log/        LogSheet, LogFormView, PhotoLogView, SearchView, DropPinView, GPXImportView
    Adventure/  AdventureDetailView
    Friends/    FriendsView, FeedView, LeaderboardView, CompareView
    You/        YouView, LevelBadge, PassportStamps
supabase/       migrations/*.sql, seed scripts (peak import)
```
Tabs: **Globe · Friends · You**, with a floating **+** on the Globe.

## Build phases (each one ends with something runnable)
1. ✅ **Setup**: Xcode project (XcodeGen), Supabase project, supabase-swift, email sign up and sign in. Done (`86f534f`).
2. **Database**: SQL migrations for the tables (including `source`, `external_id`, `dismissed_suggestions`), RLS rules, the XP function and `nearest_peak`. Import the OSM peaks.
3. **Design foundation + Globe + photo-first logging**: Theme and contour background, restyled sign-in, 3 tabs and the + sheet, the prefilled log form, photo and drop-pin logging, and pins on the globe.
4. **Search + Health import + suggestions inbox**: unified peak and place search, HealthKit workouts and routes, inbox cards, and GPX under "More".
5. **Fill your globe + onboarding + XP and levels**: the camera-roll scan, onboarding screens, country and continent detection, passport stamps and reward moments.
6. **Social**: Friends tab (feed, leaderboards, compare).
7. **Polish**: app icon, empty states, Sign in with Apple, then a TestFlight build ($99/yr Apple Developer account needed only at this point; possibly earlier for HealthKit on a device).

## Prerequisites to confirm before Phase 1
- A Mac with **Xcode** installed (free from the Mac App Store).
- A free **Supabase** account.
- Your iPhone, for on-device testing (free builds last 7 days), or use the Simulator.

## Verification
- After each phase, build and run in the **iOS Simulator** (I launch it and take screenshots; you tap through the flows, since I can't type into the Simulator), and walk through that phase's flow end to end.
- Check data in the Supabase dashboard: rows appear, RLS blocks other users' writes, and XP values match the formula.
- Screenshots in both light and dark mode for each new screen.
- Photo logging: load geotagged sample photos into the Simulator (`xcrun simctl addmedia`) and check that location, date and nearest peak fill in.
- Health: a debug-only "seed sample workout" button for the Simulator, then a real hike on the iPhone.
- Unit tests (Swift Testing) for `GPXParser` (distance and elevation on a sample .gpx file), trip grouping, type guessing, and the XP and level curve math.
- Social testing: two test accounts that friend each other, then check the feed and leaderboard.
