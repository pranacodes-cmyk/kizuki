import { Link } from "@tanstack/react-router";
import { Check, ChevronRight, EyeOff, RotateCcw, Trash2, Volume2 } from "lucide-react";

import type { Clip, Content } from "@/lib/content";
import { formatInterval, wordStatus } from "@/lib/logic";
import { speak } from "@/lib/speech";
import { useApp, type SavedWord } from "@/lib/store";
import { cn } from "@/lib/utils";

import { ContextPlayer } from "./ContextPlayer";
import { Sheet } from "./ui";

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
  const { setWordStatus, removeWord, setWordNote } = useApp.getState();
  const live = useApp((s) => (word ? s.words[word.key] : undefined));
  const w = live ?? word;
  if (!w) return null;
  const entry = w.dictId && content ? content.dict[w.dictId] : undefined;
  const clip = content?.byId[w.clipId];
  const status = w.status === "ignored" ? "ignored" : wordStatus({ status: w.status, card: w.card });
  const now = Date.now();

  return (
    <Sheet open={open} onClose={onClose} maxHeight="88%">
      <div className="overflow-y-auto px-5 pb-4 pt-3 no-scrollbar">
        <div className="flex items-start gap-3">
          <div className="min-w-0 flex-1">
            {w.reading && w.reading !== w.word && <p className="font-jp text-[0.9375rem] font-bold text-muted-foreground">{w.reading}</p>}
            <p className="font-jp text-[2.25rem] font-black leading-tight">{w.word}</p>
            <p className="text-[0.9375rem] font-bold text-muted-foreground">{w.romaji}{w.jlpt ? <span className="ml-2 rounded-md bg-success-soft px-1.5 py-0.5 text-[0.75rem] font-extrabold text-success">N{w.jlpt}</span> : null}</p>
          </div>
          <button aria-label="Play pronunciation" onClick={() => speak(w.reading || w.word)} className="press mt-2 flex h-11 w-11 items-center justify-center rounded-full bg-surface-2"><Volume2 className="h-5 w-5" /></button>
        </div>

        <div className={cn("mt-3 rounded-xl px-3 py-2 text-[0.875rem] font-extrabold", status === "known" ? "bg-success-soft text-success" : status === "ignored" ? "bg-surface-2 text-muted-foreground" : "bg-primary/15 text-primary")}>
          {status === "known" ? "✓ Known" : status === "ignored" ? "Ignored — never reviewed" : `Learning · next review ${w.card.due <= now ? "now" : `in ${formatInterval(w.card.due - now)}`}`}
        </div>

        <div className="mt-4">
          {w.gloss && <p className="text-[1.125rem] font-extrabold">{w.gloss}</p>}
          {entry && (
            <ol className="mt-2 space-y-1.5">
              {entry.m.map((m, i) => <li key={i} className="text-[0.9375rem] text-muted-foreground"><span className="mr-1.5 font-black text-foreground">{i + 1}.</span>{m.pos[0] && <span className="mr-1 text-[0.75rem] font-extrabold">[{m.pos[0]}]</span>}{m.g}</li>)}
            </ol>
          )}
        </div>

        {clip && (
          <div className="mt-5">
            <p className="mb-2 text-[0.6875rem] font-black uppercase tracking-[0.12em] text-muted-foreground">Where you found it</p>
            {open && <ContextPlayer clip={clip} line={w.line} autoplay={false} />}
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

        <div className="mt-3 grid grid-cols-3 gap-2">
          {status === "known" || status === "ignored" ? (
            <ActionBtn icon={<RotateCcw className="h-4 w-4" />} label="Learn again" onClick={() => setWordStatus(w.key, "learning")} />
          ) : (
            <ActionBtn icon={<Check className="h-4 w-4 text-success" strokeWidth={3} />} label="I know it" onClick={() => setWordStatus(w.key, "known")} />
          )}
          <ActionBtn icon={<EyeOff className="h-4 w-4" />} label="Ignore" onClick={() => setWordStatus(w.key, "ignored")} disabled={status === "ignored"} />
          <ActionBtn icon={<Trash2 className="h-4 w-4 text-danger" />} label="Remove" onClick={() => { removeWord(w.key); onClose(); }} />
        </div>
      </div>
    </Sheet>
  );
}

function ActionBtn({ icon, label, onClick, disabled }: { icon: React.ReactNode; label: string; onClick: () => void; disabled?: boolean }) {
  return (
    <button onClick={onClick} disabled={disabled} className="press flex h-12 items-center justify-center gap-1.5 rounded-xl bg-surface-2 text-[0.8125rem] font-extrabold disabled:opacity-40">
      {icon}{label}
    </button>
  );
}
