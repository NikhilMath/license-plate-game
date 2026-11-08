# App Review notes

On 2026-11-07, App Review sent back version 1.0 (build 1.0 (2)) under **Guideline 2.1 - Information Needed**. They asked for a screen recording and six answers in the **Notes** field of **App Review Information**. This file keeps that text so it can be reused or updated for later versions.

## Notes field (paste as is)

This is the text saved in App Store Connect on 2026-11-07. Keep it under the 4,000-character limit. If a later recording leaves out a step listed in section 1, remove that step from the text. For a new recording, update the first line to say where the video is.

```text
1. SCREEN RECORDING
Attached to our Nov 7 reply in the App Review messages (ScreenRecording_11-07-2026 22-47-43_1.MP4). Recorded on an iPhone running the latest iOS, using build 1.0 (2). It starts at app launch and shows: entering a name on the welcome screen, spotting plates and removing one, the Needed / Spotted / All filter and search, adding a second player and switching between players, the Leaderboard and a player's detail page, creating a friend group, a second iPhone joining with the group code and showing up on the leaderboard, leaving the group, and New Road Trip.

The app has no accounts, sign-in, or account creation, so there is no registration or account deletion flow. It has no purchases or paid features. It has no public user-generated content: a player's name and spotted plates are shared only with people who join the same private friend group by entering its 6-character code, and Leave Group removes them from the group.

2. PURPOSE AND AUDIENCE
Plate Chase is the road trip license plate game for families and friends of all ages. Players tap a plate when they spot one from any of the 50 states or DC, and the leaderboard shows who's ahead. It replaces the paper checklist, keeps several players on one phone, and lets friends and family in other cars play along on their own phones.

3. HOW TO USE IT
No login, demo account, or sample files are needed.
- Launch the app, type any name, and tap Start Playing.
- Plates tab: tap a plate to mark it spotted. Tap a spotted plate to remove it (the app asks first). Use Needed / Spotted / All to filter, or search by state. The player menu at the top switches who is playing.
- Leaderboard tab: the person+ button adds a player. Tap a player to see their plates. Swipe left to remove a player. The ... menu has New Road Trip, which clears every plate.
- Friend groups (optional; the device must be signed in to iCloud): on the Leaderboard, tap Create Group to get a 6-character code. On a second device, tap Join with Code and enter it. Each phone's players appear on the other's leaderboard within about 30 seconds, or pull down to refresh. Without iCloud, the app says so and everything else works normally.

4. EXTERNAL SERVICES
Apple CloudKit (the public database in the app's own iCloud container) stores friend group members and their spotted plates. It is the only external service. There are no third-party SDKs, analytics, ads, sign-in services, payment processors, or AI services. Everything else is stored only on the device.

5. REGIONAL DIFFERENCES
None. The app works the same everywhere. It is offered in the United States only because the game is about U.S. license plates.

6. REGULATED INDUSTRY / THIRD-PARTY MATERIAL
Not applicable. The plate cards are original designs: a state's abbreviation, name, and nickname on a color band for its region. They don't reproduce any state's license plate artwork, seals, or logos.

Contact: Nikhil Math, nikhil@nikhilmath.com
```

## Screen recording checklist

Apple requires a recording from a **physical iPhone** on the **latest iOS**, starting with the app launch.

1. Update the iPhone first: **Settings → General → Software Update**.
2. Install build **1.0 (2)** from TestFlight. To start on the welcome screen, delete the app and reinstall it from TestFlight. This clears the players saved on that phone.
3. Open **Control Center → Screen Recording**, go to the Home Screen, and tap the Plate Chase icon.
4. Go through the steps listed in section 1 of the notes. Keep it to about 2 minutes. Joining a group needs a second iPhone with the TestFlight build. Without one, show **Create Group** and its code, then remove "a second iPhone joining…" from the notes.
5. Stop the recording. It's saved to Photos.

## Sending it back

What was done on 2026-11-07:

1. The owner sent the notes and the video to Apple with **Reply to App Review** on the submission page. The reply's attachment is where the reviewer finds the video.
2. The same text went into **Distribution → iOS App 1.0 → App Review Information → Notes**, then **Save**. The version status changed to **Ready for Review**.
3. Last step: on the submission page (**App Review** in the sidebar → the 1.0 submission), click **Resubmit to App Review**. The status becomes **Waiting for Review**. No new build is needed.
