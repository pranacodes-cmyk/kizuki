import { Copy, Repeat1, RotateCcw, Sparkles } from "lucide-react";

import type { Clip, ClipNotes } from "@/lib/content";
import { useApp } from "@/lib/store";
import { toast } from "@/lib/ui-store";
import { cn } from "@/lib/utils";

import { Sheet, Toggle } from "./ui";

export const SPEEDS = [1, 0.75, 0.5] as const;

export function LineMenu({ open, onClose, clip, line, notes, onReplay, onLoop, looping }: {
  open: boolean; onClose: () => void; clip: Clip; line: number; notes: ClipNotes | null;
  onReplay: () => void; onLoop: () => void; looping: boolean;
}) {
  const l = clip.lines[line];
  const n = notes?.l[String(line)];
  if (!l) return null;
  const copy = async () => {
    try { await navigator.clipboard.writeText(l.ja); toast({ icon: "📋", title: "Copied" }); } catch { toast({ tone: "error", title: "Couldn't copy" }); }
    onClose();
  };
  return (
    <Sheet open={open} onClose={onClose} maxHeight="70%">
      <div className="overflow-y-auto px-5 pb-3 pt-3 no-scrollbar">
        <p className="font-jp text-[1.25rem] font-bold leading-snug">{l.ja}</p>
        <p className="mt-1 text-[0.9375rem] text-muted-foreground">{l.en}</p>
        {n && (
          <div className="mt-4 rounded-2xl bg-primary/10 px-4 py-3">
            <p className="flex items-center gap-1.5 text-[0.6875rem] font-black uppercase tracking-[0.12em] text-primary"><Sparkles className="h-3.5 w-3.5" /> Explained</p>
            <p className="mt-1 text-[0.9375rem]"><span className="text-muted-foreground">Literally:</span> {n.lit}</p>
            {n.tip && <p className="mt-1.5 text-[0.9375rem]">💡 {n.tip}</p>}
          </div>
        )}
        <div className="mt-4 space-y-1">
          <MenuRow icon={<RotateCcw className="h-5 w-5" />} label="Replay this line" onClick={() => { onReplay(); onClose(); }} />
          <MenuRow icon={<Repeat1 className={cn("h-5 w-5", looping && "text-primary")} />} label={looping ? "Stop looping this line" : "Loop this line"} onClick={() => { onLoop(); onClose(); }} />
          <MenuRow icon={<Copy className="h-5 w-5" />} label="Copy Japanese" onClick={copy} />
        </div>
      </div>
    </Sheet>
  );
}

function MenuRow({ icon, label, onClick }: { icon: React.ReactNode; label: string; onClick: () => void }) {
  return (
    <button onClick={onClick} className="press flex w-full items-center gap-4 rounded-xl px-2 py-3 text-left text-[1rem] font-bold hover:bg-surface-2">
      <span className="text-muted-foreground">{icon}</span>{label}
    </button>
  );
}

/** Quick "Aa" sheet: the display options learners change most, right on the player. */
export function DisplaySheet({ open, onClose, rate, onRate }: { open: boolean; onClose: () => void; rate: number; onRate: (r: number) => void }) {
  const settings = useApp((s) => s.settings);
  const setSettings = useApp((s) => s.setSettings);
  const rows: { k: "furigana" | "romaji" | "translation" | "highlight" | "spacing"; label: string }[] = [
    { k: "furigana", label: "Furigana (readings above kanji)" },
    { k: "romaji", label: "Romaji" },
    { k: "translation", label: "English translation" },
    { k: "highlight", label: "Highlight the spoken word" },
    { k: "spacing", label: "Space between words" },
  ];
  return (
    <Sheet open={open} onClose={onClose} maxHeight="80%">
      <div className="overflow-y-auto px-5 pb-3 pt-3 no-scrollbar">
        <p className="text-[1.125rem] font-black">Display</p>
        <div className="mt-3 divide-y divide-border rounded-2xl bg-surface-2">
          {rows.map((r) => (
            <div key={r.k} className="flex items-center justify-between gap-3 px-4 py-3">
              <span className="text-[0.9375rem] font-bold">{r.label}</span>
              <Toggle label={r.label} checked={settings[r.k]} onChange={(v) => setSettings({ [r.k]: v })} />
            </div>
          ))}
        </div>
        <p className="mt-5 text-[0.8125rem] font-black uppercase tracking-[0.12em] text-muted-foreground">Text size</p>
        <div className="mt-2 grid grid-cols-3 gap-2">
          {[{ v: 0.85, l: "Small" }, { v: 1, l: "Medium" }, { v: 1.2, l: "Large" }].map((o) => (
            <button key={o.v} onClick={() => setSettings({ textSize: o.v })} className={cn("press h-11 rounded-xl border-2 text-[0.875rem] font-extrabold", settings.textSize === o.v ? "border-primary bg-primary/15 text-primary" : "border-border bg-surface-2")}>{o.l}</button>
          ))}
        </div>
        <p className="mt-5 text-[0.8125rem] font-black uppercase tracking-[0.12em] text-muted-foreground">Speed</p>
        <div className="mt-2 grid grid-cols-3 gap-2">
          {SPEEDS.map((s) => (
            <button key={s} onClick={() => onRate(s)} className={cn("press h-11 rounded-xl border-2 text-[0.875rem] font-extrabold", rate === s ? "border-primary bg-primary/15 text-primary" : "border-border bg-surface-2")}>{s}×</button>
          ))}
        </div>
      </div>
    </Sheet>
  );
}
