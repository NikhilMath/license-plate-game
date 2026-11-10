# AGENTS.md

A guide for AI coding agents working in this repo. **Keep this file current:** whenever you change the app, its setup, or anything in Apple's consoles, update the matching section here in the same commit.

## Workflow rules (from the owner)

- **Commit and push every finished change to `main`.** Don't wait to be asked. If you're working on another branch or in a worktree, push that branch too, then fast-forward `main` (`git push origin HEAD:main`).
- Update this file in the same commit as the change it describes.
- **Ship every finished app change to App Store Connect** (archive and upload, see "Shipping a new build") so it reaches TestFlight. The owner asked for this on 2026-11-06. Uploading is fine without asking. Still ask before submitting a build to Beta App Review or App Store review.
- `git push` needs a `Bash(git push:*)` allow rule in `.claude/settings.json`. Claude Code's auto mode blocks pushes otherwise, and Claude can't add the rule itself.
- Confirm with the owner before anything irreversible or outward-facing in Apple's consoles: submitting for review, inviting testers, or deploying a schema to Production.
- For public-facing contact details, use **nikhil@nikhilmath.com**.

## What the app is

**Plate Chase** is a SwiftUI iPhone game (iOS 17+, portrait, iPhone only). Players spot license plates from the 50 states and DC.

- Plates appear in one alphabetical grid (`USState.alphabetical`). Filter tabs are **Needed, Spotted, All**, and the screen opens on Needed. Tapping a spotted plate asks before removing it.
- Several local players can share one phone. Each has a palette color, shown as dots on the plates they've spotted.
- **Friend groups** sync players across phones through CloudKit (see below). Friends appear in the standings with a 👥 icon. They're view-only: no rename, delete, or "play as".
- Two **game modes**, picked at the top of the Leaderboard tab (added 2026-11-10):
  - **Competitive** (the default): everyone keeps their own list, and the leaderboard ranks players by plates spotted.
  - **Co-op**: everyone fills one shared list. A plate is done once anyone spots it. The Plates tab shows team progress, the second tab is renamed **Team**, and players are listed by how many plates they spotted first. Tapping a plate a teammate already has shows who got it. Only the spotter can remove it.
  - Switching modes never changes anyone's spotted plates. It only changes how they're counted.
  - In a friend group the mode is shared. Any member can change it, the most recent change wins, and other phones follow on their next sync. Joining a group takes on that group's mode. Without a group it's a setting on that phone.
- The Leaderboard's ⋯ menu has "New Road Trip", which clears every local player's plates.
- Things tried and **removed at the owner's request**: a worldwide Game Center leaderboard (they want friends only) and region-grouped plates.

## Code map (`LicensePlateGame/LicensePlateGame/`)

| File | Purpose |
|---|---|
| `LicensePlateGameApp.swift` | App entry. Wires in `GameStore` and `FriendSync`, runs a sync every 30s, uploads after player changes. Also `ContentView` (tabs) and `WelcomeView` (first-run name entry). |
| `GameStore.swift` | `Player` model and the `@Observable` store: local `players`, `currentPlayerID`, `groupCode`, cached `friends`, and the `GameMode` (`mode`, `modeChangedAt`) with the co-op team helpers. Saved as JSON in Application Support (`game.json`). |
| `FriendSync.swift` | CloudKit public database sync: create, join, and leave groups, upload, and fetch. |
| `USState.swift` | The 51 entries (50 states + DC) with nickname and region color. |
| `PlatesView.swift` | Plates grid, progress header (player or team), filter, search, player switcher. |
| `LicensePlateCard.swift` | A single plate card. |
| `LeaderboardView.swift` | Mode picker, friend group section, standings (or team progress in co-op), player detail. |

The Xcode project uses a file-system-synchronized group (objectVersion 77), so new `.swift` files in that folder are picked up automatically. Don't add them to `project.pbxproj` by hand.

## Building and running

The active developer directory on this Mac is Command Line Tools, so prefix commands with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

```bash
cd LicensePlateGame
# Simulator
xcodebuild -project LicensePlateGame.xcodeproj -scheme LicensePlateGame -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath build build
# Owner's iPhone (device id 00008150-000C282201E8C01C)
xcodebuild -project LicensePlateGame.xcodeproj -scheme LicensePlateGame -destination 'id=00008150-000C282201E8C01C' -derivedDataPath build -allowProvisioningUpdates build
xcrun devicectl device install app --device 00008150-000C282201E8C01C build/Build/Products/Debug-iphoneos/LicensePlateGame.app
xcrun devicectl device process launch --terminate-existing --device 00008150-000C282201E8C01C com.nikhilmath.licenseplategame
```

`build/` is gitignored.

## Signing and identifiers

- Team **A5SDFXT5VB** has been on the paid Apple Developer Program since 2026-11-06. Xcode's cached team list may still say "Personal Team", but `-allowProvisioningUpdates` signs fine.
- Bundle ID: `com.nikhilmath.licenseplategame`. Home-screen name: "Plate Chase".
- Entitlements (`LicensePlateGame/LicensePlateGame.entitlements`): iCloud/CloudKit with container `iCloud.com.nikhilmath.licenseplategame`.
- `ITSAppUsesNonExemptEncryption = NO` is set, so uploads skip the export-compliance question.

## CloudKit (friend groups)

- Container `iCloud.com.nikhilmath.licenseplategame`, **public database**, record type `Member`. Each local player is one record named `<GROUPCODE>-<player UUID>`, with fields `groupCode`, `playerID`, `name`, `count`, `spotted` (a JSON string mapping state code to date), plus `mode` (String, `competitive` or `coop`) and `modeChangedAt` (Date/Time). A group's mode is the one with the latest `modeChangedAt` on any member's record. A phone that has never changed the mode leaves both fields off.
- `mode` and `modeChangedAt` were added in the CloudKit Console and **deployed to Production on 2026-11-10**. Neither has an index, and neither needs one.
- A phone only writes its own records. Friends are found with a query on `groupCode`, which has a QUERYABLE index.
- Group codes are 6 characters from `ABCDEFGHJKMNPQRSTUVWXYZ23456789`.
- The schema was **deployed to Production on 2026-11-06**. If you add or change fields, the change lands in Development first. Deploy it in the CloudKit Console before shipping a TestFlight or App Store build, because those use Production.
- **Every build uses Production**, including Debug builds from Xcode. The entitlements file sets `com.apple.developer.icloud-container-environment = Production`. This was added on 2026-11-06 after a Debug build couldn't join a group made in TestFlight, because Development and Production data are separate.
- Production won't create new record types or fields automatically. To change the schema, temporarily set that entitlement to `Development`, run once to create the fields, deploy them to Production in the console, then set it back.

## App Store Connect and TestFlight

- App record: **"Plate Chase: 50 States + DC"** (app id `6831714785`). The name "Plate Chase" was taken.
- Build **1.0 (1)** was submitted to Beta App Review on 2026-11-06.
- Build **1.0 (2)** was uploaded on 2026-11-06. It has the Production-CloudKit entitlement and the clearer "no group found" message. It goes to **Me** automatically. It is not yet added to **Friends**.
- Build **1.1** was uploaded on 2026-11-10 with the co-op and competitive game modes. The 1.0 train is closed to new builds because 1.0 was approved, so `MARKETING_VERSION` is now 1.1. It goes to **Me** automatically. It is not yet added to **Friends** and has not been submitted for App Store review.
- Groups:
  - **Me** (internal): the owner. Gets every build automatically, with no review.
  - **Friends** (external): public link https://testflight.apple.com/join/yKKYG9Dh, limit 25. Grayson (grayson.nielsen@gmail.com) is invited.
- The Beta App Review contact is Nikhil Math, nikhil@nikhilmath.com. No sign-in is required.
- TestFlight builds expire after 90 days.

### App Store review

- Version **1.0** (build 1.0 (2)) was submitted to App Store review on 2026-11-07. App Review sent it back the same day under **Guideline 2.1 - Information Needed**. They want a screen recording from a physical iPhone plus answers about purpose, setup, external services, regions, and third-party material, all in **App Review Information → Notes**.
- [`APP_REVIEW_NOTES.md`](APP_REVIEW_NOTES.md) has the Notes text, the recording checklist, and how to resubmit. No new build is needed.
- On 2026-11-07 the owner replied to App Review with the notes and the screen recording attached. The same text is saved in **App Review Information → Notes**, pointing to that reply for the video. The owner then clicked **Resubmit to App Review** (Claude's browser click on that button is blocked by auto mode, so the owner does it). Version 1.0 has been **Waiting for Review** since 2026-11-07.
- By 2026-11-10 App Store Connect was treating **1.0 as approved**: an upload of another 1.0 build was refused with "must contain a higher version than that of the previously approved version [1.0]". Check the app's page in App Store Connect for whether it is live.
- Version **1.0** is live (Ready for Distribution).
- Version **1.1** was set up on 2026-11-10 and is in **Prepare for Submission** with build 1.1 (1) attached. Its What's New text, promotional text, and description cover the game modes, and the review notes start with a "What's New in 1.1" section (also in `APP_REVIEW_NOTES.md`). The owner approved submitting it, and it was **submitted for App Store review on 2026-11-10** (status: Waiting for Review). It is set to release automatically to all users as soon as App Review approves it.
- The App Store screenshots still show 1.0, without the mode picker. They're optional to refresh, since every 1.0 screen still looks the same in Competitive mode.
- Listing: support page `docs/index.html`, privacy policy `docs/privacy.html` (GitHub Pages from `main`), screenshots in `docs/screenshots/` at 1206 × 2622. Sold in the US only, free. Update the privacy policy and the review notes if the app starts storing or sharing anything new.

### Shipping a new build

```bash
cd LicensePlateGame
xcodebuild -project LicensePlateGame.xcodeproj -scheme LicensePlateGame -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/PlateChase.xcarchive -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath build/PlateChase.xcarchive -exportOptionsPlist ExportOptions.plist \
  -exportPath build/export -allowProvisioningUpdates
```

`ExportOptions.plist` uploads straight to App Store Connect and bumps the build number automatically. After processing, add the build to **Friends** and submit it for review (ask the owner first). Then update the build and status lines above.
