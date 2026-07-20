# Getting TOTO onto the App Store (native SwiftUI app)

The app in this folder is a native Xcode project — you build and ship it
with Xcode on your Mac. No Expo/EAS involved.

## Run it today (simulator)

1. Open `ios/TotoApp.xcodeproj` in Xcode.
2. Wait for the Supabase Swift package to resolve (first open only).
3. Pick any iPhone simulator in the toolbar and press **▶ Run**.

The app pulls live draw data, number facts, and myth content from the
`toto-data` Supabase project.

## Ship it (once your Apple Developer account is approved)

1. In Xcode, click the blue **TotoApp** project icon → **Signing &
   Capabilities** tab → set **Team** to your Apple Developer team and
   leave "Automatically manage signing" on. (Or put your Team ID in
   `project.yml` if you regenerate the project with XcodeGen.)
2. In the toolbar device menu choose **Any iOS Device (arm64)**.
3. Menu **Product → Archive**. When the Organizer window opens:
4. **Distribute App → App Store Connect → Upload**, accept the defaults.
5. Go to https://appstoreconnect.apple.com → My Apps → **+** → New App
   (bundle ID `com.chintheman.toto`), attach the uploaded build, fill in
   the listing:
   - Screenshots: take them in the simulator (Cmd+S saves a PNG).
   - Privacy: the app collects **no user data** (the anonymous device
     UUID never leaves the Keychain; the optional premium-interest email
     is user-submitted — declare "Contact Info: Email Address, optional,
     not linked to identity" for that one field).
   - Age rating: answer the gambling questions honestly (educational
     references → expect 17+).
6. **Submit for Review**. Apple typically responds in 1–3 days.

## Version bumps

Edit `CFBundleShortVersionString` (marketing version) and bump
`CFBundleVersion` in `TotoApp/Info.plist` before each new archive.

## Tests

Product → Test in Xcode runs `TotoAppTests` (EV math verification against
Singapore Pools' published odds).

## App Review note (guideline 5.3)

The app sells nothing, links to no gambling operator, and only presents
public statistical data with a strong play-responsibly framing. If a
reviewer flags it, reply with exactly that.
