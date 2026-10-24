import { Link } from "@tanstack/react-router";
import { ChevronRight, Trash2, Volume2 } from "lucide-react";

import type { Clip, Content } from "@/lib/content";
import { formatWhen, repeatsSense, wordLevel } from "@/lib/logic";
import { speak } from "@/lib/speech";
import { useApp, type SavedWord } from "@/lib/store";
import { cn } from "@/lib/utils";

import { Sheet } from "./ui";
import { LevelPill } from "./WordLevel";

/** The source sentence with the saved word highlighted. */
export function HighlightedLine({ clip, line, idx, className }: { clip: Clip; line: number; idx: number; className?: string }) {
  const l = clip.lines[line];
  if (!l) return null;
  return (
    <p className={cn("font-jp font-bold leading-snug", className)}>
      {l.words.map((w, i) => <span key={i} className={i === idx ? "text-primary" : undefined}>{w.s}</span>)}
    </p>
  );
}

export function SavedWordSheet({ word, content, open, onClose }: { word: SavedWord | null; content: Content | undefined; open: boolean; onClose: () => void }) {
  const { removeWord, setWordNote } = useApp.getState();
  const live = useApp((s) => (word ? s.words[word.key] : undefined));
  const w = live ?? word;
  if (!w) return null;
  const entry = w.dictId && content ? content.dict[w.dictId] : undefined;
  const clip = content?.byId[w.clipId];
  const level = wordLevel(w);
  const now = Date.now();
  const review = level >= 1 && level <= 4 ? (w.card.due <= now ? "Practice now" : `Next practice ${formatWhen(w.card.due - now)}`) : null;

  return (
    <Sheet open={open} onClose={onClose} maxHeight="88%">
      <div className="overflow-y-auto px-5 pb-4 pt-3 no-scrollbar">
        <div className="flex items-start gap-3">
          <div className="min-w-0 flex-1">
            {w.reading && w.reading !== w.word && <p className="font-jp text-[0.9375rem] font-bold text-muted-foreground">{w.reading}</p>}
            <p className="font-jp text-[2.25rem] font-black leading-tight">{w.word}</p>
            <p className="text-[0.9375rem] font-bold text-muted-foreground">{w.romaji}{w.jlpt ? <span className="ml-2 rounded-md bg-success-soft px-1.5 py-0.5 text-[0.75rem] font-extrabold text-success">N{w.jlpt}</span> : null}</p>
          </div>
          <button aria-label="Play pronunciation" onClick={() => speak(w.reading || w.word)} className="press mt-2 flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-surface-2"><Volume2 className="h-5 w-5" /></button>
          <button aria-label="Remove from Vocab" onClick={() => { removeWord(w.key); onClose(); }} className="press mt-2 flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-surface-2"><Trash2 className="h-[18px] w-[18px] text-danger" /></button>
        </div>

        <div className="mt-3 flex items-center gap-2.5">
          <LevelPill wordKey={w.key} word={w.word} onRemoved={onClose} />
          {review && <span className="min-w-0 flex-1 truncate text-[0.8125rem] font-bold text-muted-foreground">{review}</span>}
        </div>

        <div className="mt-4">
          {/* The clip meaning, unless the dictionary's first sense already says the same thing. */}
          {w.gloss && !(entry?.m[0] && repeatsSense(w.gloss, entry.m[0].g)) && <p className="text-[1.125rem] font-extrabold">{w.gloss}</p>}
          {entry && (
            <ol className="mt-2 space-y-1.5">
              {entry.m.map((m, i) => <li key={i} className="text-[0.9375rem] text-muted-foreground"><span className="mr-1.5 font-black text-foreground">{i + 1}.</span>{m.pos[0] && <span className="mr-1 text-[0.75rem] font-extrabold">[{m.pos[0]}]</span>}{m.g}</li>)}
            </ol>
          )}
        </div>

        {clip && (
          <div className="mt-5">
            <p className="mb-2 text-[0.6875rem] font-black uppercase tracking-[0.12em] text-muted-foreground">Where you found it</p>
            <HighlightedLine clip={clip} line={w.line} idx={w.idx} className="mt-2 text-[1.0625rem]" />
            <p className="text-[0.875rem] text-muted-foreground">{clip.lines[w.line]?.en}</p>
            <Link to="/clip/$clipId" params={{ clipId: clip.id }} onClick={onClose} className="press mt-2 flex items-center justify-between rounded-xl bg-surface-2 px-3 py-2.5 text-[0.875rem] font-extrabold">
              Watch the whole clip <ChevronRight className="h-4 w-4" />
            </Link>
          </div>
        )}

        <textarea
          key={w.key}
          defaultValue={w.note}
          onBlur={(e) => setWordNote(w.key, e.target.value.slice(0, 500))}
          placeholder="Add a note…"
          className="mt-4 h-20 w-full resize-none rounded-2xl border-2 border-border bg-surface-2 p-3 text-[0.9375rem] outline-none placeholder:text-faint focus:border-primary"
        />

      </div>
    </Sheet>
  );
}
