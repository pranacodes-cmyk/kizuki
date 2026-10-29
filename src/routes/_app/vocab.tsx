import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { ChevronRight, Search, Volume2, X } from "lucide-react";
import { useDeferredValue, useMemo, useState } from "react";
import { useShallow } from "zustand/react/shallow";

import { Mascot } from "@/components/mimi/Mascot";
import { SavedWordSheet } from "@/components/mimi/SavedWordSheet";
import { LevelBadge } from "@/components/mimi/WordLevel";
import { Button, Chip, Screen } from "@/components/mimi/ui";
import { useContent } from "@/lib/feed";
import { dayKey, isDue, kanaDeck, kanaLearned, kanaQueue, normalizeQuery, wordLevel, wordStatus } from "@/lib/logic";
import { speak } from "@/lib/speech";
import { countsOf, glossIn, useApp, type SavedWord } from "@/lib/store";
import { getLang, tr, trn } from "@/lib/i18n";

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
      if (q && ![w.word, w.reading, w.surface].some((f) => normalizeQuery(f).includes(q)) && !w.romaji.toLowerCase().includes(q) && !w.gloss.toLowerCase().includes(q) && !glossIn(w, data).toLowerCase().includes(q)) return false;
      return true;
    });
  }, [wordsMap, filter, q, now, data]);

  const groups = useMemo(() => {
    const today = dayKey(new Date());
    const yest = dayKey(new Date(Date.now() - 86_400_000));
    const out: { label: string; items: SavedWord[] }[] = [];
    for (const w of list) {
      const k = dayKey(new Date(w.addedAt));
      const label = k === today ? tr("Today") : k === yest ? tr("Yesterday") : new Date(w.addedAt).toLocaleDateString(getLang(), { month: "short", day: "numeric" });
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
            <p className="mt-1 text-[1rem] font-extrabold text-muted-foreground">{tr("Words you know")}</p>
          </div>
          <Mascot pose="read" className="-mt-1 h-20 w-20" />
        </div>
        <div className="mt-4">
          {counts.due > 0 ? (
            <Button data-tour="reviewButton" onClick={() => navigate({ to: "/review", search: { deck: "words" } })}>{trn(counts.due, "{n} card to review", "{n} cards to review")}</Button>
          ) : (
            <div className="rounded-2xl bg-surface px-4 py-3.5 text-center">
              <p className="text-[1rem] font-extrabold">{counts.saved ? tr("Done reviewing for today 🎉") : tr("Tap words in clips to save them")}</p>
              <p className="text-[0.8125rem] text-muted-foreground">{counts.saved ? tr("{learning} learning · {known} known", { learning: counts.learning, known: counts.known }) : tr("They'll show up here, ready to review.")}</p>
              {counts.learning > 0 && <button onClick={() => navigate({ to: "/review", search: { deck: "words", mode: "extra" } })} className="press mt-2 text-[0.875rem] font-extrabold text-primary">{tr("Keep studying")}</button>}
            </div>
          )}
        </div>

        <p className="mb-2 mt-6 text-[0.8125rem] font-black uppercase tracking-[0.12em] text-muted-foreground">{tr("Decks")}</p>
        <div className="space-y-2">
          <DeckRow icon="🔖" title={tr("Your words")} sub={tr("{saved} saved from clips", { saved: counts.saved })} badge={counts.due} onClick={() => counts.due > 0 ? navigate({ to: "/review", search: { deck: "words" } }) : undefined} />
          {/* The welcome tour's "kanaDecks" step spotlights both alphabet decks together. */}
          <div data-tour="kanaDecks" className="space-y-2">
            <DeckRow icon="あ" title={tr("Hiragana")} sub={tr("{known} / {total} known", { known: kanaLearned(HIRA, kana), total: HIRA.length })} badge={hiraDue} onClick={() => navigate({ to: "/review", search: { deck: "hiragana" } })} />
            <DeckRow icon="ア" title={tr("Katakana")} sub={tr("{known} / {total} known", { known: kanaLearned(KATA, kana), total: KATA.length })} badge={kataDue} onClick={() => navigate({ to: "/review", search: { deck: "katakana" } })} />
          </div>
        </div>

        <label className="mt-6 flex h-12 items-center gap-2 rounded-2xl border-2 border-border bg-surface px-3 focus-within:border-primary">
          <Search className="h-5 w-5 text-faint" />
          <input value={text} onChange={(e) => setText(e.target.value.slice(0, 40))} placeholder={tr("Search your words")} aria-label={tr("Search your words")} className="h-full min-w-0 flex-1 bg-transparent text-[1rem] font-bold outline-none placeholder:text-faint" />
          {text && <button aria-label={tr("Clear")} onClick={() => setText("")}><X className="h-5 w-5 text-faint" /></button>}
        </label>
        <div className="mt-2.5 flex gap-2 overflow-x-auto no-scrollbar">
          {([["all", tr("All {saved}", { saved: counts.saved })], ["due", tr("To Review {due}", { due: counts.due })], ["known", tr("Known {known}", { known: counts.known })]] as const).map(([f, l]) => (
            <Chip key={f} active={filter === f} onClick={() => setFilter(f)}>{l}</Chip>
          ))}
        </div>
      </div>

      <div className="px-5 pb-28 pt-2">
        {groups.length === 0 && (
          <div className="flex flex-col items-center py-10 text-center">
            <Mascot pose="think" className="h-20 w-20" />
            <p className="mt-2 text-[0.9375rem] font-bold text-muted-foreground">{counts.saved ? tr("No words match.") : tr("No words yet — watch a clip and tap any word.")}</p>
            {!counts.saved && <Button size="md" variant="surface" className="mt-3" onClick={() => navigate({ to: "/feed" })}>{tr("Go to the feed")}</Button>}
          </div>
        )}
        {groups.map((g) => (
          <div key={g.label}>
            <p className="mb-1.5 mt-4 text-[0.875rem] font-extrabold text-muted-foreground">{g.label}</p>
            <div className="divide-y divide-border overflow-hidden rounded-2xl bg-surface">
              {g.items.map((w) => {
                return (
                  <div key={w.key} className="flex items-center gap-3 px-3 py-2.5">
                    <button onClick={() => { setOpen(w); setSheet(true); }} className="flex min-w-0 flex-1 items-center gap-3 text-left">
                      <LevelBadge level={wordLevel(w)} size={24} />
                      <span className="min-w-0 flex-1">
                        <span className="block truncate font-jp text-[1.0625rem] font-bold">{w.word} {w.reading && w.reading !== w.word && <span className="text-[0.8125rem] text-faint">{w.reading}</span>}</span>
                        <span className="block truncate text-[0.8125rem] text-muted-foreground">{glossIn(w, data)}</span>
                      </span>
                    </button>
                    <button aria-label={tr("Play {word}", { word: w.word })} onClick={() => speak(w.reading || w.word)} className="press flex h-9 w-9 items-center justify-center rounded-full text-faint"><Volume2 className="h-4 w-4" /></button>
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
