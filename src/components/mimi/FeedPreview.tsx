// The learner's own first clips, playing inside the trial screen's phone mockup: the
// subtitles follow along, a finger taps a word, its card slides up, then it swipes to the
// next clip. Uses the YouTube thumbnail only (never the video). Mirrors
// mobile/lib/widgets/feed_preview.dart.
import { Bookmark, Check, Flame, Play, Pointer, Repeat, User } from "lucide-react";
import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState, type Ref } from "react";

import type { Clip, Content, Word } from "@/lib/content";
import { glossOf, thumbOf } from "@/lib/content";
import { feedOrder, useContent } from "@/lib/feed";
import { useApp } from "@/lib/store";
import { cn } from "@/lib/utils";

/** One clip line to demo: the line, the word the finger taps, and what its card shows. */
export type PreviewDemo = { clip: Clip; line: number; word: number; channel: string; gloss: string };

const TAPPABLE = new Set(["noun", "verb", "adjective"]);

/** A short, translated line with a dictionary word to tap (feed_preview.dart: previewDemoOf). */
export function previewDemoOf(c: Content, clip: Clip): PreviewDemo | null {
  for (let li = 0; li < clip.lines.length; li++) {
    const l = clip.lines[li]!;
    const real = l.words.filter((w) => w.p !== "punct").length;
    if (real < 3 || real > 9 || !l.en.trim()) continue;
    for (let wi = 0; wi < l.words.length; wi++) {
      const w = l.words[wi]!;
      if (w.p === "punct" || !w.d || !TAPPABLE.has(w.p) || [...w.s].length < 2) continue;
      const gloss = glossOf(c.dict[w.d]);
      if (!gloss) continue;
      return { clip, line: li, word: wi, channel: c.videos[clip.videoId]?.channel ?? "", gloss };
    }
  }
  return null;
}

/** Up to n demos from the learner's personal feed order. */
export function previewDemos(c: Content, order: string[], n = 3): PreviewDemo[] {
  const out: PreviewDemo[] = [];
  for (const id of order) {
    const clip = c.byId[id];
    const d = clip ? previewDemoOf(c, clip) : null;
    if (d) out.push(d);
    if (out.length >= n) break;
  }
  return out;
}

/** The lines shown after the demo line: up to n, skipping repeats of a sentence already on
 * screen (teachers often say a line twice; in a demo that just looks like a glitch). Mirrors
 * feed_preview.dart: previewFollowing. */
export function previewFollowing(clip: Clip, line: number, n = PREVIEW_FOLLOWING_LINES) {
  const seen = new Set([clip.lines[line]!.ja.trim()]);
  const out: Clip["lines"] = [];
  for (let li = line + 1; li < clip.lines.length && out.length < n; li++) {
    const l = clip.lines[li]!;
    if (seen.has(l.ja.trim())) continue;
    seen.add(l.ja.trim());
    out.push(l);
  }
  return out;
}

/** Loop timing (fractions of PREVIEW_LOOP_MS). */
export const PREVIEW_LOOP_MS = 7000;
/** How many transcript lines after the demo line the mockup shows (feed_preview.dart: previewFollowingLines). */
export const PREVIEW_FOLLOWING_LINES = 3;
const KARAOKE_END = 0.4, FINGER_IN = 0.47, CARD_IN = 0.5, CARD_OUT = 0.76, SWIPE_FROM = 0.82;

const ramp = (v: number, a: number, b: number) => Math.min(1, Math.max(0, (v - a) / (b - a)));
const easeOut = (t: number) => 1 - Math.pow(1 - t, 3);
const easeIn = (t: number) => t * t * t;
const easeInOut = (t: number) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);

export function FeedPreview() {
  const { data, error } = useContent();
  const demos = useMemo(() => (data ? previewDemos(data, feedOrder(data, useApp.getState())) : null), [data]);
  const still = useMemo(() => typeof window !== "undefined" && window.matchMedia?.("(prefers-reduced-motion: reduce)").matches, []);
  const [v, setV] = useState(0);
  const [i, setI] = useState(0);

  const boxRef = useRef<HTMLDivElement>(null);
  const wordRef = useRef<HTMLSpanElement>(null);
  const [wordAt, setWordAt] = useState<{ x: number; y: number } | null>(null);
  // Where the tapped word is right now (fonts and the thumbnail can still move it).
  const measure = useCallback(() => {
    const box = boxRef.current?.getBoundingClientRect();
    const w = wordRef.current?.getBoundingClientRect();
    if (!box || !w) return;
    const x = w.left - box.left + w.width / 2, y = w.top - box.top + w.height / 2;
    setWordAt((o) => (o && Math.abs(o.x - x) < 0.5 && Math.abs(o.y - y) < 0.5 ? o : { x, y }));
  }, []);
  useLayoutEffect(measure, [i, demos, measure]);

  useEffect(() => {
    if (!demos?.length || still) return;
    let raf = 0;
    let t0 = performance.now();
    const tick = (t: number) => {
      let p = (t - t0) / PREVIEW_LOOP_MS;
      if (p >= 1) {
        t0 = t;
        p = 0;
        setI((x) => (x + 1) % demos.length);
      }
      if (p > KARAOKE_END - 0.03 && p < CARD_IN + 0.07) measure();
      setV(p);
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [demos, still, measure]);

  if (error || (demos && demos.length === 0)) return <StaticPreview />;
  if (!demos) return <div className="h-full w-full bg-stage" />;

  const demo = demos[i % demos.length]!;
  const t = still ? 0.6 : v;
  const line = demo.clip.lines[demo.line]!;
  const realIdx = line.words.map((w, k) => (w.p === "punct" ? -1 : k)).filter((k) => k >= 0);
  const spoken = t < KARAOKE_END ? realIdx[Math.min(realIdx.length - 1, Math.floor((t / KARAOKE_END) * realIdx.length))]! : -1;
  const tapped = t >= FINGER_IN + 0.01;
  const cardV = ramp(t, CARD_IN, CARD_IN + 0.04) * (1 - ramp(t, CARD_OUT, CARD_OUT + 0.04));
  const swipeV = ramp(t, SWIPE_FROM, 1);
  // The lines after the demo line fill the page like the real feed's transcript.
  const after = previewFollowing(demo.clip, demo.line);

  // The finger lifts away as the card slides up, so the card never slides over it.
  const tapFinger = !still && wordAt && t >= KARAOKE_END && t < CARD_IN + 0.06
    ? (() => {
        const k = easeOut(ramp(t, KARAOKE_END, FINGER_IN));
        return { x: wordAt.x + 30 * (1 - k), y: wordAt.y + 60 * (1 - k), press: ramp(t, FINGER_IN - 0.01, FINGER_IN + 0.02), opacity: ramp(t, KARAOKE_END, KARAOKE_END + 0.03) * (1 - ramp(t, CARD_IN - 0.01, CARD_IN + 0.03)) };
      })()
    : null;
  const box = boxRef.current;
  const swipeFinger = !still && t >= SWIPE_FROM - 0.02 && box
    ? { x: box.clientWidth * 0.6, y: box.clientHeight * (0.78 - 0.4 * easeInOut(swipeV)), press: 1, opacity: 1 - ramp(t, 0.96, 1) }
    : null;

  return (
    <div ref={boxRef} className="relative h-full w-full overflow-hidden bg-stage" aria-label="Preview of your feed" role="img">
      {/* The feed page; it scrolls up as the finger swipes. */}
      <div className="absolute inset-0 flex flex-col" style={{ transform: `translateY(${-40 * easeIn(swipeV)}px)`, opacity: 1 - 0.6 * swipeV }}>
        <div className="flex items-center px-3 pb-2 pt-2.5">
          <span className="text-[0.6875rem] font-black">For you</span>
          <span className="ml-2.5 text-[0.6875rem] font-extrabold text-faint">Explore</span>
          <span className="ml-auto flex items-center text-[0.625rem] font-black text-primary"><Flame className="h-3 w-3" /> 1</span>
        </div>
        <div className="relative aspect-video w-full bg-surface-2">
          <img src={thumbOf(demo.clip.videoId)} alt="" className="h-full w-full object-cover" draggable={false} />
          <div className="absolute inset-x-0 bottom-0 h-[3px] bg-surface-3"><div className="h-full bg-primary" style={{ width: `${Math.max(2, t * 100)}%` }} /></div>
        </div>
        <p className="truncate px-2.5 pt-1 text-[0.5625rem] font-bold text-faint">{demo.channel ? `${demo.channel} · YouTube` : "YouTube"}</p>
        <div className="flex flex-wrap gap-y-1 px-2.5 pt-2.5">
          {line.words.map((w, k) => (
            <Token key={k} w={w} spoken={k === spoken} demo={k === demo.word} selected={k === demo.word && tapped && cardV > 0} saved={k === demo.word && tapped} ref={k === demo.word ? wordRef : undefined} />
          ))}
        </div>
        <p className="line-clamp-2 px-3 pt-1 text-[0.65625rem] font-semibold leading-snug text-muted-foreground">{line.en}</p>
        <div className="min-h-0 flex-1 overflow-hidden [mask-image:linear-gradient(to_bottom,black_70%,transparent)]">
          {after.map((l, k) => (
            <div key={k} className="px-3 pt-3">
              <p className="truncate font-jp text-[0.8125rem] font-bold text-faint">{l.ja}</p>
              {l.en && <p className="truncate text-[0.59375rem] font-semibold text-faint">{l.en}</p>}
            </div>
          ))}
        </div>
        <div className="mx-2.5 mb-2 flex h-[34px] items-center justify-evenly rounded-full bg-surface">
          <Play className="h-3.5 w-3.5 text-primary" />
          <Bookmark className="h-3.5 w-3.5 text-faint" />
          <Repeat className="h-3.5 w-3.5 text-faint" />
          <User className="h-3.5 w-3.5 text-faint" />
        </div>
      </div>

      {/* Word card. */}
      {cardV > 0 && (
        <div className="absolute inset-x-0 bottom-0 rounded-t-[18px] bg-surface px-3 pb-3 pt-1.5" style={{ transform: `translateY(${(1 - easeOut(cardV)) * 100}%)` }}>
          <div className="mx-auto h-[3px] w-7 rounded-full bg-surface-3" />
          <p className="mt-2 flex items-end gap-1.5">
            <span className="truncate font-jp text-[1.375rem] font-black leading-none">{line.words[demo.word]!.b || line.words[demo.word]!.s}</span>
            {line.words[demo.word]!.r && <span className="font-jp text-[0.6875rem] font-bold text-muted-foreground">{line.words[demo.word]!.r}</span>}
          </p>
          <p className="mt-0.5 line-clamp-2 text-[0.8125rem] font-extrabold">{demo.gloss}</p>
          <div className="mt-2 flex items-center gap-1.5">
            <span className="rounded-full bg-primary px-2 py-0.5 text-[0.625rem] font-black text-primary-foreground">Meaning</span>
            <span className="rounded-full bg-surface-2 px-2 py-0.5 text-[0.625rem] font-black text-muted-foreground">Explain</span>
            <span className="ml-auto flex items-center text-[0.625rem] font-black text-success"><Check className="h-3 w-3" strokeWidth={3} /> Saved</span>
          </div>
        </div>
      )}

      {tapFinger && <Finger {...tapFinger} />}
      {swipeFinger && <Finger {...swipeFinger} />}
    </div>
  );
}

function Finger({ x, y, press, opacity }: { x: number; y: number; press: number; opacity: number }) {
  return (
    <div className="pointer-events-none absolute" style={{ left: x - 10, top: y - 4, opacity }}>
      {press > 0 && press < 1 && (
        <span className="absolute rounded-full border-[3px] border-primary" style={{ left: -4 - 18 * press, top: -10 - 18 * press, width: 28 + 36 * press, height: 28 + 36 * press, opacity: 1 - press }} />
      )}
      <Pointer className="h-[30px] w-[30px] fill-foreground text-stage drop-shadow-[0_0_10px_var(--stage)]" style={{ transform: `scale(${1 - 0.12 * Math.sin(press * Math.PI)})` }} />
    </div>
  );
}

function Token({ w, spoken, demo, selected, saved, ref }: { w: Word; spoken: boolean; demo: boolean; selected: boolean; saved: boolean; ref?: Ref<HTMLSpanElement> | undefined }) {
  if (w.p === "punct") return <span className="font-jp text-[0.9375rem] font-bold leading-[1.5]">{w.s}</span>;
  const status = demo && saved ? "learning" : TAPPABLE.has(w.p) ? "new" : "known";
  return (
    <span ref={ref} className={cn("mr-px rounded-[5px] border-[1.5px] px-0.5", spoken ? "border-success" : "border-transparent", selected && "bg-primary/25")}>
      <span className={cn("block border-b-2 pb-px font-jp text-[0.9375rem] font-bold leading-[1.3]", status === "new" ? "border-info" : status === "learning" ? "border-learning" : "border-transparent", selected ? "text-primary" : "text-foreground")}>{w.s}</span>
    </span>
  );
}

/** Shown if the library couldn't load: the same scene, drawn. */
function StaticPreview() {
  return (
    <div className="h-full w-full space-y-2 bg-stage p-3">
      <p className="font-jp text-[1rem] font-bold leading-tight"><span className="rounded bg-primary/25 px-0.5 text-primary">今日</span>は<span className="underline decoration-learning decoration-2 underline-offset-4">楽しかった</span>ね！</p>
      <p className="text-[0.75rem] text-muted-foreground">Today was fun, wasn't it!</p>
    </div>
  );
}
