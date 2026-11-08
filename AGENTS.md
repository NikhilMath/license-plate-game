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
- The Leaderboard's ⋯ menu has "New Road Trip", which clears every local player's plates.
- Things tried and **removed at the owner's request**: a worldwide Game Center leaderboard (they want friends only) and region-grouped plates.

## Code map (`LicensePlateGame/LicensePlateGame/`)

| File | Purpose |
|---|---|
| `LicensePlateGameApp.swift` | App entry. Wires in `GameStore` and `FriendSync`, runs a sync every 30s, uploads after player changes. Also `ContentView` (tabs) and `WelcomeView` (first-run name entry). |
| `GameStore.swift` | `Player` model and the `@Observable` store: local `players`, `currentPlayerID`, `groupCode`, cached `friends`. Saved as JSON in Application Support (`game.json`). |
| `FriendSync.swift` | CloudKit public database sync: create, join, and leave groups, upload, and fetch. |
| `USState.swift` | The 51 entries (50 states + DC) with nickname and region color. |
| `PlatesView.swift` | Plates grid, progress header, filter, search, player switcher. |
| `LicensePlateCard.swift` | A single plate card. |
| `LeaderboardView.swift` | Friend group section, standings, player detail. |

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

- Container `iCloud.com.nikhilmath.licenseplategame`, **public database**, record type `Member`. Each local player is one record named `<GROUPCODE>-<player UUID>`, with fields `groupCode`, `playerID`, `name`, `count`, `spotted` (a JSON string mapping state code to date).
- A phone only writes its own records. Friends are found with a query on `groupCode`, which has a QUERYABLE index.
- Group codes are 6 characters from `ABCDEFGHJKMNPQRSTUVWXYZ23456789`.
- The schema was **deployed to Production on 2026-11-06**. If you add or change fields, the change lands in Development first. Deploy it in the CloudKit Console before shipping a TestFlight or App Store build, because those use Production.
- **Every build uses Production**, including Debug builds from Xcode. The entitlements file sets `com.apple.developer.icloud-container-environment = Production`. This was added on 2026-11-06 after a Debug build couldn't join a group made in TestFlight, because Development and Production data are separate.
- Production won't create new record types or fields automatically. To change the schema, temporarily set that entitlement to `Development`, run once to create the fields, deploy them to Production in the console, then set it back.

## App Store Connect and TestFlight

- App record: **"Plate Chase: 50 States + DC"** (app id `6831714785`). The name "Plate Chase" was taken.
- Build **1.0 (1)** was submitted to Beta App Review on 2026-11-06.
- Build **1.0 (2)** was uploaded on 2026-11-06. It has the Production-CloudKit entitlement and the clearer "no group found" message. It goes to **Me** automatically. It is not yet added to **Friends**.
- Groups:
  - **Me** (internal): the owner. Gets every build automatically, with no review.
  - **Friends** (external): public link https://testflight.apple.com/join/yKKYG9Dh, limit 25. Grayson (grayson.nielsen@gmail.com) is invited.
- The Beta App Review contact is Nikhil Math, nikhil@nikhilmath.com. No sign-in is required.
- TestFlight builds expire after 90 days.

### Shipping a new build

```bash
cd LicensePlateGame
xcodebuild -project LicensePlateGame.xcodeproj -scheme LicensePlateGame -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/PlateChase.xcarchive -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath build/PlateChase.xcarchive -exportOptionsPlist ExportOptions.plist \
  -exportPath build/export -allowProvisioningUpdates
```

`ExportOptions.plist` uploads straight to App Store Connect and bumps the build number automatically. After processing, add the build to **Friends** and submit it for review (ask the owner first). Then update the build and status lines above.
