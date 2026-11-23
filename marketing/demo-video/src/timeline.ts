import timings from '../public/voice/timings.json';

export const FPS = 30;
export const WIDTH = 1080;
export const HEIGHT = 1920;

/** Silence between narration sections, in seconds. */
const GAP = 0.3;
/** How long the end card stays up after the last word. */
const END_HOLD = 2.0;

export type Word = {text: string; start: number; end: number};

export type Section = {
  id: string;
  file: string;
  /** When this section's audio starts, in seconds from the start of the video. */
  start: number;
  /** When the next section starts (or the video ends). */
  end: number;
  /** Words with times in seconds from the start of the video. */
  words: Word[];
};

const raw = timings.sections;

export const sections: Section[] = (() => {
  const out: Section[] = [];
  let cursor = 0;
  raw.forEach((s, i) => {
    const start = i === 0 ? 0 : cursor - s.words[0].start;
    const words = s.words.map((w) => ({text: w.text, start: start + w.start, end: start + w.end}));
    out.push({id: s.id, file: s.file, start, end: 0, words});
    cursor = start + s.words[s.words.length - 1].end + GAP;
  });
  out.forEach((s, i) => {
    s.end = i < out.length - 1 ? out[i + 1].start : s.words[s.words.length - 1].end + END_HOLD;
  });
  return out;
})();

export const section = (id: string): Section => {
  const found = sections.find((s) => s.id === id);
  if (!found) throw new Error(`No section ${id}`);
  return found;
};

export const DURATION = sections[sections.length - 1].end;
export const DURATION_FRAMES = Math.ceil(DURATION * FPS);

export type Chunk = {words: Word[]; start: number; end: number; section: string};

/**
 * Splits the narration into caption chunks of 2–4 words. Each phrase (up to a comma or full
 * stop) is split into the fewest chunks of at most 4 words, balanced by length.
 */
export const chunks: Chunk[] = (() => {
  const out: Chunk[] = [];
  for (const s of sections) {
    const phrases: Word[][] = [[]];
    s.words.forEach((w) => {
      phrases[phrases.length - 1].push(w);
      if (/[.,?!]$/.test(w.text)) phrases.push([]);
    });
    const merged = phrases.filter((p) => p.length).reduce<Word[][]>((acc, p) => {
      const prev = acc[acc.length - 1];
      if (prev && (prev.length === 1 || p.length === 1) && prev.length + p.length <= 4) prev.push(...p);
      else acc.push([...p]);
      return acc;
    }, []);
    for (const phrase of merged) {
      const n = Math.ceil(phrase.length / 4);
      const total = phrase.reduce((sum, w) => sum + w.text.length + 1, 0);
      let current: Word[] = [];
      let chars = 0;
      let made = 0;
      phrase.forEach((w, i) => {
        const left = phrase.length - i;
        const chunksLeft = n - made;
        const due = current.length > 0 && chunksLeft > 1
          && (current.length >= 4 || chars >= (total / n) * 0.85 || left < 2 * (chunksLeft - 1) + 0);
        if (due && left >= 2) {
          out.push({words: current, start: 0, end: 0, section: s.id});
          made += 1;
          current = [];
          chars = 0;
        }
        current.push(w);
        chars += w.text.length + 1;
      });
      if (current.length) out.push({words: current, start: 0, end: 0, section: s.id});
    }
  }
  out.forEach((c) => {
    c.start = c.words[0].start - 0.05;
  });
  out.forEach((c, i) => {
    const next = out[i + 1];
    const lastEnd = c.words[c.words.length - 1].end + 0.45;
    c.end = next ? Math.min(next.section === c.section ? next.start : lastEnd, next.start) : lastEnd;
  });
  return out;
})();
