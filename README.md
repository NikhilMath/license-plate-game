# license-plate-game

**Plate Chase** is an iPhone game for spotting license plates from all 50 states and DC.

- Plates are listed alphabetically. Filter by Needed, Spotted, or All.
- Tap a plate when you spot it. Tap it again to remove it.
- Add players, switch who's playing from the menu at the top right, and see who's ahead on the Leaderboard.
- Colored dots on each plate show which players have spotted it.
- **Friend groups:** on the Leaderboard, tap **Create Group** and text friends the 6-character code. They tap **Join with Code** on their phones. Everyone's plates sync through iCloud about every 30 seconds.
- "New Road Trip" (Leaderboard ⋯ menu) clears everyone's plates on this phone.

## Run it

Open `LicensePlateGame/LicensePlateGame.xcodeproj` in Xcode, pick your iPhone as the run destination, and press ⌘R.

## One-time CloudKit setup

Friend groups store each player as a `Member` record in the public database of the `iCloud.com.nikhilmath.licenseplategame` container.

1. In the app, tap **Create Group** once. This creates the `Member` record type in the Development environment.
2. Open the [CloudKit Console](https://icloud.developer.apple.com) → **CloudKit Database** → container `iCloud.com.nikhilmath.licenseplategame` → **Development**.
3. Go to **Indexes** → record type **Member** → **Add Basic Index** → field `groupCode`, type **Queryable** → **Save Changes**.
4. Before sending a TestFlight or App Store build, click **Deploy Schema Changes…** to copy the schema to **Production**. TestFlight builds use Production.

## Getting friends to play (TestFlight)

1. In [App Store Connect](https://appstoreconnect.apple.com) → **Apps** → **+** → **New App**: iOS, name "Plate Chase" (or any name that isn't taken), bundle ID `com.nikhilmath.licenseplategame`, any SKU.
2. Upload a build: in Xcode choose **Product → Archive**, then **Distribute App → TestFlight & App Store**.
3. In App Store Connect → the app → **TestFlight** → **External Testing** → **+** to create a group. Add the build, then turn on **Public Link**. Apple reviews the first external build, which usually takes under a day.
4. Send friends the public link. They install **TestFlight** from the App Store, open the link, and tap **Install**.
