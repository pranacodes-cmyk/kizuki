import { BookOpen, Check, ChevronDown, Trash2, X } from "lucide-react";
import { useState } from "react";

import { formatWhen, WORD_LEVELS, wordLevel, wordLevelInfo } from "@/lib/logic";
import { useApp } from "@/lib/store";
import { cn } from "@/lib/utils";

import { Button, Hi, Sheet } from "./ui";
import { tr } from "@/lib/i18n";

/** Word level colours (Kiku's colour legend): 1 bright orange fading to brown by 4, green
 * when known, red when ignored — mirrors levelColor in word_level.dart. */
const LEVEL_BG = ["bg-danger", "bg-learning", "bg-level-2", "bg-level-3", "bg-level-4", "bg-success"];
const LEVEL_TINT = ["bg-danger/15", "bg-learning/15", "bg-level-2/15", "bg-level-3/15", "bg-level-4/15", "bg-success/15"];
const levelIndex = (level: number) => Math.min(5, Math.max(0, level));

/** Round level badge: the number for learning levels, ✓ when known, × when ignored. */
export function LevelBadge({ level, size = 22 }: { level: number; size?: number }) {
  const i = levelIndex(level);
  const fg = i >= 1 && i <= 2 ? "text-primary-foreground" : i === 5 || i === 0 ? "text-stage" : "text-foreground";
  return (
    <span
      aria-label={tr("Level: {level}", { level: i >= 1 && i <= 4 ? tr("Learning") : tr(wordLevelInfo(i).label) })}
      className={cn("flex shrink-0 items-center justify-center rounded-full font-black leading-none", LEVEL_BG[i], fg)}
      style={{ width: size, height: size, fontSize: size * 0.55 }}
    >
      {i === 5 ? <Check style={{ width: size * 0.6, height: size * 0.6 }} strokeWidth={3} /> : i === 0 ? <X style={{ width: size * 0.6, height: size * 0.6 }} strokeWidth={3} /> : <BookOpen style={{ width: size * 0.6, height: size * 0.6 }} />}
    </span>
  );
}

/** The one status button on a saved word: badge + level name. Opens the level sheet. */
export function LevelPill({ wordKey, word, onRemoved }: { wordKey: string; word: string; /** Called after the learner removed the word from the level sheet. */ onRemoved?: (() => void) | undefined }) {
  const w = useApp((s) => s.words[wordKey]);
  const [open, setOpen] = useState(false);
  if (!w) return null;
  const level = wordLevel(w);
  return (
    <>
      <button
        data-testid="level-pill"
        aria-label={tr("Word level: {level}. Change", { level: level >= 1 && level <= 4 ? tr("Learning") : tr(wordLevelInfo(level).label) })}
        onClick={() => setOpen(true)}
        className={cn("press flex h-11 min-w-0 items-center gap-2 rounded-xl pl-2 pr-2.5", LEVEL_TINT[levelIndex(level)])}
      >
        <LevelBadge level={level} size={26} />
        <span className={cn("truncate text-[0.9375rem] font-extrabold", level === 0 ? "text-muted-foreground" : "text-foreground")}>{level >= 1 && level <= 4 ? tr("Learning") : wordLevelInfo(level).label}</span>
        <ChevronDown className="h-4 w-4 shrink-0 text-muted-foreground" />
      </button>
      <WordLevelSheet open={open} onClose={() => setOpen(false)} wordKey={wordKey} word={word} onRemoved={onRemoved} />
    </>
  );
}

/** "How well do you know …?" — pick a level (reschedules reviews to match), or remove the word. */
export function WordLevelSheet({ open, onClose, wordKey, word, onRemoved }: { open: boolean; onClose: () => void; wordKey: string; word: string; onRemoved?: (() => void) | undefined }) {
  const w = useApp((s) => s.words[wordKey]);
  const { setWordLevel, removeWord } = useApp.getState();
  if (!w) return null;
  const current = wordLevel(w);
  const now = Date.now();
  const review = current >= 1 && current <= 4 ? tr("Next practice: {when}", { when: formatWhen(w.card.due - now) }) : null;
  return (
    <Sheet open={open} onClose={onClose} maxHeight="80%">
      <div className="overflow-y-auto px-5 pb-3 pt-2 no-scrollbar">
        <h2 className="text-[1.25rem] font-black leading-tight"><Hi text={tr("How well do you know [{word}]?", { word })} className="font-jp" /></h2>
        {review && <p className="mt-1 text-[0.875rem] font-bold text-muted-foreground">{review}</p>}
        <div className="mt-3 space-y-1.5">
          {[WORD_LEVELS[0], WORD_LEVELS[4], WORD_LEVELS[5]].filter((l) => l !== undefined).map((l) => (
            <Button variant="ghost"
              key={l.level}
              aria-pressed={(l.level === 1 ? current >= 1 && current <= 4 : l.level === current)}
              onClick={() => { if (!(l.level === 1 && current >= 1 && current <= 4)) setWordLevel(wordKey, l.level); onClose(); }}
              className={cn("!h-auto !justify-start !gap-3 !px-3 !py-2.5 flex w-full items-center gap-3 rounded-[14px] border-2 px-3 py-2.5 text-left", (l.level === 1 ? current >= 1 && current <= 4 : l.level === current) ? "border-border bg-surface-2" : "border-transparent")}
            >
              <LevelBadge level={l.level} size={30} />
              <span className="min-w-0 flex-1">
                <span className="block text-[1rem] font-extrabold">{l.level === 1 ? tr("Learning") : tr(l.label)}</span>
                <span className="block text-[0.8125rem] font-semibold text-muted-foreground">{l.level === 1 ? tr("Keep this word in my reviews") : l.level === 5 ? tr("I know this word") : tr("Leave this word out")}</span>
              </span>
              {(l.level === 1 ? current >= 1 && current <= 4 : l.level === current) && <Check className="h-5 w-5 shrink-0 text-primary" strokeWidth={3} />}
            </Button>
          ))}
        </div>
        <div className="my-2.5 h-px bg-border" />
        <button onClick={() => { removeWord(wordKey); onClose(); onRemoved?.(); }} className="press flex w-full items-center gap-3 rounded-[14px] px-3 py-2.5 text-left">
          <span className="flex w-[30px] justify-center"><Trash2 className="h-5 w-5 text-danger" /></span>
          <span className="text-[1rem] font-extrabold text-danger">{tr("Remove from Vocab")}</span>
        </button>
      </div>
    </Sheet>
  );
}
