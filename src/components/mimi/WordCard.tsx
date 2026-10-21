import { Link } from "@tanstack/react-router";
import { Check, EyeOff, MessageCircleQuestion, Plus, Trash2, Volume2 } from "lucide-react";
import { useMemo, useState } from "react";

import type { AskContext } from "@/lib/ask";
import type { Clip, ClipNotes, Content, DictEntry, Word } from "@/lib/content";
import { glossOf, thumbOf } from "@/lib/content";
import { clipsWithWord, formatInterval, wordKeyOf, wordStatus } from "@/lib/logic";
import { speak } from "@/lib/speech";
import { useApp, type WordInput } from "@/lib/store";
import { cn } from "@/lib/utils";

import { AskSheet } from "./AskSheet";
import { Mascot } from "./Mascot";
import { Button, Sheet } from "./ui";

const TABS = ["Meaning", "Explain", "Examples", "Notes"] as const;
type Tab = (typeof TABS)[number];

export const POS_NAMES: Record<string, string> = {
  noun: "noun", verb: "verb", adj: "adjective", "i-adj": "い-adjective", "na-adj": "な-adjective", adverb: "adverb", particle: "particle",
  auxiliary: "auxiliary", pronoun: "pronoun", interjection: "interjection", conjunction: "conjunction", prefix: "prefix", suffix: "suffix", other: "word",
};

/** Build the saved-word payload for a transcript token. */
export function wordInput(clip: Clip, li: number, wi: number, content: Content, notes: ClipNotes | null): WordInput {
  const w = clip.lines[li]!.words[wi]!;
  const e = w.d ? content.dict[w.d] : undefined;
  return {
    dictId: w.d, base: w.b || w.s, word: e?.w ?? (w.b || w.s), reading: e?.r ?? w.r, romaji: w.ro,
    gloss: notes?.w[`${li}.${wi}`]?.m || glossOf(e) || "", pos: w.p, jlpt: e?.j ?? null, surface: w.s, clipId: clip.id, line: li, idx: wi,
  };
}

type Props = {
  open: boolean;
  onClose: () => void;
  clip: Clip;
  line: number;
  idx: number;
  content: Content;
  notes: ClipNotes | null;
};

export function WordCard({ open, onClose, clip, line, idx, content, notes }: Props) {
  const [tab, setTab] = useState<Tab>("Meaning");
  const w: Word | undefined = clip.lines[line]?.words[idx];
  const entry: DictEntry | undefined = w?.d ? content.dict[w.d] : undefined;
  const key = w ? wordKeyOf(w.d, w.b || w.s) : "";
  const saved = useApp((s) => (key ? s.words[key] : undefined));
  const jlpt = useApp((s) => s.profile.jlpt);
  const { saveWord, setWordStatus, removeWord, setWordNote } = useApp.getState();
  const note = w ? notes?.w[`${line}.${idx}`] : undefined;
  const lineNote = notes?.l[String(line)];
  const others = useMemo(() => (open && key ? clipsWithWord(content.clips, key, clip.id, jlpt) : []), [open, key, content.clips, clip.id, jlpt]);
  const [asking, setAsking] = useState(false);
  // What the tutor needs to know about this word and its line — mirrors _askContext() in word_card.dart.
  const askCtx = useMemo((): AskContext | null => {
    const l = clip.lines[line];
    if (!l || !l.words[idx]) return null;
    const i = wordInput(clip, line, idx, content, notes);
    return { clipId: clip.id, title: clip.title, level: clip.level, learnerLevel: jlpt, line: { ja: l.ja, en: l.en }, word: { surface: i.surface, head: i.word, reading: i.reading, gloss: i.gloss } };
  }, [clip, line, idx, content, notes, jlpt]);

  if (!w) return null;
  const head = entry?.w ?? (w.b || w.s);
  const reading = entry?.r ?? w.r;
  const live = saved && saved.status !== "removed" ? saved : undefined;
  const status = live ? (live.status === "ignored" ? "ignored" : wordStatus({ status: live.status, card: live.card })) : "new";
  const input = () => wordInput(clip, line, idx, content, notes);

  return (
    <>
    <Sheet open={open} onClose={onClose} maxHeight="78%">
      <div className="flex min-h-0 flex-1 flex-col">
        <div className="flex items-start gap-3 px-5 pt-3">
          <div className="min-w-0 flex-1">
            {reading && reading !== head && <p className="font-jp text-[0.9375rem] font-bold text-muted-foreground">{reading}</p>}
            <p className="font-jp text-[2.25rem] font-black leading-tight">{head}</p>
            <div className="mt-1 flex flex-wrap items-center gap-1.5">
              <span className="text-[0.9375rem] font-bold text-muted-foreground">{w.ro}</span>
              {entry?.m[0]?.pos[0] && <span className="rounded-md bg-surface-2 px-2 py-0.5 text-[0.75rem] font-extrabold">{entry.m[0].pos[0]}</span>}
              {!entry?.m[0]?.pos[0] && w.p !== "other" && <span className="rounded-md bg-surface-2 px-2 py-0.5 text-[0.75rem] font-extrabold">{POS_NAMES[w.p] ?? w.p}</span>}
              {entry?.j && <span className="rounded-md bg-success-soft px-2 py-0.5 text-[0.75rem] font-extrabold text-success">N{entry.j}</span>}
              {entry?.c && <span className="rounded-md bg-surface-2 px-2 py-0.5 text-[0.75rem] font-extrabold text-muted-foreground">common</span>}
              {w.s !== head && <span className="text-[0.8125rem] font-bold text-faint">heard as <span className="font-jp text-muted-foreground">{w.s}</span></span>}
            </div>
          </div>
          <button aria-label="Play pronunciation" onClick={() => speak(reading || head)} className="press mt-2 flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-surface-2">
            <Volume2 className="h-5 w-5" />
          </button>
        </div>

        <div className="mt-3 flex gap-2 px-5">
          {!live || live.status === "ignored" ? (
            <>
              <button onClick={() => saveWord(input())} className="btn-3d flex h-11 flex-1 items-center justify-center gap-1.5 rounded-xl bg-primary text-[0.9375rem] font-extrabold text-primary-foreground"><Plus className="h-4 w-4" strokeWidth={3} /> Save word</button>
              <button onClick={() => { if (live) setWordStatus(key, "known"); else { useApp.getState().markKnown([input()]); } }} className="press flex h-11 items-center gap-1.5 rounded-xl bg-surface-2 px-3 text-[0.875rem] font-extrabold"><Check className="h-4 w-4 text-success" strokeWidth={3} /> I know it</button>
            </>
          ) : (
            <>
              <div className={cn("flex h-11 flex-1 items-center gap-2 rounded-xl px-3 text-[0.875rem] font-extrabold", status === "known" ? "bg-success-soft text-success" : "bg-primary/15 text-primary")}>
                {status === "known" ? <><Check className="h-4 w-4" strokeWidth={3} /> Known</> : <>Learning · review {live.card.due <= Date.now() ? "now" : `in ${formatInterval(live.card.due - Date.now())}`}</>}
              </div>
              {status !== "known" && <button aria-label="I know this word" onClick={() => setWordStatus(key, "known")} className="press flex h-11 items-center gap-1 rounded-xl bg-surface-2 px-3 text-[0.8125rem] font-extrabold"><Check className="h-4 w-4 text-success" strokeWidth={3} /> Known</button>}
              <button aria-label="Ignore word" onClick={() => setWordStatus(key, "ignored")} className="press flex h-11 w-11 items-center justify-center rounded-xl bg-surface-2"><EyeOff className="h-4 w-4 text-muted-foreground" /></button>
              <button aria-label="Remove word" onClick={() => removeWord(key)} className="press flex h-11 w-11 items-center justify-center rounded-xl bg-surface-2"><Trash2 className="h-4 w-4 text-danger" /></button>
            </>
          )}
        </div>

        <div role="tablist" className="mt-4 flex gap-1 border-b border-border px-4">
          {TABS.map((t) => (
            <button key={t} role="tab" aria-selected={tab === t} onClick={() => setTab(t)} className={cn("relative flex-1 pb-2.5 pt-1 text-[0.875rem] font-extrabold", tab === t ? "text-foreground" : "text-faint")}>
              {t}
              {tab === t && <span className="absolute inset-x-3 bottom-0 h-[3px] rounded-full bg-primary" />}
            </button>
          ))}
        </div>

        <div className="min-h-[180px] flex-1 overflow-y-auto px-5 pb-4 pt-4 no-scrollbar">
          {tab === "Meaning" && (
            <div className="space-y-3">
              {note?.m && (
                <div className="rounded-2xl bg-primary/10 px-4 py-3">
                  <p className="text-[0.6875rem] font-black uppercase tracking-[0.12em] text-primary">In this clip</p>
                  <p className="mt-0.5 text-[1.125rem] font-extrabold">{note.m}</p>
                </div>
              )}
              {entry ? (
                <ol className="space-y-2.5">
                  {entry.m.map((m, i) => (
                    <li key={i} className="flex gap-3">
                      <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-surface-2 text-[0.75rem] font-black">{i + 1}</span>
                      <span className="text-[0.9375rem] leading-snug">
                        {m.pos[0] && <span className="mr-1.5 rounded bg-surface-2 px-1.5 py-0.5 text-[0.6875rem] font-extrabold text-muted-foreground">{m.pos[0]}</span>}
                        {m.g}
                      </span>
                    </li>
                  ))}
                </ol>
              ) : (
                !note?.m && <p className="text-[0.9375rem] text-muted-foreground">No dictionary entry for this word — check the Explain tab.</p>
              )}
            </div>
          )}

          {tab === "Explain" && (
            <div className="space-y-3">
              <div className="flex gap-3">
                <Mascot pose="think" className="h-12 w-12 shrink-0" />
                <div className="rounded-2xl rounded-tl-sm bg-surface-2 px-4 py-3 text-[0.9375rem] leading-relaxed">
                  {note ? (
                    <>
                      <p><b className="font-jp">{w.s}</b> here means <b>“{note.m}”</b>.</p>
                      <p className="mt-1.5">{note.n}</p>
                    </>
                  ) : notes ? (
                    <p>This word is a small helper in the sentence — the full line meaning is below.</p>
                  ) : (
                    <p className="text-muted-foreground">Loading explanation…</p>
                  )}
                </div>
              </div>
              {lineNote && (
                <div className="rounded-2xl bg-surface-2/60 px-4 py-3">
                  <p className="text-[0.6875rem] font-black uppercase tracking-[0.12em] text-muted-foreground">The whole line</p>
                  <p className="mt-1 font-jp text-[1rem] font-bold">{clip.lines[line]?.ja}</p>
                  <p className="mt-1 text-[0.875rem] text-muted-foreground">Literally: {lineNote.lit}</p>
                  {lineNote.tip && <p className="mt-1.5 text-[0.875rem]">💡 {lineNote.tip}</p>}
                </div>
              )}
              <Button variant="surface" size="md" className="!mt-3.5 w-full" onClick={() => setAsking(true)}>
                <MessageCircleQuestion className="h-[18px] w-[18px] text-primary" /> Still curious? Ask Kizuki
              </Button>
            </div>
          )}

          {tab === "Examples" && (
            <div className="space-y-4">
              {others.length > 0 && (
                <div>
                  <p className="mb-2 text-[0.6875rem] font-black uppercase tracking-[0.12em] text-muted-foreground">Hear it in other clips</p>
                  <div className="flex gap-2 overflow-x-auto pb-1 no-scrollbar">
                    {others.map((id) => {
                      const c = content.byId[id];
                      if (!c) return null;
                      return (
                        <Link key={id} to="/clip/$clipId" params={{ clipId: id }} onClick={onClose} className="press w-[132px] shrink-0 overflow-hidden rounded-xl bg-surface-2">
                          <img src={thumbOf(c.videoId)} alt="" loading="lazy" className="aspect-video w-full object-cover" />
                          <p className="line-clamp-2 px-2 py-1.5 text-[0.6875rem] font-bold leading-tight">{c.title}</p>
                        </Link>
                      );
                    })}
                  </div>
                </div>
              )}
              {entry?.ex.length ? (
                <div className="space-y-2.5">
                  <p className="text-[0.6875rem] font-black uppercase tracking-[0.12em] text-muted-foreground">Example sentences</p>
                  {entry.ex.map((e, i) => (
                    <button key={i} onClick={() => speak(e.ja)} className="press flex w-full items-start gap-3 rounded-2xl bg-surface-2 px-4 py-3 text-left">
                      <span className="min-w-0 flex-1">
                        <span className="block font-jp text-[1rem] font-bold">{e.ja}</span>
                        <span className="mt-0.5 block text-[0.8125rem] text-muted-foreground">{e.en}</span>
                      </span>
                      <Volume2 className="mt-1 h-4 w-4 shrink-0 text-faint" />
                    </button>
                  ))}
                  <p className="text-[0.6875rem] text-faint">Examples: Tatoeba (CC BY 2.0 FR) via JMdict.</p>
                </div>
              ) : (
                others.length === 0 && <p className="text-[0.9375rem] text-muted-foreground">No other examples yet for this word.</p>
              )}
            </div>
          )}

          {tab === "Notes" && (
            live ? (
              <textarea
                defaultValue={live.note}
                onBlur={(e) => setWordNote(key, e.target.value.slice(0, 500))}
                placeholder="Add a note — a memory trick, where you heard it…"
                className="h-32 w-full resize-none rounded-2xl border-2 border-border bg-surface-2 p-3 text-[0.9375rem] outline-none placeholder:text-faint focus:border-primary"
              />
            ) : (
              <p className="text-[0.9375rem] text-muted-foreground">Save this word to add your own notes.</p>
            )
          )}
        </div>
      </div>
    </Sheet>
    {askCtx && <AskSheet open={open && asking} onClose={() => setAsking(false)} context={askCtx} />}
    </>
  );
}
