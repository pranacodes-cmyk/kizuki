import { Link } from "@tanstack/react-router";
import { Check } from "lucide-react";

import type { Clip } from "@/lib/content";
import { thumbOf } from "@/lib/content";
import { useContent } from "@/lib/feed";
import { useApp } from "@/lib/store";

import { Mascot } from "./Mascot";

/** Thumbnail card linking to a single clip (Explore, Saved, History, Examples). */
export function ClipCard({ clip, highlight }: { clip: Clip; highlight?: string | undefined }) {
  const seen = useApp((s) => (s.seen[clip.id] ?? 0) > 0);
  const dur = Math.round(clip.end - clip.start);
  const line = (highlight && clip.lines.find((l) => l.ja.includes(highlight))) || clip.lines[0];
  return (
    <Link to="/clip/$clipId" params={{ clipId: clip.id }} className="press block overflow-hidden rounded-2xl bg-surface">
      <div className="relative">
        <img src={thumbOf(clip.videoId)} alt="" loading="lazy" className="aspect-video w-full object-cover" />
        <span className="absolute bottom-1.5 right-1.5 rounded-md bg-stage/80 px-1.5 py-0.5 text-[0.6875rem] font-black tabular">0:{String(dur).padStart(2, "0")}</span>
        <span className="absolute left-1.5 top-1.5 rounded-md bg-stage/80 px-1.5 py-0.5 text-[0.6875rem] font-black">JLPT {clip.level}</span>
        {seen && <span className="absolute right-1.5 top-1.5 flex h-5 w-5 items-center justify-center rounded-full bg-success"><Check className="h-3 w-3 text-primary-foreground" strokeWidth={4} /></span>}
      </div>
      <div className="px-2.5 py-2">
        <p className="line-clamp-1 font-jp text-[0.875rem] font-bold">{line?.ja}</p>
        <p className="line-clamp-1 text-[0.75rem] text-muted-foreground">{clip.title}</p>
      </div>
    </Link>
  );
}

/** Two-column grid of clip cards with an empty state. */
export function ClipGrid({ ids, empty }: { ids: string[]; empty: string }) {
  const { data } = useContent();
  if (!data) return null;
  if (!ids.length) {
    return (
      <div className="flex flex-1 flex-col items-center justify-center px-8 pb-16 text-center">
        <Mascot pose="think" className="h-24 w-24" />
        <p className="mt-2 text-[0.9375rem] font-bold text-muted-foreground">{empty}</p>
      </div>
    );
  }
  return (
    <div className="grid grid-cols-2 gap-3 px-4 pb-8 pt-2">
      {ids.map((id) => data.byId[id] && <ClipCard key={id} clip={data.byId[id]} />)}
    </div>
  );
}
