import { createFileRoute, Link, useRouter } from "@tanstack/react-router";
import { AnimatePresence, motion } from "motion/react";
import { ChevronDown, CircleCheck } from "lucide-react";
import { useEffect, useState } from "react";

import { Mascot } from "@/components/mimi/Mascot";
import { Button, Screen, SectionTitle, TopBar } from "@/components/mimi/ui";
import { useSession } from "@/hooks/use-session";
import { supabase } from "@/integrations/supabase/client";
import { SUPPORT_MESSAGE_MAX, SUPPORT_TOPICS, supportMessageError, type SupportTopic } from "@/lib/logic";
import { SUPPORT_FAQ, SUPPORT_TOPIC_LABELS } from "@/lib/support";
import { cn } from "@/lib/utils";

const TITLE = "Help & support — Kizuki";
const DESCRIPTION = "Answers about Kizuki subscriptions, free trials, videos and your account, plus a form to message the Kizuki team.";

export const Route = createFileRoute("/support")({
  head: () => ({
    meta: [
      { title: TITLE },
      { name: "description", content: DESCRIPTION },
      { property: "og:title", content: TITLE },
      { property: "og:description", content: DESCRIPTION },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: SupportPage,
});

/** Help & support: common questions + a message form saved to public.support_messages. Mirrored by mobile/lib/screens/support.dart. */
function SupportPage() {
  const router = useRouter();
  const session = useSession();
  const [topic, setTopic] = useState<SupportTopic>("other");
  const [email, setEmail] = useState("");
  const [message, setMessage] = useState("");
  const [open, setOpen] = useState<number | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [sentTo, setSentTo] = useState<string | null>(null);

  useEffect(() => {
    if (session?.user.email) setEmail((e) => e || session.user.email!);
  }, [session]);

  async function send() {
    const to = email.trim().toLowerCase();
    const problem = supportMessageError(to, message);
    if (problem) return setError(problem);
    setBusy(true);
    setError(null);
    const { error: err } = await supabase.from("support_messages").insert({
      email: to,
      topic,
      message: message.trim(),
      platform: "web",
      user_id: session?.user.id ?? null,
    });
    setBusy(false);
    if (err) {
      console.error("support", err.message);
      return setError("Couldn't send right now. Check your connection and try again.");
    }
    setSentTo(to);
    setMessage("");
  }

  const count = message.trim().length;
  const field = "w-full rounded-2xl border-2 border-border bg-surface px-4 text-[1rem] font-bold outline-none placeholder:text-faint focus:border-primary";

  return (
    <Screen>
      <TopBar title="Help & support" onBack={() => (router.history.canGoBack() ? router.history.back() : void router.navigate({ to: "/profile" }))} />
      <div className="px-5 pb-10 pt-1">
        <div className="flex items-center gap-3">
          <Mascot pose="wave" className="h-16 w-16 shrink-0" />
          <div>
            <h1 className="text-[1.375rem] font-black leading-tight">How can we help?</h1>
            <p className="mt-0.5 text-[0.875rem] leading-snug text-muted-foreground">Quick answers first. A real person reads every message.</p>
          </div>
        </div>

        <SectionTitle>Common questions</SectionTitle>
        <div className="overflow-hidden rounded-[1.25rem] border border-border bg-surface">
          {SUPPORT_FAQ.map((f, i) => (
            <button key={f.q} onClick={() => setOpen(open === i ? null : i)} aria-expanded={open === i} className={cn("block w-full px-4 py-3.5 text-left", i > 0 && "border-t border-border")}>
              <span className="flex items-center gap-2">
                <span className="flex-1 text-[0.9375rem] font-extrabold leading-snug">{f.q}</span>
                <ChevronDown className={cn("h-5 w-5 shrink-0 text-muted-foreground transition-transform duration-200", open === i && "rotate-180")} />
              </span>
              <AnimatePresence initial={false}>
                {open === i && (
                  <motion.span initial={{ height: 0, opacity: 0 }} animate={{ height: "auto", opacity: 1 }} exit={{ height: 0, opacity: 0 }} transition={{ duration: 0.2 }} className="block overflow-hidden">
                    <span className="block pt-2 text-[0.875rem] leading-relaxed text-muted-foreground">{f.a}</span>
                  </motion.span>
                )}
              </AnimatePresence>
            </button>
          ))}
        </div>

        <SectionTitle>Send us a message</SectionTitle>
        {sentTo ? (
          <div className="rounded-[1.25rem] bg-success-soft p-4">
            <p className="flex items-center gap-2 text-[1rem] font-black text-success"><CircleCheck className="h-[22px] w-[22px]" /> Message sent</p>
            <p className="mt-1.5 text-[0.875rem] leading-relaxed">Thanks! We usually reply within 2 days to {sentTo}.</p>
            <Button variant="surface" className="mt-3 h-12" onClick={() => setSentTo(null)}>Send another message</Button>
          </div>
        ) : (
          <div>
            <p className="text-[0.875rem] font-bold text-muted-foreground">What is it about?</p>
            <div className="mt-2 flex flex-wrap gap-2">
              {SUPPORT_TOPICS.map((t) => (
                <button key={t} onClick={() => setTopic(t)} aria-pressed={topic === t} className={cn("press rounded-full border-2 px-3.5 py-2 text-[0.875rem] font-extrabold transition-colors", topic === t ? "border-primary bg-primary/15 text-primary" : "border-border bg-surface text-foreground")}>
                  {SUPPORT_TOPIC_LABELS[t]}
                </button>
              ))}
            </div>
            <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} maxLength={255} placeholder="Your email" autoComplete="email" aria-label="Your email" className={cn(field, "mt-4 h-14")} />
            <textarea value={message} onChange={(e) => setMessage(e.target.value)} maxLength={SUPPORT_MESSAGE_MAX} rows={5} placeholder="Tell us what happened or what you would like…" aria-label="Message" className={cn(field, "mt-3 resize-none py-4 leading-snug")} />
            <p className="mt-1.5 pr-1 text-right text-[0.75rem] font-bold text-faint">{count} / {SUPPORT_MESSAGE_MAX}</p>
            {error && <p role="alert" className="mt-2 rounded-xl bg-danger-soft px-3 py-2 text-[0.875rem] font-bold text-danger">{error}</p>}
            <Button className="mt-3" disabled={busy} onClick={() => void send()}>{busy ? "Sending…" : "Send message"}</Button>
          </div>
        )}

        <p className="mt-6 text-center text-[0.75rem] text-faint">
          <Link to="/terms" className="underline">Terms of Service</Link> · <Link to="/privacy" className="underline">Privacy Policy</Link>
        </p>
      </div>
    </Screen>
  );
}
