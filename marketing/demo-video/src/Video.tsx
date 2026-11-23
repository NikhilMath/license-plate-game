import React from 'react';
import {
  AbsoluteFill,
  Audio,
  Easing,
  Img,
  OffthreadVideo,
  Sequence,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
} from 'remotion';
import {Shot, Zoom, shots} from './shots';
import {FPS, chunks, section, sections} from './timeline';

const FONT = '"SF Pro Display", "SF Pro", -apple-system, system-ui, "Helvetica Neue", sans-serif';

// Colors from the app icon and the app's plate regions.
const BLUE_TOP = '#2083E0';
const BLUE_MID = '#1557B3';
const BLUE_BOTTOM = '#0A2B66';
const NAVY = '#123C82';
const RED = '#D2362B';
const GREEN = '#31B44B';
const YELLOW = '#FFD23F';
const REGION_COLORS = ['#215AB3', '#CC5429', '#298C4D', '#C78C14', '#80409E'];

// The phone screen: the simulator records at 1206 x 2622.
const SCREEN_W = 560;
const SCREEN_H = Math.round((SCREEN_W * 2622) / 1206);
const BEZEL = 14;
const PHONE_TOP = 290;
const PHONE_LEFT = (1080 - SCREEN_W) / 2 - BEZEL;
const SCREEN_RADIUS = 76;

const CAPTION_TOP = 1268;

const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;
const sec = (s: number) => Math.round(s * FPS);

// MARK: Background

const Background: React.FC = () => {
  const frame = useCurrentFrame();
  const t = frame / FPS;
  const codes = ['VT', 'TX', 'OH', 'CA', 'ME', 'NY', 'FL', 'MT'];
  return (
    <AbsoluteFill
      style={{background: `linear-gradient(172deg, ${BLUE_TOP} 0%, ${BLUE_MID} 48%, ${BLUE_BOTTOM} 100%)`}}
    >
      <AbsoluteFill
        style={{
          background: `radial-gradient(circle at ${18 + Math.sin(t / 3) * 4}% ${12 + Math.cos(t / 4) * 3}%, rgba(210,54,43,0.30), transparent 42%),
                       radial-gradient(circle at ${86 + Math.cos(t / 3.5) * 4}% ${88 + Math.sin(t / 5) * 3}%, rgba(49,180,75,0.26), transparent 40%)`,
        }}
      />
      {codes.map((code, i) => {
        const x = (i % 2 === 0 ? -60 : 760) + (i % 4) * 30;
        const y = 120 + i * 230 - ((t * 14 + i * 40) % 230);
        return (
          <div
            key={code}
            style={{
              position: 'absolute',
              left: x,
              top: y,
              fontFamily: 'ui-monospace, "SF Mono", Menlo, monospace',
              fontWeight: 900,
              fontSize: 190,
              color: 'white',
              opacity: 0.05,
              transform: `rotate(${i % 2 === 0 ? -8 : 7}deg)`,
            }}
          >
            {code}
          </div>
        );
      })}
    </AbsoluteFill>
  );
};

// MARK: Phone and shots

const zoomAt = (keys: Zoom[] | undefined, t: number): Zoom => {
  if (!keys || keys.length === 0) return {t, s: 1, x: 0.5, y: 0.5};
  if (t <= keys[0].t) return keys[0];
  for (let i = 0; i < keys.length - 1; i++) {
    const a = keys[i];
    const b = keys[i + 1];
    if (t <= b.t) {
      const p = Easing.inOut(Easing.cubic)((t - a.t) / Math.max(b.t - a.t, 0.001));
      return {t, s: a.s + (b.s - a.s) * p, x: a.x + (b.x - a.x) * p, y: a.y + (b.y - a.y) * p};
    }
  }
  return keys[keys.length - 1];
};

const TapRipple: React.FC<{x: number; y: number; at: number}> = ({x, y, at}) => {
  const frame = useCurrentFrame();
  const local = frame - sec(at);
  if (local < -3 || local > 16) return null;
  const press = interpolate(local, [-3, 0, 6, 14], [0, 1, 1, 0], clamp);
  const ring = interpolate(local, [0, 14], [0.4, 1.6], clamp);
  return (
    <>
      <div
        style={{
          position: 'absolute',
          left: x * SCREEN_W - 26,
          top: y * SCREEN_H - 26,
          width: 52,
          height: 52,
          borderRadius: 26,
          background: 'rgba(255,255,255,0.55)',
          border: '3px solid rgba(20,40,80,0.35)',
          opacity: press,
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: x * SCREEN_W - 34,
          top: y * SCREEN_H - 34,
          width: 68,
          height: 68,
          borderRadius: 34,
          border: '4px solid rgba(255,255,255,0.9)',
          transform: `scale(${ring})`,
          opacity: interpolate(local, [0, 14], [0.9, 0], clamp),
        }}
      />
    </>
  );
};

const ShotView: React.FC<{shot: Shot}> = ({shot}) => {
  const frame = useCurrentFrame();
  const z = zoomAt(shot.zoom, frame / FPS);
  const s = Math.max(z.s, 1);
  const tx = Math.min(0, Math.max(SCREEN_W - s * SCREEN_W, SCREEN_W / 2 - s * z.x * SCREEN_W));
  const ty = Math.min(0, Math.max(SCREEN_H - s * SCREEN_H, SCREEN_H / 2 - s * z.y * SCREEN_H));
  return (
    <AbsoluteFill style={{overflow: 'hidden', background: 'white'}}>
      <div
        style={{
          position: 'absolute',
          width: SCREEN_W,
          height: SCREEN_H,
          transformOrigin: '0 0',
          transform: `translate(${tx}px, ${ty}px) scale(${s})`,
        }}
      >
        <OffthreadVideo
          src={staticFile(`footage/${shot.clip}.mp4`)}
          trimBefore={Math.round(shot.from * FPS)}
          playbackRate={shot.rate ?? 1}
          muted
          style={{width: SCREEN_W, height: SCREEN_H}}
        />
        {(shot.taps ?? []).map((tap, i) => (
          <TapRipple key={i} x={tap.x} y={tap.y} at={tap.t} />
        ))}
      </div>
    </AbsoluteFill>
  );
};

type PlacedShot = {shot: Shot; from: number; frames: number; key: string};

const placedShots: PlacedShot[] = sections.flatMap((s) => {
  const list = shots[s.id] ?? [];
  const placed: PlacedShot[] = [];
  let cursor = sec(s.start);
  const end = sec(s.end);
  list.forEach((shot, i) => {
    const isLast = i === list.length - 1;
    const frames = isLast ? end - cursor : sec(shot.dur ?? 2);
    if (frames > 0) placed.push({shot, from: cursor, frames, key: `${s.id}-${i}`});
    cursor += frames;
  });
  return placed;
});

const Phone: React.FC = () => {
  const frame = useCurrentFrame();
  const outro = sec(section('outro').start);
  const enter = spring({frame: frame + 8, fps: FPS, config: {damping: 16, stiffness: 120}});
  const exit = interpolate(frame, [outro - 9, outro + 7], [0, 1], {...clamp, easing: Easing.in(Easing.cubic)});
  const y = interpolate(enter, [0, 1], [260, 0]) + exit * 1500;
  const scale = interpolate(enter, [0, 1], [0.92, 1]) * (1 - exit * 0.15);
  return (
    <div
      style={{
        position: 'absolute',
        left: PHONE_LEFT,
        top: PHONE_TOP,
        width: SCREEN_W + BEZEL * 2,
        height: SCREEN_H + BEZEL * 2,
        borderRadius: SCREEN_RADIUS + BEZEL,
        background: '#0D1117',
        padding: BEZEL,
        boxShadow: '0 40px 90px rgba(3,15,45,0.55), 0 10px 30px rgba(3,15,45,0.35), inset 0 0 0 2px rgba(255,255,255,0.12)',
        transform: `translateY(${y}px) scale(${scale})`,
        opacity: 1 - exit,
      }}
    >
      <div
        style={{
          position: 'relative',
          width: SCREEN_W,
          height: SCREEN_H,
          borderRadius: SCREEN_RADIUS,
          overflow: 'hidden',
          background: 'white',
        }}
      >
        {placedShots.map((p) => (
          <Sequence key={p.key} from={p.from} durationInFrames={p.frames} layout="none">
            <ShotView shot={p.shot} />
          </Sequence>
        ))}
      </div>
    </div>
  );
};

// MARK: Text

const HookCard: React.FC = () => {
  const frame = useCurrentFrame();
  const end = sec(section('hook').end);
  const pop = spring({frame: frame + 7, fps: FPS, config: {damping: 11, stiffness: 170, mass: 0.8}});
  const out = interpolate(frame, [end - 7, end + 1], [1, 0], clamp);
  if (frame > end + 2) return null;
  return (
    <div
      style={{
        position: 'absolute',
        top: 190,
        left: 80,
        width: 920,
        transform: `rotate(-3deg) scale(${interpolate(pop, [0, 1], [0.55, 1]) * (0.85 + 0.15 * out)})`,
        opacity: Math.min(1, pop * 1.6) * out,
        borderRadius: 40,
        background: 'white',
        border: `10px solid ${NAVY}`,
        overflow: 'hidden',
        boxShadow: '0 30px 70px rgba(3,15,45,0.5)',
        fontFamily: FONT,
        textAlign: 'center',
      }}
    >
      <div
        style={{
          background: RED,
          color: 'white',
          fontWeight: 900,
          fontSize: 36,
          letterSpacing: 6,
          padding: '12px 0 10px',
        }}
      >
        ROAD TRIP QUESTION
      </div>
      <div style={{color: NAVY, fontWeight: 900, fontSize: 92, lineHeight: 1.02, padding: '22px 20px 30px'}}>
        WHO SPOTTED
        <br />
        <span style={{color: RED}}>VERMONT</span> FIRST?
      </div>
    </div>
  );
};

const LABELS: Record<string, string> = {
  intro: 'The road trip game',
  spot: 'Tap to spot',
  players: 'Pass the phone',
  groups: 'Friend groups',
  modes: 'Compete or co-op',
};

const SectionLabel: React.FC = () => {
  const frame = useCurrentFrame();
  const current = sections.find((s) => frame >= sec(s.start) && frame < sec(s.end));
  if (!current || !LABELS[current.id]) return null;
  const local = frame - sec(current.start);
  const pop = spring({frame: local, fps: FPS, config: {damping: 14, stiffness: 200}});
  const out = interpolate(frame, [sec(current.end) - 5, sec(current.end)], [1, 0], clamp);
  const index = sections.indexOf(current);
  return (
    <div style={{position: 'absolute', top: 182, left: 0, width: 1080, display: 'flex', justifyContent: 'center'}}>
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 16,
          padding: '14px 30px',
          borderRadius: 40,
          background: 'rgba(255,255,255,0.16)',
          border: '2px solid rgba(255,255,255,0.28)',
          color: 'white',
          fontFamily: FONT,
          fontWeight: 800,
          fontSize: 34,
          letterSpacing: 3,
          textTransform: 'uppercase',
          transform: `translateY(${interpolate(pop, [0, 1], [-30, 0])}px)`,
          opacity: pop * out,
        }}
      >
        <div style={{width: 18, height: 18, borderRadius: 9, background: REGION_COLORS[index % REGION_COLORS.length], boxShadow: '0 0 0 3px white'}} />
        {LABELS[current.id]}
      </div>
    </div>
  );
};

const Captions: React.FC = () => {
  const frame = useCurrentFrame();
  const t = frame / FPS;
  const chunk = chunks.find((c) => t >= c.start && t < c.end && c.section !== 'hook');
  if (!chunk) return null;
  const local = frame - sec(chunk.start);
  const pop = spring({frame: local, fps: FPS, config: {damping: 13, stiffness: 260, mass: 0.6}});
  return (
    <div
      style={{
        position: 'absolute',
        top: CAPTION_TOP,
        left: 140,
        width: 800,
        display: 'flex',
        justifyContent: 'center',
      }}
    >
      <div
        style={{
          display: 'flex',
          flexWrap: 'wrap',
          justifyContent: 'center',
          columnGap: 22,
          fontFamily: FONT,
          fontWeight: 900,
          fontSize: 78,
          lineHeight: 1.1,
          textAlign: 'center',
          color: 'white',
          WebkitTextStroke: '13px #0A1F4A',
          paintOrder: 'stroke fill',
          textShadow: '0 8px 24px rgba(0,0,0,0.35)',
          transform: `scale(${interpolate(pop, [0, 1], [0.82, 1])})`,
          opacity: Math.min(1, pop * 2),
        }}
      >
        {chunk.words.map((w, i) => {
          // The word being spoken: the latest one to start, until shortly after it ends.
          const spoken = chunk.words.filter((x) => t >= x.start - 0.03).length - 1;
          const active = i === spoken && t < w.end + 0.25;
          return (
            <span key={i} style={{color: active ? YELLOW : 'white'}}>
              {w.text}
            </span>
          );
        })}
      </div>
    </div>
  );
};

// MARK: End card

const EndCard: React.FC = () => {
  const frame = useCurrentFrame();
  const outro = section('outro');
  const start = sec(outro.start);
  if (frame < start - 2) return null;
  const wordAt = (text: string) => sec((outro.words.find((w) => w.text.startsWith(text)) ?? outro.words[0]).start);
  const springAt = (at: number, delay = 0) =>
    spring({frame: frame - at - delay, fps: FPS, config: {damping: 12, stiffness: 160, mass: 0.7}});
  const icon = springAt(start, 5);
  const title = springAt(start, 10);
  const tech = springAt(Math.max(wordAt('Made') + 2, start + 16));
  const built = springAt(wordAt('Built'));
  const get = springAt(wordAt('Get'));
  const rise = (p: number) => ({opacity: Math.min(1, p * 1.5), transform: `translateY(${interpolate(p, [0, 1], [40, 0])}px)`});
  const chip = (label: string) => (
    <div
      style={{
        padding: '12px 26px',
        borderRadius: 30,
        background: 'rgba(255,255,255,0.16)',
        border: '2px solid rgba(255,255,255,0.3)',
        fontSize: 38,
        fontWeight: 700,
      }}
    >
      {label}
    </div>
  );
  return (
    <AbsoluteFill style={{fontFamily: FONT, color: 'white', alignItems: 'center'}}>
      <div
        style={{
          position: 'absolute',
          top: 250,
          width: 300,
          height: 300,
          borderRadius: 68,
          overflow: 'hidden',
          boxShadow: '0 30px 70px rgba(3,15,45,0.55), 0 0 0 4px rgba(255,255,255,0.25)',
          transform: `scale(${interpolate(icon, [0, 1], [0.4, 1])}) rotate(${interpolate(icon, [0, 1], [-14, 0])}deg)`,
          opacity: Math.min(1, icon * 2),
        }}
      >
        <Img src={staticFile('icon.png')} style={{width: 300, height: 300}} />
      </div>
      <div style={{position: 'absolute', top: 600, textAlign: 'center', ...rise(title)}}>
        <div style={{fontSize: 124, fontWeight: 900, letterSpacing: -2, textShadow: '0 10px 30px rgba(0,0,0,0.3)'}}>
          Plate Chase
        </div>
        <div style={{fontSize: 44, fontWeight: 600, opacity: 0.85, marginTop: 4}}>
          Spot all 50 states + DC
        </div>
      </div>
      <div style={{position: 'absolute', top: 860, display: 'flex', gap: 18, ...rise(tech)}}>
        {chip('SwiftUI')}
        {chip('CloudKit')}
      </div>
      <div style={{position: 'absolute', top: 975, fontSize: 56, fontWeight: 800, ...rise(built)}}>
        Built by Nikhil Math
      </div>
      <div
        style={{
          position: 'absolute',
          top: 1080,
          padding: '20px 44px',
          borderRadius: 50,
          background: 'white',
          color: NAVY,
          fontSize: 46,
          fontWeight: 900,
          display: 'flex',
          alignItems: 'center',
          gap: 16,
          boxShadow: '0 16px 40px rgba(3,15,45,0.4)',
          ...rise(get),
        }}
      >
        <div
          style={{
            width: 46,
            height: 46,
            borderRadius: 23,
            background: GREEN,
            color: 'white',
            fontSize: 32,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          ✓
        </div>
        Free on the App Store
      </div>
    </AbsoluteFill>
  );
};

// MARK: Composition

export const Demo: React.FC = () => (
  <AbsoluteFill style={{background: BLUE_BOTTOM}}>
    <Background />
    <Phone />
    <EndCard />
    <SectionLabel />
    <HookCard />
    <Captions />
    {sections.map((s) => (
      <Sequence key={s.id} from={sec(s.start)} layout="none">
        <Audio src={staticFile(s.file)} />
      </Sequence>
    ))}
  </AbsoluteFill>
);
