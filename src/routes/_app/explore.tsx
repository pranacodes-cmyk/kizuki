import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { Search, X } from "lucide-react";
import { useDeferredValue, useMemo, useState } from "react";
import { z } from "zod";

import { ClipCard } from "@/components/mimi/ClipCard";
import { FeedHeader } from "@/components/mimi/FeedHeader";
import { Mascot } from "@/components/mimi/Mascot";
import { Chip, ErrorState, MascotLoader } from "@/components/mimi/ui";
import { grammarIndex } from "@/lib/content";
import { useContent } from "@/lib/feed";
import { jlptLevels, searchClips } from "@/lib/logic";
import { topicEmoji, topicLabel } from "@/lib/topics";
import { cn } from "@/lib/utils";
import { tr, trn } from "@/lib/i18n";

const searchSchema = z.object({
  q: z.string().max(60).optional(),
  level: z.enum(jlptLevels).optional(),
  topic: z.string().max(30).optional(),
  grammar: z.string().max(60).optional(),
});

export const Route = createFileRoute("/_app/explore")({
  validateSearch: (s) => searchSchema.parse(s),
  head: () => ({
    meta: [
      { title: "Explore clips — Kizuki" },
      { name: "description", content: "Search real Japanese clips by word, JLPT level, topic or grammar pattern." },
      { property: "og:title", content: "Explore clips — Kizuki" },
      { property: "og:description", content: "Search real Japanese clips by word, JLPT level, topic or grammar pattern." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: Explore,
});

const SECTIONS = [
  { id: "word", icon: "🔍", title: "Search a word", body: "Find clips with any Japanese word" },
  { id: "level", icon: "🎯", title: "Difficulty", body: "Filter by JLPT level" },
  { id: "grammar", icon: "📖", title: "Grammar", body: "Clips that use a pattern" },
  { id: "topic", icon: "🎬", title: "Topic", body: "Anime, food, travel & more" },
] as const;

function Explore() {
  const { data, error, refetch, isLoading } = useContent();
  const search = Route.useSearch();
  const navigate = useNavigate({ from: "/explore" });
  const [text, setText] = useState(search.q ?? "");
  const q = useDeferredValue(text);
  const [panel, setPanel] = useState<"level" | "grammar" | "topic" | null>(null);
  const set = (patch: Partial<z.infer<typeof searchSchema>>) => void navigate({ search: (s) => ({ ...s, ...patch }), replace: true });

  const topics = useMemo(() => {
    if (!data) return [];
    const m = new Map<string, number>();
    for (const c of data.clips) for (const t of c.topics) m.set(t, (m.get(t) ?? 0) + 1);
    return [...m.entries()].sort((a, b) => b[1] - a[1]);
  }, [data]);
  const grammar = useMemo(() => (data ? grammarIndex(data).filter(([, n]) => n >= 2).slice(0, 40) : []), [data]);
  const filtering = !!(q.trim() || search.level || search.topic || search.grammar);
  const results = useMemo(() => (data && filtering ? searchClips(data.clips, q, { level: search.level ?? null, topic: search.topic ?? null, grammar: search.grammar ?? null }) : []), [data, filtering, q, search.level, search.topic, search.grammar]);

  return (
    <div className="absolute inset-0 flex flex-col bg-background pt-[calc(var(--sat)+6px)]">
      <FeedHeader tab="explore" />
      <div className="px-4 pt-2">
        <label className="flex h-12 items-center gap-2 rounded-2xl border-2 border-border bg-surface px-3 focus-within:border-primary">
          <Search className="h-5 w-5 text-faint" />
          <input
            value={text}
            onChange={(e) => { setText(e.target.value.slice(0, 60)); set({ q: e.target.value.slice(0, 60) || undefined }); }}
            placeholder={tr("English, Japanese or romaji")}
            aria-label={tr("Search clips")}
            className="h-full min-w-0 flex-1 bg-transparent text-[1rem] font-bold outline-none placeholder:text-faint"
          />
          {text && <button aria-label={tr("Clear search")} onClick={() => { setText(""); set({ q: undefined }); }}><X className="h-5 w-5 text-faint" /></button>}
        </label>
        <div className="mt-2.5 flex gap-2 overflow-x-auto pb-1 no-scrollbar">
          <Chip active={!!search.level || panel === "level"} onClick={() => setPanel(panel === "level" ? null : "level")}>🎯 {search.level ?? tr("Level")}</Chip>
          <Chip active={!!search.topic || panel === "topic"} onClick={() => setPanel(panel === "topic" ? null : "topic")}>{search.topic ? `${topicEmoji(search.topic)} ${topicLabel(search.topic)}` : tr("🎬 Topic")}</Chip>
          <Chip active={!!search.grammar || panel === "grammar"} onClick={() => setPanel(panel === "grammar" ? null : "grammar")}>📖 {search.grammar ?? tr("Grammar")}</Chip>
          {(search.level || search.topic || search.grammar) && <Chip onClick={() => { set({ level: undefined, topic: undefined, grammar: undefined }); setPanel(null); }}>{tr("Clear")}</Chip>}
        </div>
        {panel === "level" && (
          <div className="mt-2 grid grid-cols-5 gap-2">
            {jlptLevels.map((l) => (
              <button key={l} onClick={() => { set({ level: search.level === l ? undefined : l }); setPanel(null); }} className={cn("press h-11 rounded-xl border-2 text-[0.9375rem] font-black", search.level === l ? "border-primary bg-primary/15 text-primary" : "border-border bg-surface")}>{l}</button>
            ))}
          </div>
        )}
        {panel === "topic" && (
          <div className="mt-2 flex flex-wrap gap-2">
            {topics.map(([t, n]) => <Chip key={t} active={search.topic === t} onClick={() => { set({ topic: search.topic === t ? undefined : t }); setPanel(null); }}>{topicEmoji(t)} {topicLabel(t)} <span className="text-faint">{n}</span></Chip>)}
          </div>
        )}
        {panel === "grammar" && (
          <div className="mt-2 flex max-h-[220px] flex-wrap gap-2 overflow-y-auto no-scrollbar">
            {grammar.map(([g, n]) => <Chip key={g} active={search.grammar === g} className="font-jp" onClick={() => { set({ grammar: search.grammar === g ? undefined : g }); setPanel(null); }}>{g} <span className="font-sans text-faint">{n}</span></Chip>)}
          </div>
        )}
      </div>

      <div className="min-h-0 flex-1 overflow-y-auto px-4 pb-28 pt-3 no-scrollbar">
        {isLoading && <MascotLoader className="pt-16" />}
        {error && <ErrorState title={tr("Couldn't load clips")} onRetry={() => void refetch()} />}
        {data && !filtering && (
          <>
            <div className="flex items-center gap-3 pb-1 pt-2">
              <Mascot pose="read" className="h-16 w-16" />
              <div>
                <p className="text-[1.25rem] font-black">{tr("Explore {n} clips", { n: data.clips.length })}</p>
                <p className="text-[0.875rem] text-muted-foreground">{tr("Search and filter to find exactly what you want to hear.")}</p>
              </div>
            </div>
            <div className="mt-3 grid grid-cols-2 gap-3">
              {SECTIONS.map((s) => (
                <button key={s.id} onClick={() => (s.id === "word" ? document.querySelector<HTMLInputElement>("input[aria-label='Search clips']")?.focus() : setPanel(s.id))} className="press rounded-2xl bg-surface p-4 text-left">
                  <span className="text-[1.75rem]">{s.icon}</span>
                  <p className="mt-2 text-[1rem] font-extrabold">{tr(s.title)}</p>
                  <p className="text-[0.8125rem] leading-snug text-muted-foreground">{tr(s.body)}</p>
                </button>
              ))}
            </div>
            <p className="mb-2 mt-6 text-[0.8125rem] font-black uppercase tracking-[0.12em] text-muted-foreground">{tr("Popular topics")}</p>
            <div className="flex flex-wrap gap-2">
              {topics.slice(0, 10).map(([t]) => <Chip key={t} onClick={() => set({ topic: t })}>{topicEmoji(t)} {topicLabel(t)}</Chip>)}
            </div>
          </>
        )}
        {data && filtering && (
          results.length ? (
            <>
              <p className="mb-2 text-[0.8125rem] font-bold text-muted-foreground">{trn(results.length, "{n} clip", "{n} clips")}</p>
              <div className="grid grid-cols-2 gap-3">
                {results.slice(0, 60).map((id) => data.byId[id] && <ClipCard key={id} clip={data.byId[id]} highlight={q.trim()} />)}
              </div>
            </>
          ) : (
            <div className="flex flex-col items-center pt-10 text-center">
              <Mascot pose="think" className="h-24 w-24" />
              <p className="mt-2 text-[1.0625rem] font-black">{tr("No clips found")}</p>
              <p className="text-[0.875rem] text-muted-foreground">{tr("Try another word or remove a filter.")}</p>
            </div>
          )
        )}
      </div>
    </div>
  );
}
