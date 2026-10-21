import { Bookmark, CheckCheck, Pause, Play, Repeat1, RotateCcw, Type } from "lucide-react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import type { Clip, ClipNotes, Content, Word } from "@/lib/content";
import { loadNotes } from "@/lib/content";
import { wordKeyOf } from "@/lib/logic";
import { tokenStatus, useApp, type WordInput } from "@/lib/store";
import { toast } from "@/lib/ui-store";
import { cn } from "@/lib/utils";
import { watchUrl } from "@/lib/youtube";

import { ClipPlayer, type ClipPlayerHandle } from "./ClipPlayer";
import { DisplaySheet, LineMenu, SPEEDS } from "./ClipSheets";
import { Transcript, activeLineIndex, type TokenStatus } from "./Transcript";
import { WordCard, wordInput } from "./WordCard";

const fmt = (s: number) => `${Math.floor(Math.max(0, s) / 60)}:${String(Math.floor(Math.max(0, s) % 60)).padStart(2, "0")}`;

/** One clip: official YouTube player + controls + interactive transcript + word card. */
export function ClipView({ clip, content, active, bottomInset = 96, tourTargets = false }: { clip: Clip; content: Content; active: boolean; bottomInset?: number; /** Only the feed's active clip carries the welcome-tour spotlight targets. */ tourTargets?: boolean }) {
  const player = useRef<ClipPlayerHandle>(null);
  const scroller = useRef<HTMLDivElement>(null);
  const [time, setTime] = useState(clip.start);
  const [playing, setPlaying] = useState(false);
  const [rate, setRate] = useState(1);
  const [loopLine, setLoopLine] = useState<number | null>(null);
  const [notes, setNotes] = useState<ClipNotes | null>(null);
  const [sel, setSel] = useState<{ line: number; idx: number } | null>(null);
  const [cardOpen, setCardOpen] = useState(false);
  const [menuLine, setMenuLine] = useState<number | null>(null);
  const [menuOpen, setMenuOpen] = useState(false);
  const [display, setDisplay] = useState(false);

  const settings = useApp((s) => s.settings);
  const words = useApp((s) => s.words);
  const savedClip = useApp((s) => s.savedClips.includes(clip.id));
  const video = content.videos[clip.videoId];

  useEffect(() => {
    if (!active) return;
    let live = true;
    void loadNotes(clip.id).then((n) => live && setNotes(n));
    return () => { live = false; };
  }, [active, clip.id]);

  // Reset per activation.
  useEffect(() => {
    if (!active) { setCardOpen(false); setMenuOpen(false); setLoopLine(null); setTime(clip.start); }
  }, [active, clip.start]);

  // Watch time → daily goal + "watched" once 80% heard or on first loop.
  const marked = useRef(false);
  const played = useRef(0);
  const pending = useRef(0);
  const markWatched = useCallback(() => {
    if (marked.current) return;
    marked.current = true;
    useApp.getState().markClipWatched(clip.id);
  }, [clip.id]);
  useEffect(() => {
    if (!active) { marked.current = false; played.current = 0; return; }
  }, [active]);
  useEffect(() => {
    if (!playing) return;
    const dur = clip.end - clip.start;
    const id = setInterval(() => {
      played.current += 1;
      pending.current += 1;
      if (played.current >= dur * 0.8) markWatched();
      if (pending.current >= 10) { useApp.getState().addWatchSeconds(pending.current); pending.current = 0; }
    }, 1000);
    return () => {
      clearInterval(id);
      if (pending.current) { useApp.getState().addWatchSeconds(pending.current); pending.current = 0; }
    };
  }, [playing, clip.start, clip.end, markWatched]);

  // Keep the spoken line in view (scroll only this transcript, never the feed).
  const current = activeLineIndex(clip, time);
  useEffect(() => {
    const box = scroller.current;
    if (!box || current < 0) return;
    const el = box.querySelector<HTMLElement>(`[data-line="${current}"]`);
    if (!el) return;
    const top = el.offsetTop - box.clientHeight * 0.25;
    if (Math.abs(box.scrollTop - top) > 24) box.scrollTo({ top: Math.max(0, top), behavior: "smooth" });
  }, [current]);

  const statusOf = useCallback((w: Word): TokenStatus => tokenStatus({ words } as never, wordKeyOf(w.d, w.b || w.s)), [words]);

  const onWord = useCallback((li: number, wi: number) => {
    setSel({ line: li, idx: wi });
    setCardOpen(true);
    player.current?.pause();
    const s = useApp.getState();
    if (s.settings.autoSave) {
      const w = clip.lines[li]?.words[wi];
      if (!w) return;
      const k = wordKeyOf(w.d, w.b || w.s);
      if (!s.words[k] || s.words[k].status === "removed") s.saveWord(wordInput(clip, li, wi, content, notes));
    }
  }, [clip, content, notes]);

  const seekLine = useCallback((li: number) => {
    const l = clip.lines[li];
    if (!l) return;
    player.current?.seek(Math.max(clip.start, l.start - 0.1));
  }, [clip]);

  const unknown = useMemo(() => {
    const out: WordInput[] = [];
    const seen = new Set<string>();
    clip.lines.forEach((l, li) => l.words.forEach((w, wi) => {
      if (w.p === "punct") return;
      const k = wordKeyOf(w.d, w.b || w.s);
      if (seen.has(k) || statusOf(w) !== "new") return;
      seen.add(k);
      out.push(wordInput(clip, li, wi, content, notes));
    }));
    return out;
  }, [clip, content, notes, statusOf]);

  const dur = clip.end - clip.start;
  const rel = Math.min(dur, Math.max(0, time - clip.start));
  const ll = loopLine != null ? clip.lines[loopLine] : undefined;
  const loopRange = ll ? { start: ll.start - 0.1, end: ll.end + 0.15 } : null;

  const tour = (id: string) => (active && tourTargets ? id : undefined);

  return (
    <div className="flex h-full flex-col">
      <div data-tour={tour("player")}>
      <ClipPlayer
        ref={player}
        clip={clip}
        active={active}
        rate={rate}
        onTime={setTime}
        onPlayingChange={setPlaying}
        onLoop={markWatched}
        loopRange={loopRange}
      />
      </div>
      <div className="h-[3px] w-full bg-surface-2"><div className="h-full bg-primary transition-[width] duration-100" style={{ width: `${(rel / dur) * 100}%` }} /></div>

      <div data-tour={tour("controls")} className="flex items-center gap-1 px-2 pt-1.5">
        <button aria-label={playing ? "Pause" : "Play"} onClick={() => player.current?.toggle()} className="press flex h-10 w-10 items-center justify-center rounded-full">
          {playing ? <Pause className="h-5 w-5 fill-current" /> : <Play className="h-5 w-5 fill-current" />}
        </button>
        <span className="min-w-[78px] text-[0.8125rem] font-bold text-muted-foreground tabular">{fmt(rel)} / {fmt(dur)}</span>
        <div className="flex-1" />
        <button aria-label="Replay line" onClick={() => seekLine(Math.max(0, current))} className="press flex h-10 w-10 items-center justify-center rounded-full text-muted-foreground"><RotateCcw className="h-[18px] w-[18px]" /></button>
        <button aria-label="Loop line" onClick={() => setLoopLine(loopLine != null ? null : Math.max(0, current))} className={cn("press flex h-10 w-10 items-center justify-center rounded-full", loopLine != null ? "text-primary" : "text-muted-foreground")}><Repeat1 className="h-[18px] w-[18px]" /></button>
        <button aria-label="Playback speed" onClick={() => setRate(SPEEDS[(SPEEDS.indexOf(rate as 1) + 1) % SPEEDS.length] ?? 1)} className={cn("press h-8 min-w-11 rounded-full px-2 text-[0.8125rem] font-black tabular", rate !== 1 ? "bg-primary/15 text-primary" : "text-muted-foreground")}>{rate}×</button>
        <button aria-label={savedClip ? "Unsave clip" : "Save clip"} onClick={() => { useApp.getState().toggleSavedClip(clip.id); if (!savedClip) toast({ icon: "🔖", title: "Clip saved", description: "Find it in Profile → Saved" }); }} className={cn("press flex h-10 w-10 items-center justify-center rounded-full", savedClip ? "text-primary" : "text-muted-foreground")}><Bookmark className={cn("h-[18px] w-[18px]", savedClip && "fill-current")} /></button>
        <button aria-label="Display options" onClick={() => setDisplay(true)} className="press flex h-10 w-10 items-center justify-center rounded-full text-muted-foreground"><Type className="h-[18px] w-[18px]" /></button>
      </div>

      <div ref={scroller} className="relative min-h-0 flex-1 overflow-y-auto no-scrollbar" style={{ paddingBottom: bottomInset }}>
        <div className="flex items-center gap-2 px-4 pb-1 pt-1">
          <p className="min-w-0 flex-1 truncate text-[0.875rem] font-extrabold">{clip.title}</p>
          <span className="shrink-0 rounded-md bg-surface-2 px-1.5 py-0.5 text-[0.6875rem] font-black text-muted-foreground">{clip.level}</span>
        </div>
        {video && (
          <a href={watchUrl(clip.videoId, clip.start)} target="_blank" rel="noreferrer" className="block truncate px-4 text-[0.75rem] font-bold text-faint hover:text-muted-foreground">
            {video.channel} · Watch on YouTube
          </a>
        )}
        <div data-tour={tour("transcript")}>
        <Transcript clip={clip} time={time} settings={settings} statusOf={statusOf} selected={cardOpen ? sel : null} onWord={onWord} onLine={seekLine} onLineMenu={(li) => { setMenuLine(li); setMenuOpen(true); }} />
        </div>
        {unknown.length > 0 && (
          <div className="px-4 pb-4">
            <button
              onClick={() => { useApp.getState().markKnown(unknown); toast({ icon: "✅", title: `${unknown.length} word${unknown.length > 1 ? "s" : ""} marked as known` }); }}
              className="press flex w-full items-center justify-center gap-2 rounded-2xl border-2 border-border py-3 text-[0.9375rem] font-extrabold text-muted-foreground"
            >
              <CheckCheck className="h-5 w-5 text-success" /> Mark remaining {unknown.length} word{unknown.length > 1 ? "s" : ""} as known
            </button>
          </div>
        )}
      </div>

      {sel && <WordCard key={`${sel.line}.${sel.idx}`} open={cardOpen} onClose={() => setCardOpen(false)} clip={clip} line={sel.line} idx={sel.idx} content={content} notes={notes} />}
      {menuLine != null && (
        <LineMenu open={menuOpen} onClose={() => setMenuOpen(false)} clip={clip} line={menuLine} notes={notes} onReplay={() => seekLine(menuLine)} onLoop={() => setLoopLine(loopLine === menuLine ? null : menuLine)} looping={loopLine === menuLine} />
      )}
      <DisplaySheet open={display} onClose={() => setDisplay(false)} rate={rate} onRate={setRate} />
    </div>
  );
}
