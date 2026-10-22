import { MoreVertical } from "lucide-react";
import { memo } from "react";

import type { Clip, Word } from "@/lib/content";
import type { Settings } from "@/lib/store";
import { cn } from "@/lib/utils";

export type TokenStatus = "new" | "learning" | "known" | "ignored";

type Props = {
  clip: Clip;
  time: number;
  settings: Settings;
  statusOf: (w: Word) => TokenStatus;
  selected: { line: number; idx: number } | null;
  onWord: (line: number, idx: number) => void;
  onLine: (line: number) => void;
  onLineMenu: (line: number) => void;
  /** The word the welcome tour spotlights, if any. */
  tourWord?: { line: number; idx: number } | null;
};

/** Index of the line being spoken (last line whose start ≤ t), -1 before the first line. */
export function activeLineIndex(clip: Clip, t: number) {
  let idx = -1;
  for (let i = 0; i < clip.lines.length; i++) if (clip.lines[i]!.start <= t + 0.05) idx = i;
  return idx;
}

/** Interactive transcript: furigana, romaji, translation, status underlines and karaoke highlight. */
export const Transcript = memo(function Transcript({ clip, time, settings, statusOf, selected, onWord, onLine, onLineMenu, tourWord }: Props) {
  const current = activeLineIndex(clip, time);
  const scale = settings.textSize;
  return (
    <div className="space-y-1.5 px-3 pb-4 pt-2">
      {clip.lines.map((line, li) => {
        const active = li === current;
        return (
          <div
            key={li}
            data-line={li}
            onClick={() => onLine(li)}
            className={cn("group relative cursor-pointer rounded-2xl py-2.5 pl-3 pr-9 transition-colors", active ? "bg-surface" : "opacity-60 hover:opacity-90")}
          >
            {line.sp && <p className="mb-0.5 text-[0.6875rem] font-black uppercase tracking-[0.1em] text-faint">{line.sp}</p>}
            <div className={cn("flex flex-wrap items-end font-jp", settings.spacing ? "gap-x-1.5 gap-y-1" : "gap-0")} style={{ fontSize: `${1.3 * scale}rem` }}>
              {groupTokens(line.words).map(({ wi, trail }) => {
                const w = line.words[wi]!;
                return (
                  <Token
                    key={wi}
                    w={w}
                    trail={trail}
                    status={w.p === "punct" ? "known" : statusOf(w)}
                    speaking={settings.highlight && active && time >= w.t0 && time < w.t1 && w.p !== "punct"}
                    selected={selected?.line === li && selected.idx === wi}
                    furigana={settings.furigana}
                    romaji={settings.romaji}
                    onTap={w.p === "punct" ? undefined : () => onWord(li, wi)}
                    tour={tourWord?.line === li && tourWord.idx === wi ? "word" : undefined}
                  />
                );
              })}
            </div>
            {settings.translation && <p className="mt-1.5 text-muted-foreground" style={{ fontSize: `${0.9375 * scale}rem` }}>{line.en}</p>}
            <button
              aria-label="Line options"
              onClick={(e) => { e.stopPropagation(); onLineMenu(li); }}
              className="absolute right-1 top-2 flex h-8 w-8 items-center justify-center rounded-full text-faint hover:text-foreground"
            >
              <MoreVertical className="h-4 w-4" />
            </button>
          </div>
        );
      })}
    </div>
  );
});

/** Punctuation sticks to the word before it so "。" never wraps onto its own line. */
export function groupTokens(words: Word[]) {
  const out: { wi: number; trail: string }[] = [];
  words.forEach((w, wi) => {
    const last = out[out.length - 1];
    if (w.p === "punct" && last) last.trail += w.s;
    else out.push({ wi, trail: "" });
  });
  return out;
}

function Token({ w, trail, status, speaking, selected, furigana, romaji, onTap, tour }: { w: Word; trail: string; status: TokenStatus; speaking: boolean; selected: boolean; furigana: boolean; romaji: boolean; onTap?: (() => void) | undefined; tour?: string | undefined }) {
  const underline = status === "new" ? "decoration-info" : status === "learning" ? "decoration-learning" : "decoration-transparent";
  const body = w.f && furigana
    ? w.f.map(([t, r], i) => (r ? <ruby key={i}>{t}<rt className="text-[0.5em] font-bold text-muted-foreground">{r}</rt></ruby> : <span key={i}>{t}</span>))
    : w.s;
  if (!onTap) return <span className="leading-[1.9]">{w.s}{trail}</span>;
  const btn = (
    <button
      data-tour={tour}
      onClick={(e) => { e.stopPropagation(); onTap(); }}
      className={cn(
        "flex flex-col items-center rounded-lg px-0.5 leading-tight transition-colors",
        speaking && "outline outline-2 outline-success",
        selected && "bg-primary/25",
      )}
    >
      <span className={cn("font-bold underline decoration-[3px] underline-offset-[6px]", underline)}>{body}</span>
      {romaji && <span className="mt-1.5 font-sans text-[0.5em] font-bold text-faint">{w.ro || "\u00a0"}</span>}
    </button>
  );
  if (!trail) return btn;
  return (
    <span className="inline-flex items-start">
      {btn}
      <span className={cn("font-bold leading-tight", furigana && w.f ? "pt-[0.5em]" : "")}>{trail}</span>
    </span>
  );
}
