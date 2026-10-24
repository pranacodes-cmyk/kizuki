import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { AnimatePresence, motion, useMotionValue, useTransform } from "motion/react";
import { Check, ChevronRight, Play, Pointer, Star, Volume2, X } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";
import { z } from "zod";

import { Confetti } from "@/components/mimi/Confetti";
import { ContextPlayer } from "@/components/mimi/ContextPlayer";
import { LivelyMascot, Mascot } from "@/components/mimi/Mascot";
import { HighlightedLine } from "@/components/mimi/SavedWordSheet";
import { POS_NAMES } from "@/components/mimi/WordCard";
import { Button, Modal, Screen, Sheet } from "@/components/mimi/ui";
import type { Content } from "@/lib/content";
import { useContent } from "@/lib/feed";
import { customStudyKeys, kanaDeck, kanaQueue, newCard, repeatsSense, ReviewSession, type Card, type Grade } from "@/lib/logic";
import { track } from '@/lib/analytics';
import { haptic } from "@/lib/haptics";
import { watchUrl } from "@/lib/youtube";
import { speak } from "@/lib/speech";
import { dueKeysOf, useApp, wordLites, type SavedWord } from "@/lib/store";
import { toast } from "@/lib/ui-store";
import { tourEmit } from "@/lib/tour-store";
import { cn } from "@/lib/utils";

/** How the review timing works, in plain words (no interval codes) — same text in review.dart. */
const REVIEW_DONE_NOTE = "Each word comes back right before you'd forget it. Forgotten words come back sooner.";

const searchSchema = z.object({ deck: z.enum(["words", "hiragana", "katakana"]).catch("words"), mode: z.enum(["extra"]).optional() });

export const Route = createFileRoute("/review")({
  validateSearch: (s) => searchSchema.parse(s),
  head: () => ({
    meta: [
      { title: "Review — Kizuki" },
      { name: "description", content: "Spaced-repetition flashcards with the original clip audio." },
      { property: "og:title", content: "Review — Kizuki" },
      { property: "og:description", content: "Spaced-repetition flashcards with the original clip audio." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: ReviewRoute,
});

function ReviewRoute() {
  const { deck, mode } = Route.useSearch();
  return <Review key={`${deck}-${mode ?? "due"}`} />;
}

function Review() {
  const { deck, mode } = Route.useSearch();
  const navigate = useNavigate();
  const { data } = useContent();
  const settings = useApp((s) => s.settings);
  const firstTime = useApp((s) => !s.tutorial.review);
  const kanaCards = useMemo(() => (deck === "words" ? [] : kanaDeck(deck)), [deck]);

  const session = useRef<ReviewSession | null>(null);
  const total = useRef(0);
  if (!session.current) {
    const s = useApp.getState();
    const now = Date.now();
    const ids = deck === "words" ? (mode === "extra" ? customStudyKeys(wordLites(s), now) : dueKeysOf(s)) : kanaQueue(kanaCards, s.kana, now);
    session.current = new ReviewSession(ids);
    total.current = ids.length;
  }
  const [, force] = useState(0);
  const [revealed, setRevealed] = useState(false);
  const [finished, setFinished] = useState(false);
  const [modal, setModal] = useState<null | "plan" | "rate">(null);

  const sess = session.current;
  const id = sess.current;
  const store = useApp.getState();
  const word = deck === "words" && id ? store.words[id] : undefined;
  const kana = deck !== "words" && id ? kanaCards.find((k) => k.id === id) : undefined;
  const card: Card | undefined = deck === "words" ? word?.card : id ? store.kana[id] ?? newCard(Date.now()) : undefined;

  useEffect(() => track('review_session_started', { deck, card_count: total.current, extra: mode === 'extra' }), []);
  const reveal = () => { track('review_card_revealed', { deck }); setRevealed(true); tourEmit("reveal"); };

  const answer = (g: Grade) => {
    if (!id || !card) return;
    track('review_answered', { deck, grade: g });
    const next = sess.answer(card, g, Date.now());
    if (deck === "words") store.answerWord(id, next);
    else store.answerKana(id, next);
    tourEmit("graded");
    // Remembered feels like a small win, Forgot stays gentle, the last card celebrates (review.dart).
    haptic(sess.done ? "celebrate" : g === "again" ? "light" : "success");
    setRevealed(false);
    if (sess.done) {
      store.finishReviewSession();
      store.completeTutorial("review");
      setFinished(true);
    }
    force((x) => x + 1);
  };

  const exit = () => {
    const s = useApp.getState();
    if (finished && !s.planModalSeen) return setModal("plan");
    if (finished && s.reviewSessions >= 2 && !s.ratingAsked) return setModal("rate");
    void navigate({ to: "/vocab" });
  };

  const progress = total.current ? Math.min(1, sess.answered / Math.max(total.current, sess.answered + sess.queue.length)) : 1;

  if (total.current === 0 || finished) {
    const extra = deck === "words" && customStudyKeys(wordLites(useApp.getState()), Date.now()).length > 0;
    return (
      <Screen className="items-center px-6 text-center">
        {finished && <Confetti />}
        <div className="flex flex-1 flex-col items-center justify-center">
          <LivelyMascot pose={finished ? "brave" : "cheer"} size={144} entrance hopAfter={400} tappable />
          <h1 className="mt-3 text-[1.75rem] font-black">{finished ? "Well done!" : "All caught up!"}</h1>
          <p className="mt-2 flex items-center gap-1.5 text-[1rem] font-extrabold text-success">
            <Check className="h-5 w-5" strokeWidth={3} /> {finished ? `${sess.answered} card${sess.answered === 1 ? "" : "s"} reviewed` : "Nothing due right now"}
          </p>
          <p className="mt-2.5 max-w-[300px] text-[0.9375rem] font-semibold leading-snug text-muted-foreground">{REVIEW_DONE_NOTE}</p>
        </div>
        <div className="w-full space-y-3 pb-2">
          <Button onClick={exit}>I'm done for now</Button>
          {extra && <Button variant="surface" onClick={() => {
            if (mode === "extra") { session.current = null; setFinished(false); setRevealed(false); force((x) => x + 1); }
            else void navigate({ to: "/review", search: { deck: "words", mode: "extra" }, replace: true });
          }}>Keep studying</Button>}
        </div>
        <PlanModal open={modal === "plan"} onDone={() => { useApp.getState().setPlanModalSeen(); setModal(null); void navigate({ to: "/vocab" }); }} />
        <RateModal open={modal === "rate"} onDone={() => { useApp.getState().setRatingAsked(); setModal(null); void navigate({ to: "/vocab" }); }} />
      </Screen>
    );
  }

  return (
    <Screen scroll={false}>
      <div className="flex h-12 shrink-0 items-center gap-3 px-4">
        <button aria-label="Close review" onClick={() => navigate({ to: "/vocab" })} className="press flex h-10 w-10 items-center justify-center rounded-full text-muted-foreground"><X className="h-6 w-6" /></button>
        <div className="h-3 flex-1 overflow-hidden rounded-full bg-surface-2"><motion.div className="h-full rounded-full bg-success" animate={{ width: `${Math.max(4, progress * 100)}%` }} /></div>
        <span className="w-10 text-right text-[0.8125rem] font-black text-muted-foreground tabular">{sess.queue.length}</span>
      </div>
      <div className="relative min-h-0 flex-1 px-4 pb-2 pt-1">
        <AnimatePresence mode="popLayout">
          {/* Kiku-style flashcard: the whole card is the one thing to tap (no separate "Show answer"). */}
          <SwipeCard key={`${id}-${sess.answered}`} revealed={revealed} onReveal={reveal} onSwipe={(g) => answer(g)}>
            {!revealed ? (
              <div className="relative flex h-full flex-col items-center justify-center text-center">
                {word && settings.flashFront === "en" ? (
                  <p className="text-[1.75rem] font-black">{word.gloss}</p>
                ) : (
                  <>
                    {word && settings.flashFurigana && word.reading !== word.word && <p className="font-jp text-[1.125rem] font-bold text-muted-foreground">{word.reading}</p>}
                    <p className="font-jp text-[3.5rem] font-black leading-tight">{word?.word ?? kana?.kana}</p>
                    {word && settings.flashRomaji && <p className="text-[1rem] font-bold text-muted-foreground">{word.romaji}</p>}
                  </>
                )}
                <p className="absolute inset-x-0 bottom-1 flex items-center justify-center gap-1.5 text-[0.9375rem] font-bold text-faint">
                  <Pointer className="h-4 w-4 shrink-0" />{firstTime ? "Remember it? Tap to reveal" : "Tap to reveal"}
                </p>
              </div>
            ) : word ? (
              <WordBack word={word} content={data} playerKey={`ctx-${id}-${sess.answered}`} />
            ) : (
              <div className="flex h-full flex-col items-center justify-center text-center">
                <p className="font-jp text-[4rem] font-black leading-none">{kana?.kana}</p>
                <p className="mt-4 text-[2rem] font-black text-primary">{kana?.romaji}</p>
                <button aria-label="Play sound" onClick={(e) => { e.stopPropagation(); if (kana) speak(kana.kana); }} className="press mt-5 flex h-12 w-12 items-center justify-center rounded-full bg-surface-2"><Volume2 className="h-5 w-5" /></button>
              </div>
            )}
          </SwipeCard>
        </AnimatePresence>
      </div>
      {/* Grade buttons slide in once the answer shows — before that the card is the only target. */}
      <AnimatePresence initial={false}>
        {revealed && card && (
          <motion.div key="grade" initial={{ height: 0, opacity: 0 }} animate={{ height: "auto", opacity: 1 }} exit={{ height: 0, opacity: 0 }} transition={{ duration: 0.22, ease: "easeOut" }} className="shrink-0 overflow-hidden">
            <div className="px-4 pb-2">
              {firstTime && <p className="mb-2 text-center text-[0.8125rem] font-bold text-faint">Did you remember it?</p>}
              {/* Plain words only — no "1m / 10m" timing codes; the app picks the timing. */}
              <div data-tour="grade" className="grid grid-cols-2 gap-3">
                <Button variant="ghost" onClick={() => answer("again")} className="h-[60px] !gap-2 !px-1 items-center justify-center rounded-2xl bg-danger-soft text-danger">
                  <X className="h-5 w-5 shrink-0" strokeWidth={3} /><span className="truncate text-[1.0625rem] font-black">Forgot</span>
                </Button>
                <Button variant="ghost" onClick={() => answer("good")} className="h-[60px] !gap-2 !px-1 items-center justify-center rounded-2xl bg-success-soft text-success">
                  <Check className="h-5 w-5 shrink-0" strokeWidth={3} /><span className="truncate text-[1.0625rem] font-black">Remembered</span>
                </Button>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </Screen>
  );
}

/** Answer side of a word card: word + reading/romaji/POS, numbered definition (the clip meaning
 * only when it adds something), then the original clip with the sentence highlighted. */
function WordBack({ word, content, playerKey }: { word: SavedWord; content: Content | undefined; playerKey: string }) {
  const [watching, setWatching] = useState(false);
  const clip = content?.byId[word.clipId];
  const entry = word.dictId ? content?.dict[word.dictId] : undefined;
  const senses = entry ? entry.m.slice(0, 3) : [];
  const pos = senses[0]?.pos[0] ?? (word.pos === "other" ? undefined : POS_NAMES[word.pos] ?? word.pos);
  const showClipMeaning = senses.length === 0 ? !!word.gloss : !repeatsSense(word.gloss, senses[0]?.g ?? "");
  return (
    <div className="h-full overflow-y-auto no-scrollbar">
      <div className="flex items-start gap-3">
        <div className="min-w-0 flex-1">
          {word.reading !== word.word && <p className="font-jp text-[1rem] font-bold text-muted-foreground">{word.reading}</p>}
          <p className="font-jp text-[2.5rem] font-black leading-tight">{word.word}</p>
          <div className="mt-1 flex flex-wrap items-center gap-1.5">
            <span className="text-[0.9375rem] font-bold text-muted-foreground">{word.romaji}</span>
            {pos && <span className="rounded-md bg-surface-2 px-2 py-0.5 text-[0.75rem] font-extrabold">{pos}</span>}
            {word.jlpt ? <span className="rounded-md bg-success-soft px-2 py-0.5 text-[0.75rem] font-extrabold text-success">N{word.jlpt}</span> : null}
          </div>
        </div>
        <button aria-label="Play pronunciation" onClick={(e) => { e.stopPropagation(); speak(word.reading || word.word); }} className="press mt-2 flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-surface-2"><Volume2 className="h-5 w-5" /></button>
      </div>

      <p className="mt-4 text-[0.6875rem] font-black uppercase tracking-[0.12em] text-muted-foreground">Definition</p>
      <div className="mt-2">
        {showClipMeaning && (
          <p className="mb-2 rounded-xl bg-primary/10 px-3 py-2 text-[1rem] font-extrabold"><span className="text-[0.875rem] text-primary">In this clip: </span>{word.gloss}</p>
        )}
        {senses.map((m, i) => (
          <div key={i} className="mb-2 flex items-start gap-2.5">
            <span className="flex h-[22px] w-[22px] shrink-0 items-center justify-center rounded-full bg-surface-2 text-[0.75rem] font-black">{i + 1}</span>
            <p className={cn("leading-snug", i === 0 ? "text-[1.0625rem] font-extrabold" : "text-[0.9375rem] text-muted-foreground")}>{m.g}</p>
          </div>
        ))}
      </div>

      {clip && (
        <>
          <p className="mt-5 text-[0.6875rem] font-black uppercase text-muted-foreground">Example sentence</p>
          <HighlightedLine clip={clip} line={word.line} idx={word.idx} className="mt-2 text-[1.25rem]" />
          <p className="mt-1.5 text-[0.9375rem] leading-relaxed text-muted-foreground">{clip.lines[word.line]?.en}</p>
          <Button variant="surface" size="md" className="mt-4 w-full" onClick={() => setWatching(true)}><Play className="h-4 w-4" />Watch original</Button>
          <Sheet open={watching} onClose={() => setWatching(false)}>
            <div className="overflow-y-auto px-4 pb-5 pt-2">
              <h2 className="mb-3 text-[1.125rem] font-black">{clip.title}</h2>
              {watching && <ContextPlayer key={playerKey} clip={clip} line={word.line} autoplay />}
              <a href={watchUrl(clip.videoId, clip.start)} target="_blank" rel="noreferrer" className="mt-2 block text-sm text-muted-foreground">{content?.videos[clip.videoId]?.channel ?? "YouTube"} · Watch on YouTube</a>
              <HighlightedLine clip={clip} line={word.line} idx={word.idx} className="mt-3 text-[1.0625rem]" />
              <Link to="/clip/$clipId" params={{ clipId: clip.id }} className="press mt-3 flex items-center text-[0.875rem] font-extrabold text-muted-foreground"><span className="flex-1">Open the clip</span><ChevronRight className="h-4 w-4" /></Link>
            </div>
          </Sheet>
        </>
      )}
    </div>
  );
}

/** The flashcard: tap anywhere to flip it; once revealed, swipe right = Good, left = Again. */
function SwipeCard({ children, revealed, onReveal, onSwipe }: { children: React.ReactNode; revealed: boolean; onReveal: () => void; onSwipe: (g: Grade) => void }) {
  const x = useMotionValue(0);
  const rotate = useTransform(x, [-200, 200], [-10, 10]);
  const good = useTransform(x, [20, 120], [0, 1]);
  const again = useTransform(x, [-120, -20], [1, 0]);
  return (
    <motion.div
      data-tour={revealed ? undefined : "reviewCard"}
      role={revealed ? undefined : "button"}
      aria-label={revealed ? undefined : "Reveal the answer"}
      className={cn("absolute inset-x-4 inset-y-0 [perspective:1200px]", !revealed && "cursor-pointer")}
      style={{ x, rotate }}
      initial={{ opacity: 0, scale: 0.94, y: 16 }}
      animate={{ opacity: 1, scale: 1, y: 0 }}
      exit={{ opacity: 0, x: x.get() >= 0 ? 260 : -260, transition: { duration: 0.22 } }}
      drag={revealed ? "x" : false}
      dragConstraints={{ left: 0, right: 0 }}
      dragElastic={0.9}
      onDragEnd={(_, info) => {
        if (info.offset.x > 110) onSwipe("good");
        else if (info.offset.x < -110) onSwipe("again");
      }}
      onClick={() => !revealed && onReveal()}
    >
      {/* Flip: the front turns away, then the answer turns in. */}
      <AnimatePresence mode="wait" initial={false}>
        <motion.div
          key={revealed ? "back" : "front"}
          className="absolute inset-0 rounded-[28px] bg-surface p-5 shadow-[0_20px_50px_-20px_oklch(0_0_0/0.6)]"
          initial={{ rotateY: -90 }}
          animate={{ rotateY: 0, transition: { duration: 0.18, ease: "easeOut" } }}
          exit={{ rotateY: 90, transition: { duration: 0.18, ease: "easeIn" } }}
        >
          {children}
        </motion.div>
      </AnimatePresence>
      <motion.span style={{ opacity: good }} className="pointer-events-none absolute right-4 top-4 rounded-lg border-2 border-success bg-surface px-2 py-0.5 text-[0.875rem] font-black text-success">REMEMBERED</motion.span>
      <motion.span style={{ opacity: again }} className="pointer-events-none absolute left-4 top-4 rounded-lg border-2 border-danger bg-surface px-2 py-0.5 text-[0.875rem] font-black text-danger">FORGOT</motion.span>
    </motion.div>
  );
}

function PlanModal({ open, onDone }: { open: boolean; onDone: () => void }) {
  const months = useApp((s) => s.profile.fluencyMonths);
  const minutes = useApp((s) => s.profile.dailyMinutes);
  const [ready, setReady] = useState(false);
  return (
    <Modal open={open}>
      <h2 className="text-center text-[1.375rem] font-black leading-tight">This is how you'll understand Japanese in {months} months</h2>
      <div className="mt-5 space-y-3">
        {[["▶️", "Watch clips"], ["🔖", "Save words"], ["🔁", "Review daily"]].map(([i, t], n) => (
          <motion.div key={t} initial={{ opacity: 0, x: -12 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: 0.2 + n * 0.25 }} className="flex items-center gap-3 rounded-2xl bg-surface-2 px-4 py-3 text-[1rem] font-extrabold">
            <span className="text-[1.5rem]">{i}</span>{t}
          </motion.div>
        ))}
      </div>
      <p className="mt-4 text-center text-[0.9375rem] text-muted-foreground">It's that simple. Show up for {minutes} minutes a day and you'll surprise yourself.</p>
      <button disabled={!ready} onClick={onDone} className="btn-3d relative mt-5 h-14 w-full overflow-hidden rounded-2xl bg-primary-dim font-extrabold text-primary-foreground">
        <motion.span className="absolute inset-y-0 left-0 bg-primary" initial={{ width: "0%" }} animate={open ? { width: "100%" } : {}} transition={{ duration: 2.2, ease: "linear" }} onAnimationComplete={() => setReady(true)} />
        <span className="relative">Let's do it!</span>
      </button>
    </Modal>
  );
}

function RateModal({ open, onDone }: { open: boolean; onDone: () => void }) {
  const [stars, setStars] = useState(5);
  return (
    <Modal open={open} onClose={onDone}>
      <div className="flex flex-col items-center text-center">
        <Mascot pose="heart" className="h-24 w-24" />
        <h2 className="mt-2 text-[1.375rem] font-black">How is Kizuki doing?</h2>
        <p className="mt-1 text-[0.9375rem] text-muted-foreground">A quick rating helps more learners find us. Thank you!</p>
        <div className="mt-4 flex gap-1.5">
          {[1, 2, 3, 4, 5].map((n) => (
            <button key={n} aria-label={`${n} stars`} onClick={() => setStars(n)}><Star className={cn("h-9 w-9", n <= stars ? "fill-gold text-gold" : "text-surface-3")} /></button>
          ))}
        </div>
        <Button className="mt-5" onClick={() => { toast({ icon: "💛", title: "Thanks for rating Kizuki!" }); onDone(); }}>Rate Kizuki</Button>
        <button onClick={onDone} className="press mt-2 py-2 text-[0.875rem] font-bold text-muted-foreground">Not now</button>
      </div>
    </Modal>
  );
}
