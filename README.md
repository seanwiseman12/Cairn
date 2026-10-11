# Cairn

Log any adventure on Earth onto a 3D globe. See PLAN.md for the full plan.

## First-time setup
1. Accept the Xcode license once: `sudo xcodebuild -license accept`
2. Point command-line tools at Xcode: `sudo xcode-select -s /Applications/Xcode.app`
3. Copy `Config/Secrets.example.xcconfig` to `Config/Secrets.xcconfig` and fill in your
   Supabase host and anon key (Supabase dashboard → Project Settings → API).
4. Generate the Xcode project: `xcodegen` (install with `brew install xcodegen`)
5. Open `Cairn.xcodeproj`, choose an iPhone simulator, and press ⌘R.

`Cairn.xcodeproj` is generated from `project.yml`, so edit `project.yml` and re-run
`xcodegen` instead of changing project settings in Xcode.
