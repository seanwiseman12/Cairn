# Explorer Log App: iOS MVP Plan

## Context
Apps like Yak only let you log hikes on big-name, curated mountain lists. This app lets explorers log almost any adventure: any peak on Earth, a custom pin anywhere, or an imported GPS track. Every log lands on an interactive 3D globe. Users level up from effort and exploration, and compete with friends.

**Decisions so far:** working MVP · native iOS (SwiftUI) · Supabase backend (free tier) · user is new to Swift/Xcode, so the architecture stays simple and each step gets explained · pure honor system (no verification) · XP from effort, exploration breadth and social competition · **very easy logging: the app suggests and the user confirms** (about 3 taps per log, globe already filled on day one) · **clean outdoors visual style (off-white, forest green, rounded cards)** · 3 tabs plus a floating + button.

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
- **Custom Metal-shader globe** for the home screen (see Visual style), plus **MapKit (built in, free)** for precise, zoomed-in placement and route maps. No third-party map SDK or API key.
- **supabase-swift** (Swift Package Manager) for auth (email now, Sign in with Apple in Phase 7), the Postgres database, and Storage for photos.
- **Bundled peaks database** (SQLite, built by `tools/make_peaks.py` from GeoNames, CC BY 4.0): about 506k named peaks, mountains, volcanoes and ranges with elevation, country and alternate names. Instant offline search, ranked by fame (elevation plus how many languages name it). Hills (another ~500k) can be added with `--hills`.
- **Photos**: each peak's own photo from **Wikimedia Commons** (free, no key). `tools/add_peak_photos.py` matches bundled peaks to their Wikidata image by GeoNames ID (about 22k peaks), and the app fetches the image, author and license on demand (`Services/PlacePhotos.swift`). Fallback for peaks without one, and for places: an **Unsplash** search (free key, optional, `UNSPLASH_ACCESS_KEY` in Secrets.xcconfig). Every photo shows its required credit.
- **PostGIS** in Supabase for location queries on adventures.
- **CoreLocation `CLGeocoder`** to reverse-geocode each log to a country, which drives exploration XP.
- **Swift's built-in `XMLParser`** to read GPX files (distance, elevation gain, start and end points).
- **PhotoKit (`PHAsset`)** to read each photo's location and date, for photo-first logging and the camera-roll scan.
- **HealthKit (`HKWorkout` + `HKWorkoutRoute`)** to import hikes recorded on an Apple Watch or iPhone. Check early that a free Apple ID signing account can use it on a device.

## MVP features
1. **Accounts**: sign up or sign in, plus a profile (username, avatar, home country).
2. **Navigation: 3 tabs plus a floating + button**
   - **Globe** (home): globe with ink-stamp pins color-coded by type, a stats strip (countries, continents, summits, elevation), a level bar, a **search bar for mountains and places** (picking a result flies the globe there, drops a pin and offers "Log an adventure here"), the **Suggested adventures** inbox, and the + button.
   - **Plans** (built): adventures you want to do next, saved from any searched place with a **Plan** button (type, a date or "Someday", notes). "Up next" sorts dated plans soonest first; "Someday" is drag-to-reorder. Filter by type, swipe to edit or remove, tap to fly the globe there, "Log it" when done. Each plan shows estimated XP and peak-list progress ("13th of the Adirondack 46ers"). Saved on the phone (`PlanStore`, plans.json) until the database phase.
   - **Friends**: Feed | Leaderboard segmented control; Compare opens from a friend.
   - **You**: profile, level and rank, passport stamps, settings, sign out.
3. **Log an adventure**: the + button opens a sheet with three large choices:
   - **From a photo** (the default): pick photos; location and date come from the photos. The app suggests the nearest peak (from the bundled peaks database, within about 1 km) or a reverse-geocoded place name, guesses the type, and fills the title. Tap Save.
   - **Search**: the same mountain and place search as the globe (bundled GeoNames peaks plus `MKLocalSearch` for towns, addresses and outdoor places). Shows peaks "near me" before typing.
   - **Drop a pin**: long-press the globe.
   - **More… → GPX import** from Files or the share sheet (Strava, Garmin and AllTrails exports).
   - Every source opens **one prefilled form**: title, type (an icon row: hike, summit, climb, ski, trek, expedition, volcano, canyon, other), date and photos. Distance, elevation and notes sit under a collapsed "Add details" section.
4. **Suggested adventures inbox**: cards with **Add** / **Dismiss**, fed by:
   - **Apple Health**: hiking, walking and skiing (downhill, cross-country, snowboarding) workouts with routes; distance, elevation and the route fill in automatically.
   - **Camera roll ("Fill your globe")**: offered during onboarding and re-runnable from You. Groups photos by place and day into trips, keeps trips far from home or near a known peak, ranks peaks first, and caps at about 30. Runs on the phone; only accepted trips upload.
   - Nothing is suggested twice (each log stores the workout or photo ID it came from; dismissals are stored too).
5. **Onboarding** (about 4 screens, all skippable): username → home country (prefilled from the phone's region) → fill your globe from photos? → connect Apple Health? → the globe, with suggestions waiting.
6. **Leveling and badges** (rules in `Cairn/Progression/`, every number in `XPRules`; tests in `CairnTests/ProgressionTests.swift`):
   - **Effort XP**: a base per type (hike or ski 100, canyon 120, summit, trek or volcano 150, climb 200, expedition 400), +1 per 10 m of elevation gain, +10 per km, and a high-summit bonus (+150 over 3,000 m, +400 over 5,000 m, +1,000 over 7,000 m). A **difficulty** rating on the log form (Easy ×1, Moderate ×1.25, Hard ×1.5, Extreme ×2) scales it, so strenuous days earn more.
   - **Exploration XP**: +500 and a **passport stamp** for a first adventure in a new country; +150 for a first adventure in a new US state.
   - **Milestone badges with XP boosts**: countries 3 / 5 / 10 / 25 / 50 / 100 (+300 / +500 / +1,000 / +2,500 / +5,000 / +10,000); US states 10 / 25 / 50 (+500 / +1,500 / +5,000).
   - **Peak-list badges**: finish every peak on a list for its badge and a big bonus. Lists live in `Resources/PeakLists/peak-lists.json`: Adirondack 46ers (+4,600) and Seven Summits (+15,000) so far. A log counts if it's on the list's GeoNames peak or within 400 m of its summit.
   - Adventures are replayed in date order, so "first in a country" and "finished the list" go to the adventure that actually did it.
   - Levels: reaching level L takes 150 × (L − 1)² XP. Ranks: Trailhead (1) → Wanderer (5) → Pathfinder (10) → Mountaineer (20) → Explorer (30) → Legend (50).
   - Today the app calculates this on the phone (`ProgressStore`). Phase 2's `award_xp` Postgres function must use the same rules so leaderboards can't drift; keep the two in sync, or have the server call the same logic.
   - **Reward moments**: an XP breakdown card after each Save ("+120 effort · +500 new country!"), a passport-stamp animation with a haptic tap for a new country, and a full-screen level-up.
7. **Social**:
   - Find friends by username, and send and accept friend requests.
   - **Friends feed** of recent adventures.
   - **Leaderboards** among friends: XP, countries and badges (built, `LeaderboardView`), with "You're in Nth place"; this-week and total-elevation boards to follow.
   - **Head-to-head comparison** screen with stats side by side and both globes.

**Out of MVP (later):** more peak lists (Colorado 14ers, NH 48, Catskill 3500), continent bonuses, live GPS recording, Android, offline mode, public profiles.

## Visual style: clean outdoors
Based on an "Adventure Awaits" app-UI reference: light and airy, with deep forest-green accents. Built from native SwiftUI with the system font. Tokens and shared components live in `Cairn/Design/` (`Theme.swift`, `Components.swift`).
- **Colors** (always dark mode, `Theme.swift`): charcoal background `#111311`, dark grey cards `#1D201D` with hairline edges, off-white text `#F3F4EF`, grey secondary text `#989D97`, and a stark **white accent** (`Theme.accent`: selected chips and tabs, primary buttons, the + button, progress, badges) with near-black text on it (`Theme.onAccent`). Gold `#F4BE52` for stars.
- **Type**: Outfit (geometric sans, bundled, SIL Open Font License) everywhere through `Font.cairn(...)`, which keeps Dynamic Type. Semibold large titles (for example "Adventure Awaits"), semibold card titles.
- **Shapes**: big rounded cards (32 pt hero, 24 pt cards), capsule chips and buttons, white circular icon buttons, soft shadows.
- **Components**: pill chips with icons (selected = white outline and text), stat chips, raised grey feature cards, and a floating dark capsule tab bar (selected tab = white-outlined pill with its name, white + in the middle).
- **Globe**: the custom shader globe (`Features/Globe/TopoGlobe`) filling the home screen, with white continents (the accent white), soft grey contour lines and a dark charcoal sea. Built from real elevation data (NOAA ETOPO1, public domain, `Resources/Globe/globe-relief.png`). It spins slowly; drag to turn it, pinch or double-tap to zoom up to 10× (finer 100 m contours and a 10° grid fade in). Elevation is stored as 16-bit values across two color channels and blended in the shader. Pins: dark dot ringed in white with a name tag. Drop-a-pin placement uses a zoomable map.
- **Accessibility**: Dynamic Type through system text styles, VoiceOver labels on icon buttons, and both light and dark mode.

## Data model (Supabase / Postgres)
- `profiles`: id (= auth user), username, avatar_url, home_country, total_xp, level
- Peaks are **not** stored in Supabase: they ship in the app (see Tech stack). Adventures store the GeoNames peak id plus its name and elevation.
- `planned_adventures`: id, user_id, place (name, subtitle, lat/lng, GeoNames peak_id, country_code, elevation), type, target_date (nullable = someday), notes, sort_order, created_at. Imports the plans already saved on the phone on first sign-in.
- `adventures`: id, user_id, type, title, date, peak_id (nullable GeoNames id), peak_name, `location geography`, country_code, continent, distance_m, elevation_gain_m, `route geography(LineString)` (nullable), notes, xp_awarded, source (photo / health / search / pin / gpx), external_id (Health workout or photo asset ID, unique per user, for dedupe)
- `adventure_photos`: adventure_id, storage_path
- `friendships`: requester_id, addressee_id, status (pending / accepted)
- `dismissed_suggestions`: user_id, external_id
- Row-level security on every table: you can write only your own rows, and you can read your friends' adventures.
- Postgres function `award_xp(adventure_id)`, triggered on insert, plus views for the leaderboards.

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
2. **Database**: SQL migrations for the tables (including `source`, `external_id`, `dismissed_suggestions`), RLS rules and the XP function. (Peaks are bundled in the app, so there's no peak import; "nearest peak" runs on the phone.)
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
