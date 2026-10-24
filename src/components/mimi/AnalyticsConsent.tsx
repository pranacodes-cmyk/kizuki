import { useEffect, useState } from 'react';
import { useLocation } from '@tanstack/react-router';
import { ANALYTICS_NOTICE, analyticsChoice, analyticsScreen, setAnalyticsChoice, startAnalytics } from '@/lib/analytics';
import { Button, Toggle } from './ui';

function useChoice() {
  const [choice, setChoice] = useState<boolean | null>(false);
  useEffect(() => {
    const update = () => setChoice(analyticsChoice());
    update();
    window.addEventListener('kizuki-analytics-choice', update);
    window.addEventListener('storage', update);
    return () => { window.removeEventListener('kizuki-analytics-choice', update); window.removeEventListener('storage', update); };
  }, []);
  return choice;
}

export function AnalyticsConsent() {
  const choice = useChoice();
  const { pathname } = useLocation();
  useEffect(() => startAnalytics(), []);
  useEffect(() => analyticsScreen(pathname), [pathname]);
  if (choice !== null) return null;
  return <div role="dialog" aria-modal="true" aria-labelledby="analytics-title" className="absolute inset-0 z-[250] flex items-center justify-center overflow-y-auto bg-background/95 p-6">
    <div className="w-full">
      <h2 id="analytics-title" className="text-2xl font-black">Usage analytics</h2>
      <p className="mt-4 text-[0.9375rem] leading-relaxed text-muted-foreground">{ANALYTICS_NOTICE}</p>
      <div className="mt-6 space-y-3">
        <Button variant="surface" className="w-full" onClick={() => setAnalyticsChoice(true)}>Allow analytics</Button>
        <Button variant="surface" className="w-full" onClick={() => setAnalyticsChoice(false)}>No thanks</Button>
      </div>
    </div>
  </div>;
}

export function AnalyticsToggle() {
  const choice = useChoice();
  return <div className="flex items-center justify-between gap-3 px-4 py-3">
    <span className="min-w-0"><span className="block text-[0.9375rem] font-bold">Usage analytics</span><span className="block text-xs text-muted-foreground">Share activity with PostHog. No messages or payment details.</span></span>
    <Toggle label="Usage analytics" checked={choice === true} onChange={setAnalyticsChoice} />
  </div>;
}