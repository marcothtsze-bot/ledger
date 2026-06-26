# Installing Ledger on your iPhone (from a Mac)

The app is iOS-native Flutter. Building an installable iOS app **must** happen on
a Mac with Xcode — this is the full, foolproof sequence. Repo is already on
GitHub and in sync, so the Mac just clones it.

> **Free Apple ID** → the app installs but stops working after **7 days**; just
> re-run step 5 to refresh it.
> **Paid Apple Developer ($99/yr)** → signs for a full year (and unlocks
> TestFlight). Not required to start.

---

## 1. One-time Mac setup

```bash
# Xcode: install from the Mac App Store, then open it once to finish setup, then:
sudo xcodebuild -license accept
xcode-select --install            # command-line tools (skip if already installed)

# Flutter SDK (if not already installed):
brew install --cask flutter       # or follow https://docs.flutter.dev/get-started/install/macos

# CocoaPods (Flutter needs it for iOS):
sudo gem install cocoapods

# Sanity check — fix anything it flags:
flutter doctor
```

## 2. Get the code

```bash
git clone https://github.com/marcothtsze-bot/ledger.git
cd ledger
flutter pub get
```

## 3. Add your Apple ID to Xcode (one time)

`Xcode ▸ Settings ▸ Accounts ▸ +  ▸ Apple ID` — sign in with your normal Apple ID.

## 4. Set the signing team

```bash
open ios/Runner.xcworkspace
```

In Xcode: select the **Runner** target ▸ **Signing & Capabilities** tab:

- ✅ **Automatically manage signing**
- **Team**: pick your Apple ID
- Bundle Identifier is `com.marco.ledger`. If Xcode says it's taken, change it to
  something unique, e.g. `com.marco.ledger.app`.

## 5. Plug in the iPhone and run

1. Connect the iPhone by USB. Unlock it and tap **Trust This Computer**.
2. Run it:

   ```bash
   flutter devices                 # confirm the iPhone shows up
   flutter run --release -d ios    # builds, installs, launches on the phone
   ```

   (Or just hit ▶ in Xcode with the iPhone selected.)

   The app stays installed after you stop the run.

## 6. Trust the developer on the iPhone (free Apple ID only)

First launch will refuse to open. On the iPhone:
`Settings ▸ General ▸ VPN & Device Management ▸ [your Apple ID] ▸ Trust`.
Then open Ledger from the home screen.

---

## Notes

- **iOS 13+** required (any iPhone from the last several years).
- First launch fetches the two fonts (Hanken Grotesk, IBM Plex Mono) over the
  network once; everything else — including all your data (SQLite on-device) — is
  fully offline after that.
- Want it to never expire / install over-the-air without the cable? Get the $99/yr
  Apple Developer Program and ship via **TestFlight** — ask and I'll wire up a
  cloud build (Codemagic / GitHub Actions macOS runner).
