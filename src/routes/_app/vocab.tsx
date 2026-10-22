import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { ChevronRight, Search, Volume2, X } from "lucide-react";
import { useDeferredValue, useMemo, useState } from "react";
import { useShallow } from "zustand/react/shallow";

import { Mascot } from "@/components/mimi/Mascot";
import { SavedWordSheet } from "@/components/mimi/SavedWordSheet";
import { Button, Chip, Screen } from "@/components/mimi/ui";
import { useContent } from "@/lib/feed";
import { dayKey, isDue, kanaDeck, kanaLearned, kanaQueue, normalizeQuery, wordStatus } from "@/lib/logic";
import { speak } from "@/lib/speech";
import { countsOf, useApp, type SavedWord } from "@/lib/store";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/_app/vocab")({
  head: () => ({
    meta: [
      { title: "Your words — Kizuki" },
      { name: "description", content: "Every Japanese word you saved from clips, with smart reviews and kana decks." },
      { property: "og:title", content: "Your words — Kizuki" },
      { property: "og:description", content: "Every Japanese word you saved from clips, with smart reviews and kana decks." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: Vocab,
});

type Filter = "all" | "due" | "learning" | "known";
const HIRA = kanaDeck("hiragana");
const KATA = kanaDeck("katakana");

function Vocab() {
  const navigate = useNavigate();
  const { data } = useContent();
  const wordsMap = useApp((s) => s.words);
  const kana = useApp((s) => s.kana);
  const counts = useApp(useShallow((s) => countsOf(s)));
  const [filter, setFilter] = useState<Filter>("all");
  const [text, setText] = useState("");
  const q = normalizeQuery(useDeferredValue(text));
  const [open, setOpen] = useState<SavedWord | null>(null);
  const [sheet, setSheet] = useState(false);
  const now = Date.now();

  const list = useMemo(() => {
    const all = Object.values(wordsMap).filter((w) => w.status !== "removed").sort((a, b) => b.addedAt - a.addedAt);
    return all.filter((w) => {
      const st = w.status === "ignored" ? "ignored" : wordStatus({ status: w.status, card: w.card });
      if (filter === "due" && !(w.status === "learning" && isDue(w.card, now))) return false;
      if (filter === "learning" && st !== "learning") return false;
      if (filter === "known" && st !== "known") return false;
      if (q && ![w.word, w.reading, w.surface].some((f) => normalizeQuery(f).includes(q)) && !w.romaji.toLowerCase().includes(q) && !w.gloss.toLowerCase().includes(q)) return false;
      return true;
    });
  }, [wordsMap, filter, q, now]);

  const groups = useMemo(() => {
    const today = dayKey(new Date());
    const yest = dayKey(new Date(Date.now() - 86_400_000));
    const out: { label: string; items: SavedWord[] }[] = [];
    for (const w of list) {
      const k = dayKey(new Date(w.addedAt));
      const label = k === today ? "Today" : k === yest ? "Yesterday" : new Date(w.addedAt).toLocaleDateString([], { month: "short", day: "numeric" });
      const g = out[out.length - 1];
      if (g && g.label === label) g.items.push(w);
      else out.push({ label, items: [w] });
    }
    return out;
  }, [list]);

  const hiraDue = kanaQueue(HIRA, kana, now).length;
  const kataDue = kanaQueue(KATA, kana, now).length;

  return (
    <Screen className="pb-0">
      <div className="px-5 pt-2">
        <div className="flex items-start justify-between">
          <div>
            <p className="text-[3.25rem] font-black leading-none tabular">{counts.known}</p>
            <p className="mt-1 text-[1rem] font-extrabold text-muted-foreground">Japanese words you know 🇯🇵</p>
          </div>
          <Mascot pose="read" className="-mt-1 h-20 w-20" />
        </div>
        <div className="mt-4">
          {counts.due > 0 ? (
            <Button data-tour="reviewButton" onClick={() => navigate({ to: "/review", search: { deck: "words" } })}>{counts.due} card{counts.due === 1 ? "" : "s"} to review</Button>
          ) : (
            <div className="rounded-2xl bg-surface px-4 py-3.5 text-center">
              <p className="text-[1rem] font-extrabold">{counts.saved ? "Done reviewing for today 🎉" : "Tap words in clips to save them"}</p>
              <p className="text-[0.8125rem] text-muted-foreground">{counts.saved ? `${counts.learning} learning · ${counts.known} known` : "They'll show up here, ready to review."}</p>
              {counts.learning > 0 && <button onClick={() => navigate({ to: "/review", search: { deck: "words", mode: "extra" } })} className="press mt-2 text-[0.875rem] font-extrabold text-primary">Keep studying</button>}
            </div>
          )}
        </div>

        <p className="mb-2 mt-6 text-[0.8125rem] font-black uppercase tracking-[0.12em] text-muted-foreground">Decks</p>
        <div className="space-y-2">
          <DeckRow icon="🔖" title="Your words" sub={`${counts.saved} saved from clips`} badge={counts.due} onClick={() => counts.due > 0 ? navigate({ to: "/review", search: { deck: "words" } }) : undefined} />
          <DeckRow icon="あ" title="Hiragana" sub={`${kanaLearned(HIRA, kana)} / ${HIRA.length} learned`} badge={hiraDue} onClick={() => navigate({ to: "/review", search: { deck: "hiragana" } })} />
          <DeckRow icon="ア" title="Katakana" sub={`${kanaLearned(KATA, kana)} / ${KATA.length} learned`} badge={kataDue} onClick={() => navigate({ to: "/review", search: { deck: "katakana" } })} />
        </div>

        <label className="mt-6 flex h-12 items-center gap-2 rounded-2xl border-2 border-border bg-surface px-3 focus-within:border-primary">
          <Search className="h-5 w-5 text-faint" />
          <input value={text} onChange={(e) => setText(e.target.value.slice(0, 40))} placeholder="Search your words" aria-label="Search your words" className="h-full min-w-0 flex-1 bg-transparent text-[1rem] font-bold outline-none placeholder:text-faint" />
          {text && <button aria-label="Clear" onClick={() => setText("")}><X className="h-5 w-5 text-faint" /></button>}
        </label>
        <div className="mt-2.5 flex gap-2 overflow-x-auto no-scrollbar">
          {([["all", `All ${counts.saved}`], ["due", `Due ${counts.due}`], ["learning", `Learning ${counts.learning}`], ["known", `Known ${counts.known}`]] as const).map(([f, l]) => (
            <Chip key={f} active={filter === f} onClick={() => setFilter(f)}>{l}</Chip>
          ))}
        </div>
      </div>

      <div className="px-5 pb-28 pt-2">
        {groups.length === 0 && (
          <div className="flex flex-col items-center py-10 text-center">
            <Mascot pose="think" className="h-20 w-20" />
            <p className="mt-2 text-[0.9375rem] font-bold text-muted-foreground">{counts.saved ? "No words match." : "No words yet — watch a clip and tap any word."}</p>
            {!counts.saved && <Button size="md" variant="surface" className="mt-3" onClick={() => navigate({ to: "/feed" })}>Go to the feed</Button>}
          </div>
        )}
        {groups.map((g) => (
          <div key={g.label}>
            <p className="mb-1.5 mt-4 text-[0.875rem] font-extrabold text-muted-foreground">{g.label}</p>
            <div className="divide-y divide-border overflow-hidden rounded-2xl bg-surface">
              {g.items.map((w) => {
                const st = w.status === "ignored" ? "ignored" : wordStatus({ status: w.status, card: w.card });
                return (
                  <div key={w.key} className="flex items-center gap-3 px-3 py-2.5">
                    <button onClick={() => { setOpen(w); setSheet(true); }} className="flex min-w-0 flex-1 items-center gap-3 text-left">
                      <span className={cn("h-3 w-3 shrink-0 rounded-full", st === "known" ? "bg-success" : st === "ignored" ? "bg-surface-3" : "bg-learning")} aria-label={st} />
                      <span className="min-w-0 flex-1">
                        <span className="block truncate font-jp text-[1.0625rem] font-bold">{w.word} {w.reading && w.reading !== w.word && <span className="text-[0.8125rem] text-faint">{w.reading}</span>}</span>
                        <span className="block truncate text-[0.8125rem] text-muted-foreground">{w.gloss}</span>
                      </span>
                    </button>
                    <button aria-label={`Play ${w.word}`} onClick={() => speak(w.reading || w.word)} className="press flex h-9 w-9 items-center justify-center rounded-full text-faint"><Volume2 className="h-4 w-4" /></button>
                  </div>
                );
              })}
            </div>
          </div>
        ))}
      </div>
      <SavedWordSheet word={open} content={data} open={sheet} onClose={() => setSheet(false)} />
    </Screen>
  );
}

function DeckRow({ icon, title, sub, badge, onClick }: { icon: string; title: string; sub: string; badge: number; onClick?: () => void }) {
  return (
    <button onClick={onClick} className="press flex w-full items-center gap-3 rounded-2xl bg-surface px-4 py-3 text-left">
      <span className="flex h-11 w-11 items-center justify-center rounded-xl bg-surface-2 font-jp text-[1.375rem] font-black">{icon}</span>
      <span className="min-w-0 flex-1">
        <span className="block text-[1rem] font-extrabold">{title}</span>
        <span className="block text-[0.8125rem] text-muted-foreground">{sub}</span>
      </span>
      {badge > 0 && <span className="rounded-full bg-primary px-2 py-0.5 text-[0.75rem] font-black text-primary-foreground tabular">{badge}</span>}
      <ChevronRight className="h-5 w-5 text-faint" />
    </button>
  );
}
