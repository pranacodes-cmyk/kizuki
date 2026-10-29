import { createFileRoute, useNavigate } from '@tanstack/react-router';
import { useState } from 'react';
import { useSuspenseQuery } from '@tanstack/react-query';
import { ArrowRight, RotateCw, Sparkles, Smartphone, LockKeyhole } from 'lucide-react';
import { Button, Modal, Screen, Toggle, TopBar } from '@/components/mimi/ui';
import { Mascot } from '@/components/mimi/Mascot';
import { contentQuery } from '@/lib/feed';
import { widgetPreviewWords } from '@/lib/home-widgets';
import { useApp, dueKeysOf, streakOf } from '@/lib/store';
import { cn } from '@/lib/utils';
import wallpaper from '@/assets/widget-wallpaper.jpg';
import { getLang, tr, useLang } from "@/lib/i18n";

export const Route = createFileRoute('/widgets')({
  // Offline pack storage and relative content URLs are intentionally browser-only.
  ssr: false,
  head: () => ({ meta: [
    { title: 'Home & Lock Screen Widgets — Kizuki' },
    { name: 'description', content: 'Choose a Japanese word widget for your Kizuki Home Screen or iPhone Lock Screen.' },
    { property: 'og:title', content: 'Home & Lock Screen Widgets — Kizuki' },
    { property: 'og:description', content: 'A little Japanese, every time you look. Choose your Kizuki word and review widgets.' },
    { property: 'og:type', content: 'website' }, { name: 'twitter:card', content: 'summary' },
  ] }),
  loader: ({ context }) => context.queryClient.ensureQueryData(contentQuery(getLang())),
  component: WidgetsPage,
});

function WidgetsPage() {
  const navigate = useNavigate();
  const { data: content } = useSuspenseQuery(contentQuery(useLang()));
  const s = useApp();
  const [family, setFamily] = useState('medium');
  const [index, setIndex] = useState(0);
  const [instructions, setInstructions] = useState(false);
  const [platform, setPlatform] = useState('ios');
  const pool = widgetPreviewWords(s, content, Date.now());
  const w = pool[index % Math.max(1, pool.length)];
  const small = family === 'small', lock = family === 'lock';
  const due = s.settings.widgetSaved ? dueKeysOf(s).length : 0;
  const streak = s.settings.widgetSaved ? streakOf(s) : 0;
  const reading = s.settings.widgetReading !== false, meaning = s.settings.widgetMeaning !== false;
  return <Screen>
    <TopBar title={tr("Widgets")} onBack={() => void navigate({ to: '/profile' })} />
    <div className="px-5 pb-8 pt-3">
      <h1 className="text-[1.75rem] font-black leading-tight">{tr("A little Japanese.")}<br />{tr("Every time you look.")}</h1>
      <div className="mt-5 grid grid-cols-4 gap-1.5" aria-label={tr("Widget size")}>
        {[['small', tr('Small')], ['medium', tr('Wide')], ['large', tr('Large')], ['lock', tr('Lock')]].map(([value, label]) => <Button key={value} size="sm" variant={family === value ? 'primary' : 'surface'} className="rounded-lg px-1" aria-pressed={family === value} onClick={() => setFamily(value ?? 'medium')}>{label}</Button>)}
      </div>
      <div className="mt-6 flex justify-center">
        <div aria-label={tr("Widget preview")} className={cn('relative flex flex-col overflow-hidden border border-border bg-surface-2', small ? 'h-[180px] w-[170px] rounded-3xl p-[18px]' : lock ? 'h-[310px] w-full rounded-3xl p-5' : family === 'large' ? 'h-80 w-full rounded-3xl p-[18px]' : 'h-[180px] w-full rounded-3xl p-[18px]')}>
          {lock && <><img src={wallpaper} width={1024} height={1792} loading="lazy" alt={tr("Mount Fuji beside a Japanese lake")} className="absolute inset-0 h-full w-full object-cover" /><div className="absolute inset-0 bg-background/25" /><div className="relative text-center"><p className="text-sm font-bold text-foreground">{new Date().toLocaleDateString(getLang(), { weekday: "long", day: "numeric", month: "long" })}</p><p className="text-[3.5rem] font-black leading-tight text-foreground">10:05</p></div></>}
          {lock ? <div className="relative mt-2 flex h-20 items-center gap-4">
            <span className="min-w-0 max-w-[45%] truncate font-jp text-[2.5rem]">{w?.word ?? '気'}</span>
            <div className="min-w-0 flex-1">{reading && <p className="truncate font-jp text-[0.8125rem] text-muted-foreground">{w?.reading}</p>}{meaning && <p className="line-clamp-2 text-base font-bold">{w?.meaning ?? tr("Japanese")}</p>}</div>
          </div> : <>
            <div className="flex items-center gap-1.5"><Mascot pose="face" className="size-[22px]" /><span className="text-[0.8125rem] font-black text-primary">kizuki</span>{!small && <Sparkles className="ml-auto size-4 text-primary" />}</div>
            <div className={cn('my-auto', !small && 'flex items-center gap-5')}>
              <p className={cn('min-w-0 truncate font-jp font-extrabold', small ? 'text-[2.125rem]' : 'max-w-[45%] text-[2.625rem]')}>{w?.word ?? '気'}</p>
              <div className="min-w-0 flex-1">{reading && <p className={cn('truncate font-jp text-primary', small ? 'text-xs' : 'text-sm')}>{w?.reading}</p>}{meaning && <p className={cn('font-extrabold', small ? 'truncate text-[0.8125rem]' : 'line-clamp-2 text-[1.0625rem]')}>{w?.meaning ?? tr("Japanese")}</p>}</div>
            </div>
            {family === 'large' && w?.example && <p className="mb-auto line-clamp-3 font-jp text-[1.0625rem] text-muted-foreground">{w.example}</p>}
            {!small && <div className="flex items-center gap-2 text-xs"><span className="text-muted-foreground">{due > 0 ? tr("{due} to review", { due }) : tr("A moment of discovery")}</span>{streak > 0 && <span className="ml-auto text-gold">🔥 {streak}</span>}<ArrowRight className="ml-auto size-4 text-primary" /></div>}
          </>}
        </div>
      </div>
      <div className="mt-2 flex justify-end"><Button size="sm" variant="ghost" onClick={() => setIndex(index + 1)}><RotateCw className="size-4" />{tr("Next word")}</Button></div>
      <div className="mt-4 divide-y divide-border">
        {([['widgetSaved', tr('Use my saved learning words')], ['widgetReading', tr('Show reading')], ['widgetMeaning', tr('Show meaning')]] as const).map(([key, label]) => {
          const k = key as 'widgetSaved' | 'widgetReading' | 'widgetMeaning';
          return <div key={key} className="flex items-center justify-between gap-3 py-3"><span className="text-[0.9375rem] font-bold">{label}</span><Toggle label={label} checked={k === 'widgetSaved' ? s.settings[k] === true : s.settings[k] !== false} onChange={(v) => s.setSettings({ [k]: v })} /></div>;
        })}
      </div>
      <p className="mt-2 text-xs leading-relaxed text-muted-foreground">{tr("Saved words and review progress will be visible to anyone looking at your screen.")}</p>
      <Button className="mt-6" onClick={() => setInstructions(true)}><Smartphone className="size-5" />{tr("Add widget")}</Button>
    </div>
    <Modal open={instructions} onClose={() => setInstructions(false)}>
      <h2 className="text-xl font-black">{tr("Add Kizuki to your screen")}</h2>
      <div className="mt-4 grid grid-cols-2 gap-2">{['ios', 'android'].map((p) => <Button key={p} size="sm" variant={platform === p ? 'primary' : 'surface'} onClick={() => setPlatform(p)}>{p === 'ios' ? tr("iPhone") : tr("Android")}</Button>)}</div>
      <p className="mt-4 text-[0.9375rem] leading-relaxed text-muted-foreground">{platform === 'ios' ? lock ? tr("Touch and hold your Lock Screen → Customize → Lock Screen → Add Widgets → Kizuki.") : tr("Touch and hold your Home Screen → Edit → Add Widget → Kizuki. Choose a size, then tap Add Widget.") : lock ? tr("Lock-screen widgets are supported only on some Android versions and devices. Use your device’s widget picker if available.") : tr("Touch and hold your Home Screen → Widgets → Kizuki. Drag a widget onto your screen.")}</p>
      <p className="mt-3 text-xs text-muted-foreground"><LockKeyhole className="mr-1 inline size-3" />{tr("System widgets are added on your phone, not from this web preview.")}</p>
      <Button className="mt-5" onClick={() => setInstructions(false)}>{tr("Got it")}</Button>
    </Modal>
  </Screen>;
}