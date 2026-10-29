import { useEffect, useState } from 'react';
import { useLocation } from '@tanstack/react-router';
import { analyticsChoice, analyticsScreen, setAnalyticsChoice, startAnalytics } from '@/lib/analytics';
import { Toggle } from './ui';
import { tr } from "@/lib/i18n";

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
  const { pathname } = useLocation();
  useEffect(() => startAnalytics(), []);
  useEffect(() => analyticsScreen(pathname), [pathname]);
  return null;
}

export function AnalyticsToggle() {
  const choice = useChoice();
  return <div className="flex items-center justify-between gap-3 px-4 py-3">
    <span className="min-w-0"><span className="block text-[0.9375rem] font-bold">{tr("Usage analytics")}</span><span className="block text-xs text-muted-foreground">{tr("Share activity with PostHog. No messages or payment details.")}</span></span>
    <Toggle label={tr("Usage analytics")} checked={choice === true} onChange={setAnalyticsChoice} />
  </div>;
}