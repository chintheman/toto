# Getting TOTO Strategy onto the App Store

The app is fully built — this guide is the part only you can do, because
Apple requires the app to be published under your own identity. Total
hands-on time is about 30–45 minutes, then Apple's review takes 1–3 days.
No Mac is needed at any point: Expo's EAS service builds the app in the
cloud.

## 1. Create an Apple Developer account (~15 min + up to 48h approval)

1. Go to https://developer.apple.com/programs/enroll/
2. Sign in with your Apple ID (the one on your iPhone is fine).
3. Enroll as an **Individual** — US$99/year.
4. Wait for Apple's confirmation email (usually hours, sometimes 1–2 days).

## 2. Create a free Expo account (~2 min)

1. Go to https://expo.dev/signup and sign up (free tier is enough).

## 3. Build the app in the cloud (~10 min of your time)

On any computer with Node.js installed (https://nodejs.org, LTS version):

```bash
# get the code
git clone https://github.com/chintheman/toto.git
cd toto/mobile
npm install

# install the EAS command-line tool and log in with your Expo account
npm install -g eas-cli
eas login

# link the project to your Expo account (accept the defaults)
eas init

# start the iOS build — EAS walks you through connecting your Apple
# Developer account and creates all certificates for you automatically
eas build --platform ios --profile production
```

When it asks "Do you want to log in to your Apple account?" say yes and
use the account from step 1. Say yes to everything about certificates and
provisioning — EAS manages them so you never have to think about it.
The build runs on Expo's servers (~15 min); you can watch progress at the
link it prints.

## 4. Submit to the App Store (~5 min)

```bash
eas submit --platform ios --latest
```

This uploads the finished build to App Store Connect. Then:

1. Go to https://appstoreconnect.apple.com → My Apps → TOTO Strategy.
2. Fill in the listing: description, a few screenshots (take them in the
   app via TestFlight, or ask Claude to generate simulator screenshots),
   the privacy questionnaire (the app collects **no data**, so answer
   "No" throughout), and an age rating (17+ — Apple requires this for
   gambling-related content, even educational apps).
3. Click **Submit for Review**.

Apple usually responds within 1–3 days. Once approved, you're live.

## Try it on your phone before all that (optional, free)

You can run the app on your iPhone today without any Apple account:

1. Install the free **Expo Go** app from the App Store.
2. On your computer: `cd toto/mobile && npm install && npx expo start`
3. Scan the QR code with your iPhone camera — the app opens in Expo Go.

## Notes

- The bundle identifier is `com.chintheman.totostrategy` (in
  `app.json`) — change it before the first build if you prefer another;
  it's permanent once published.
- Version bumps: edit `version` in `app.json`; build numbers
  auto-increment (`eas.json` → `autoIncrement`).
- Heads-up on App Review: apps that merely *reference* gambling are
  allowed, but Apple can be picky in this category. The app's framing —
  statistics education, myth-busting, "play responsibly" — is the right
  side of the line, but if a reviewer rejects it citing guideline 5.3,
  reply pointing out the app sells nothing, links to no gambling
  operator, and only presents public statistical data.
