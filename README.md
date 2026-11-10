# license-plate-game

**Plate Chase** is an iPhone game for spotting license plates from all 50 states and DC.

- Plates are listed alphabetically. Filter by Needed, Spotted, or All.
- Tap a plate when you spot it. Tap it again to remove it.
- Add players, switch who's playing from the menu at the top right, and see who's ahead on the Leaderboard.
- Colored dots on each plate show which players have spotted it.
- **Friend groups:** on the Leaderboard, tap **Create Group** and text friends the 6-character code. They tap **Join with Code** on their phones. Everyone's plates sync through iCloud about every 30 seconds.
- **Game modes:** at the top of the Leaderboard, pick **Competitive** (everyone has their own list, most plates wins) or **Co-op** (one shared list everyone fills together). A friend group shares one mode, and any member can change it.
- "New Road Trip" (Leaderboard ⋯ menu) clears everyone's plates on this phone.

## Run it

Open `LicensePlateGame/LicensePlateGame.xcodeproj` in Xcode, pick your iPhone as the run destination, and press ⌘R.

## One-time CloudKit setup

Friend groups store each player as a `Member` record in the public database of the `iCloud.com.nikhilmath.licenseplategame` container.

1. In the app, tap **Create Group** once. This creates the `Member` record type in the Development environment.
2. Open the [CloudKit Console](https://icloud.developer.apple.com) → **CloudKit Database** → container `iCloud.com.nikhilmath.licenseplategame` → **Development**.
3. Go to **Indexes** → record type **Member** → **Add Basic Index** → field `groupCode`, type **Queryable** → **Save Changes**.
4. Before sending a TestFlight or App Store build, click **Deploy Schema Changes…** to copy the schema to **Production**. TestFlight builds use Production.

The entitlements file sets `com.apple.developer.icloud-container-environment` to `Production`, so Xcode builds share groups with TestFlight builds. To work on schema changes, switch it to `Development` temporarily.

## App Store listing

- Support page: https://nikhilmath.github.io/license-plate-game/ (`docs/index.html`)
- Privacy policy: https://nikhilmath.github.io/license-plate-game/privacy.html (`docs/privacy.html`)
- GitHub Pages serves `docs/` from `main`. Update the privacy policy if the app starts storing or sharing anything new.
- `docs/screenshots/` holds the App Store screenshots at 1206 × 2622 (6.3" iPhone, the size App Store Connect asks for). They were taken in the iPhone 18 Pro simulator with sample players.
- Sold in the United States only, for free.
- App Review notes and the screen-recording checklist for review: [`APP_REVIEW_NOTES.md`](APP_REVIEW_NOTES.md).

## Getting friends to play (TestFlight)

The app is set up in App Store Connect as **Plate Chase: 50 States + DC** (bundle ID `com.nikhilmath.licenseplategame`). The home-screen name is still "Plate Chase".

- **Public link** for the "Friends" external group (25-tester limit): https://testflight.apple.com/join/yKKYG9Dh. It works once Beta App Review approves a build. Friends install **TestFlight** from the App Store, then open the link.
- To invite someone by email: App Store Connect → the app → **TestFlight** → **Friends** → **Testers +** → **Email**.
- The internal **"Me"** group gets every new build automatically, with no review.

### Shipping a new build

1. Bump `CURRENT_PROJECT_VERSION` in the Xcode project. Uploads also bump it automatically through `manageAppVersionAndBuildNumber`.
2. Archive and upload:
   ```bash
   cd LicensePlateGame
   xcodebuild -project LicensePlateGame.xcodeproj -scheme LicensePlateGame -configuration Release \
     -destination 'generic/platform=iOS' -archivePath build/PlateChase.xcarchive -allowProvisioningUpdates archive
   xcodebuild -exportArchive -archivePath build/PlateChase.xcarchive -exportOptionsPlist ExportOptions.plist \
     -exportPath build/export -allowProvisioningUpdates
   ```
3. In TestFlight, add the build to **Friends** and submit it for review. Later builds are usually approved faster.
4. If the CloudKit schema changed, deploy it to Production first in the CloudKit Console.
