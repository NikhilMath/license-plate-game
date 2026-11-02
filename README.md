# license-plate-game

**Plate Chase** is an iPhone game for spotting license plates from all 50 states and DC.

- Tap a plate when you spot it. Tap it again to remove it.
- Add players, switch who's playing from the menu at the top right, and see who's ahead on the Leaderboard.
- Colored dots on each plate show which players have spotted it.
- "New Road Trip" (Leaderboard ⋯ menu) clears everyone's plates.
- **Worldwide leaderboard (Game Center):** the phone owner's plate count is posted to Game Center, so everyone who downloads the app competes on one list. The first player you create is the owner. Change it with "This Is Me" on a player's page.

## Run it

Open `LicensePlateGame/LicensePlateGame.xcodeproj` in Xcode, pick your iPhone as the run destination, and press ⌘R.

## One-time Game Center setup (App Store Connect)

The worldwide leaderboard only works after the leaderboard exists in App Store Connect. Until then, the Worldwide section says it isn't set up yet. This needs a paid Apple Developer Program membership.

1. Go to [App Store Connect](https://appstoreconnect.apple.com) → **Apps** → **+** → **New App**.
   - Platform: iOS
   - Name: Plate Chase (or any name that isn't taken)
   - Bundle ID: `com.nikhilmath.licenseplategame`
   - SKU: anything, e.g. `platechase`
2. Open the app → **Services** (Game Center) → **Leaderboards** → **+** → **Classic Leaderboard**:
   - Reference name: `Plates Spotted`
   - Leaderboard ID: `com.nikhilmath.licenseplategame.plates` (must match `GameCenter.leaderboardID` in `GameCenter.swift`)
   - Score format: Integer
   - Score submission: **Best Score**
   - Sort order: High to Low
   - Score range: 0 to 51
   - Add an English localization: name `Most Plates Spotted`, suffix ` plates`
3. On the app's version page, turn on **Game Center** and add the leaderboard. Apple requires this before release.
4. Relaunch the app on your phone and pull down on the Leaderboard tab to refresh.

Because the leaderboard keeps each person's **best** score, starting a new road trip won't lower anyone's worldwide rank.

To get the app to other people, upload a build to **TestFlight** (Xcode → Product → Archive → Distribute) or release it on the App Store.
