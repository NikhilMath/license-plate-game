# Plate Chase demo video

A 45-second vertical video (1080 × 1920, 30 fps, H.264 + AAC) for LinkedIn and TikTok. It's
made with [Remotion](https://www.remotion.dev): real simulator footage of the app in demo mode,
a Microsoft neural voice (Ava), word-timed captions, and an end card.

## Script and shots

| Time | Narration | On screen |
|---|---|---|
| 0–3s | Ever fought over who spotted that Vermont plate first? | Hook card: "Who spotted Vermont first?" Close-up of the Vermont plate being spotted. |
| 3–11s | Plate Chase is a free iPhone game for road trips. Spot license plates from all fifty states and D.C., with family or friends. | The Plates tab, switch to All, scroll through the grid. |
| 11–20s | See a plate? Tap it. Every state has its own plate, and your ring fills up as you go. Filter by what you still need, or search. | Spot Kansas and Maine, zoom on the ring (31 → 32), tap Spotted, search "new". |
| 20–24s | Everyone in the car can play on one phone, each with their own color. | Player menu, switch to Leo, everyone's dots on the plates. |
| 24–33s | Or play on separate phones. Start a group, text friends the code, and everyone's plates sync through iCloud. You can join as many groups as you like. | Leaderboard, Add Group menu, the group code and Invite, friends in the standings, switch to Road Trip Crew. |
| 33–37s | Race for the podium, or switch to co-op and fill one shared list as a team. | The podium, tap Co-op, the team ring. |
| 37–45s | Made with SwiftUI and CloudKit. Built by Nikhil Math. Get Plate Chase free on the App Store. | End card: icon, name, SwiftUI and CloudKit, "Built by Nikhil Math", "Free on the App Store". |

The narration lives in [`narration.json`](narration.json). Captions are 2–4 words at a time,
kept clear of the bottom 20% and the right-hand buttons on TikTok.

## Files

- `narration.json`: the words, voice and speed. `say` is what the voice reads; `captions` fixes
  how some words are spelled on screen (the voice reads "Swift U.I.", the caption says "SwiftUI").
- `tools/voiceover.py`: makes `public/voice/*.mp3` and `timings.json` (each word's timing).
- `recorder/`: an XCUITest that taps through the app at a human pace while the simulator
  records. It drives the installed app by bundle ID, so the app's own Xcode project doesn't
  change. `Explore.swift` prints each screen's accessibility tree, for finding elements.
- `tools/record.py`: builds and runs the recorder while `simctl` records, and writes
  `public/footage/<take>.mp4` (gitignored, about 27 MB).
- `src/shots.ts`: which part of the footage plays under each line, with zooms and tap ripples.
- `src/Video.tsx`: the composition (background, phone, hook card, captions, end card).
- `tools/finish.py`: brings the audio to -14 LUFS for social apps.

## Making it again

```bash
cd marketing/demo-video
npm install
brew install ffmpeg xcodegen
python3 -m venv .venv && .venv/bin/pip install edge-tts
.venv/bin/python tools/voiceover.py          # only if the narration changed
```

Install a Debug build of the app in the iPhone 18 Pro simulator (see `AGENTS.md`), then:

```bash
(cd recorder && xcodegen generate)
python3 tools/record.py take3 <simulator UDID>
npx remotion studio src/index.ts             # preview and adjust src/shots.ts
npm run render && python3 tools/finish.py    # out/plate-chase-demo-final.mp4
```

A new take puts every event at a different time, so update the `from` times in `src/shots.ts`.
Find them from the frames, not from the test's `DEMO-MARK` lines: `simctl` shortens stretches
where the screen doesn't change, so the test's clock drifts from the recording's by a few
seconds. The first seconds of a take show the simulator's home screen; don't use them.

The app runs with `-DemoMode`, which loads made-up players and friend groups and never talks
to CloudKit (`LicensePlateGame/LicensePlateGame/DemoData.swift`, Debug builds only).
