// Real home-feed preview; mirrors mobile/lib/widgets/feed_preview.dart.
import { Bookmark, Flame, Play, Search, User } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";

import { previewOrder, useContent } from "@/lib/feed";
import { useFeedPager } from "@/lib/feed-pager";
import { useApp } from "@/lib/store";
import { ClipView } from "./ClipView";
import { tr } from "@/lib/i18n";

export function FeedPreview() {
  const { data, error } = useContent();
  const clips = useMemo(() => data ? previewOrder(data, useApp.getState()).slice(0, 12)
    .flatMap((id) => data.byId[id] ? [data.byId[id]] : []) : [], [data]);
  const frame = useRef<HTMLDivElement>(null);
  const box = useRef<HTMLDivElement>(null);
  const [size, setSize] = useState({ scale: 1, height: 640 });
  const [active, setActive] = useState(0);
  const step = useFeedPager(box, clips.length, setActive);

  useEffect(() => {
    const el = frame.current;
    if (!el) return;
    const observer = new ResizeObserver(() => {
      const scale = el.clientWidth / 360;
      if (scale > 0 && el.clientHeight > 0) setSize({ scale, height: el.clientHeight / scale });
    });
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  return (
    <div ref={frame} className="relative h-full w-full overflow-hidden bg-background" aria-label={tr("Preview of your feed")}>
      <div className="absolute left-0 top-0 flex w-[360px] origin-top-left flex-col" style={{ height: size.height, transform: `scale(${size.scale})` }}>
        <div className="flex shrink-0 items-center justify-between px-4 pb-2 pt-3">
          <span className="text-[1.125rem] font-black">{tr("For you")}</span><Flame className="h-5 w-5 text-primary" />
        </div>
        <div ref={box} className="no-scrollbar min-h-0 flex-1 overflow-y-auto overscroll-contain"
          onWheel={(e) => { if (Math.abs(e.deltaY) > 10) { e.preventDefault(); step(e.deltaY > 0 ? 1 : -1); } }}>
          {data && clips.map((clip, i) => <div key={clip.id} data-preview-clip={clip.id} className="h-full w-full overflow-hidden">
            <ClipView clip={clip} content={data} active={i === active} inFeed bottomInset={12} />
          </div>)}
          {error && <p className="p-4 text-center text-muted-foreground">{tr("Your clips will appear on Home")}</p>}
        </div>
        <div className="flex h-12 shrink-0 items-center justify-evenly bg-surface">
          <Play className="h-5 w-5 text-primary" /><Search className="h-5 w-5 text-faint" />
          <Bookmark className="h-5 w-5 text-faint" /><User className="h-5 w-5 text-faint" />
        </div>
      </div>
    </div>
  );
}
