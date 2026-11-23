/**
 * What the phone shows during each narration section. Clips are simulator recordings in
 * public/footage/ (made by tools/record.py), and times are in seconds.
 *
 * - `from`: where the shot starts in the clip.
 * - `dur`: how long the shot lasts in the video. The last shot of a section fills what's left.
 * - `rate`: playback speed, to tighten slow stretches.
 * - `zoom`: camera keyframes. `t` is seconds into the shot; `x` and `y` are the point to centre
 *   on, as fractions of the screen; `s` is the zoom (1 = whole screen).
 * - `taps`: where a finger touches the screen, drawn as a ripple. Same units as `zoom`.
 *
 * Times in take3 were found from the frames themselves: simctl shortens stretches where the
 * screen doesn't change, so the test's own timestamps drift from the recording.
 */
export type Zoom = {t: number; s: number; x: number; y: number};
export type Tap = {t: number; x: number; y: number};
export type Shot = {clip: string; from: number; dur?: number; rate?: number; zoom?: Zoom[]; taps?: Tap[]};

const take = 'take3';

export const shots: Record<string, Shot[]> = {
  // "Ever fought over who spotted that Vermont plate first?" Vermont is spotted at 34.0.
  hook: [
    {
      clip: take,
      from: 31.8,
      zoom: [
        {t: 0, s: 2.6, x: 0.2, y: 0.7},
        {t: 3.2, s: 2.3, x: 0.2, y: 0.7},
      ],
      taps: [{t: 2.13, x: 0.1816, y: 0.7121}],
    },
  ],
  // "Plate Chase is a free iPhone game for road trips. Spot license plates from all 50 states…"
  intro: [
    {clip: take, from: 13.4, dur: 3.3, taps: [{t: 1.99, x: 0.8068, y: 0.3421}]},
    {
      clip: take,
      from: 18.8,
      rate: 1.3,
      zoom: [
        {t: 0, s: 1, x: 0.5, y: 0.5},
        {t: 5, s: 1.12, x: 0.5, y: 0.5},
      ],
    },
  ],
  // "See a plate? Tap it. Every state has its own plate, and your ring fills up as you go.
  //  Filter by what you still need, or search."
  spot: [
    {clip: take, from: 45.0, dur: 1.99, zoom: [{t: 0, s: 1.7, x: 0.3, y: 0.62}], taps: [{t: 0.95, x: 0.1816, y: 0.7445}]},
    {
      clip: take,
      from: 47.23,
      dur: 3.66,
      zoom: [
        {t: 0, s: 1.6, x: 0.4, y: 0.58},
        {t: 1.2, s: 1.35, x: 0.38, y: 0.48},
        {t: 1.75, s: 1.35, x: 0.38, y: 0.48},
        {t: 2.5, s: 2.3, x: 0.2, y: 0.31},
      ],
      taps: [{t: 1.52, x: 0.1816, y: 0.7445}],
    },
    {clip: take, from: 51.5, dur: 1.48, zoom: [{t: 0, s: 1.45, x: 0.5, y: 0.45}], taps: [{t: 0.59, x: 0.5, y: 0.4039}]},
    {clip: take, from: 64.0, rate: 1.5, zoom: [{t: 0, s: 1.35, x: 0.5, y: 0.3}]},
  ],
  // "Everyone in the car can play on one phone, each with their own color."
  players: [
    {clip: take, from: 72.55, dur: 1.15, zoom: [{t: 0, s: 1.6, x: 0.62, y: 0.2}], taps: [{t: 0.3, x: 0.8404, y: 0.0961}]},
    {
      clip: take,
      from: 76.1,
      dur: 1.25,
      zoom: [
        {t: 0, s: 1.6, x: 0.62, y: 0.2},
        {t: 1.25, s: 1.6, x: 0.38, y: 0.24},
      ],
      taps: [{t: 0.39, x: 0.6501, y: 0.1545}],
    },
    {
      clip: take,
      from: 81.3,
      zoom: [
        {t: 0, s: 1.5, x: 0.6, y: 0.5},
        {t: 1.5, s: 1.9, x: 0.7, y: 0.58},
      ],
    },
  ],
  // "Or play on separate phones. Start a group, text friends the code, and everyone's plates
  //  sync through iCloud. You can join as many groups as you like."
  groups: [
    {
      clip: take,
      from: 96.75,
      dur: 1.92,
      zoom: [
        {t: 0, s: 1, x: 0.5, y: 0.5},
        {t: 1.9, s: 1.1, x: 0.5, y: 0.4},
      ],
      taps: [{t: 0.27, x: 0.6177, y: 0.9405}],
    },
    {clip: take, from: 115.55, dur: 0.95, zoom: [{t: 0, s: 1.7, x: 0.63, y: 0.27}], taps: [{t: 0.12, x: 0.8018, y: 0.2712}]},
    {
      clip: take,
      from: 108.0,
      dur: 1.35,
      zoom: [
        {t: 0, s: 1.9, x: 0.66, y: 0.52},
        {t: 0.45, s: 1.9, x: 0.66, y: 0.52},
        {t: 1.2, s: 1.9, x: 0.3, y: 0.5},
      ],
    },
    {
      clip: take,
      from: 98.6,
      dur: 2.69,
      zoom: [
        {t: 0, s: 2.0, x: 0.35, y: 0.47},
        {t: 2.69, s: 1.25, x: 0.5, y: 0.7},
      ],
    },
    {clip: take, from: 102.3, zoom: [{t: 0, s: 1.25, x: 0.5, y: 0.33}], taps: [{t: 0.35, x: 0.9478, y: 0.2712}]},
  ],
  // "Race for the podium, or switch to co-op and fill one shared list as a team."
  modes: [
    {
      clip: take,
      from: 124.5,
      dur: 1.4,
      zoom: [
        {t: 0, s: 1.6, x: 0.5, y: 0.68},
        {t: 1.4, s: 1.75, x: 0.5, y: 0.66},
      ],
    },
    {
      clip: take,
      from: 129.55,
      zoom: [
        {t: 0, s: 1.5, x: 0.5, y: 0.36},
        {t: 0.9, s: 1.5, x: 0.5, y: 0.36},
        {t: 1.8, s: 1.3, x: 0.4, y: 0.55},
      ],
      taps: [{t: 0.47, x: 0.7036, y: 0.3415}],
    },
  ],
  // The phone drops away for the end card.
  outro: [{clip: take, from: 132.85, zoom: [{t: 0, s: 1.3, x: 0.4, y: 0.55}]}],
};
