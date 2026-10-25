// "Ask Kizuki" chat about a line (and optionally a tapped word) — mirrors mobile/lib/widgets/ask_sheet.dart.
import { useChat } from "@ai-sdk/react";
import { useNavigate } from "@tanstack/react-router";
import { DefaultChatTransport, type UIMessage } from "ai";
import { ArrowUp, CircleAlert, Square } from "lucide-react";
import { Fragment, useEffect, useMemo, useRef, useState } from "react";

import { track } from '@/lib/analytics';
import { supabase } from "@/lib/backend";
import { ASK_PATH, askErrorText, askGreeting, askSuggestions, type AskContext } from "@/lib/ask";
import { ASK_MAX_CHARS, askHistory, asksLeft, canAsk, cleanQuestion } from "@/lib/logic";
import { FREE_DAILY_ASKS } from "@/lib/paywall";
import { asksTodayOf, useApp } from "@/lib/store";
import { getSession } from "@/lib/sync";
import { useTour } from "@/lib/tour-store";
import { cn } from "@/lib/utils";

import { Mascot } from "./Mascot";
import { Button, Sheet } from "./ui";

export function AskSheet({ open, onClose, context }: { open: boolean; onClose: () => void; context: AskContext }) {
  const touring = useTour((s) => s.index != null);
  return (
    <Sheet open={open} onClose={onClose} maxHeight="92%" className={touring ? "h-[56%]" : "h-[80%]"}>
      {open && <AskChat context={context} onClose={onClose} tourExample={touring} />}
    </Sheet>
  );
}

const textOf = (m: UIMessage) => m.parts.map((p) => (p.type === "text" ? p.text : "")).join("");

/** Server errors arrive as the response body ({"error": "..."}) or as the stream's error text. */
function errorCopy(e: Error) {
  const raw = e.message ?? "";
  try {
    const j = JSON.parse(raw) as { error?: unknown };
    if (typeof j.error === "string") return j.error;
  } catch {
    /* not JSON */
  }
  if (/failed to fetch|networkerror|load failed/i.test(raw)) return askErrorText(null);
  return raw && raw.length < 160 && !raw.startsWith("<") && !raw.startsWith("{") ? raw : askErrorText(500);
}

function AskChat({ context, onClose, tourExample }: { context: AskContext; onClose: () => void; tourExample: boolean }) {
  const navigate = useNavigate();
  useEffect(() => { track('ask_opened', { has_word_context: Boolean(context.word) }); return () => track('ask_closed'); }, []);
  const premium = useApp((s) => s.premium.active);
  const asked = useApp(asksTodayOf);
  const [signedIn] = useState(() => !!getSession());
  const [input, setInput] = useState("");
  const [emptyAnswer, setEmptyAnswer] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);

  const transport = useMemo(
    () =>
      new DefaultChatTransport<UIMessage>({
        api: ASK_PATH,
        prepareSendMessagesRequest: async ({ messages }) => {
          const { data } = await supabase.auth.getSession();
          const token = data.session?.access_token;
          const turns = askHistory(messages.map((m) => ({ id: m.id, role: m.role === "user" ? ("user" as const) : ("assistant" as const), text: textOf(m) })));
          return {
            body: { context, messages: turns.map((t) => ({ id: t.id, role: t.role, parts: [{ type: "text", text: t.text }] })) },
            headers: token ? { Authorization: `Bearer ${token}` } : {},
          };
        },
      }),
    [context],
  );
  const { messages, sendMessage, status, error, stop, regenerate, clearError } = useChat({
    transport,
    onError: () => track('ask_failed', { category: 'request' }),
    onFinish: ({ message, isAbort, isError, isDisconnect }) => {
      if (isAbort || isError || isDisconnect) return;
      if (textOf(message).trim()) useApp.getState().recordAsk();
      else setEmptyAnswer(true);
    },
  });

  const busy = status === "submitted" || status === "streaming";
  const last = messages[messages.length - 1];
  const waiting = status === "submitted" || (status === "streaming" && (!last || last.role !== "assistant" || !textOf(last).trim()));
  const left = asksLeft(premium, asked, FREE_DAILY_ASKS);
  const errorText = error ? errorCopy(error) : emptyAnswer ? askErrorText(500) : null;
  const shown = messages.filter((m) => textOf(m).trim() !== "");
  const empty = cleanQuestion(input) === "";

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: "smooth" });
  }, [messages, status, errorText]);

  const send = (raw: string) => {
    const q = cleanQuestion(raw);
    if (!q || busy || !canAsk(premium, asked, FREE_DAILY_ASKS)) return;
    track('ask_submitted', { has_word_context: Boolean(context.word) });
    setInput("");
    setEmptyAnswer(false);
    clearError();
    void sendMessage({ text: q });
  };
  const retry = () => {
    setEmptyAnswer(false);
    clearError();
    void regenerate();
  };
  const go = (to: "/account" | "/trial") => {
    onClose();
    void navigate({ to });
  };

  return (
    <div data-tour={tourExample ? "askPanel" : undefined} className="flex min-h-0 flex-1 flex-col">
      <div className="flex items-center gap-3 px-5 pt-1.5">
        <Mascot pose="think" className="h-11 w-11 shrink-0" />
        <div className="min-w-0 flex-1">
          <p className="text-[1.125rem] font-black">Ask Kizuki</p>
          <p className="text-[0.8125rem] font-bold text-muted-foreground">
            {context.word ? <>About <span className="font-jp text-foreground">{context.word.head}</span> in this line</> : "About this line"}
          </p>
        </div>
      </div>
      <div className="mx-5 mt-3 rounded-2xl bg-surface-2/60 px-3.5 py-2.5">
        <p className="line-clamp-2 font-jp text-[0.9375rem] font-bold leading-snug">{context.line.ja}</p>
        {context.line.en && <p className="mt-0.5 line-clamp-2 text-[0.8125rem] text-muted-foreground">{context.line.en}</p>}
      </div>

      {tourExample ? (
        <div className="min-h-0 flex-1 overflow-y-auto px-5 pb-3 pt-3.5 no-scrollbar">
          <p className="mb-2.5 text-[0.6875rem] font-extrabold text-muted-foreground">EXAMPLE · NO QUESTION SENT</p>
          <UserBubble text="What does this word mean here?" />
          <Bubble text={context.word?.gloss
            ? `**${context.word.surface}** here means **${context.word.gloss}**.\nThe sentence above shows the context.`
            : context.line.en ? `This line means: **${context.line.en}**` : "Ask about grammar, meaning or another example from this line."} />
        </div>
      ) : !signedIn ? (
        <div className="flex-1 overflow-y-auto px-6 pb-4 pt-5 text-center no-scrollbar">
          <Mascot pose="wave" className="mx-auto h-24 w-24" />
          <p className="mt-3 text-[1.25rem] font-black">Ask Kizuki anything</p>
          <p className="mt-1.5 text-[0.9375rem] font-medium leading-snug text-muted-foreground">
            Sign in with your Premium account to ask about this line. Your words and streak sync too.
          </p>
          <Button className="mt-4 h-[52px]" onClick={() => go("/account")}>Sign in</Button>
        </div>
      ) : (
        <>
          <div ref={scrollRef} className="min-h-0 flex-1 overflow-y-auto px-5 pb-3 pt-3.5 no-scrollbar">
            <Bubble text={askGreeting(context.word)} />
            {shown.length === 0 && messages.length === 0 && left !== 0 && (
              <div className="mb-2 ml-10 mt-0.5 flex flex-wrap gap-2">
                {askSuggestions(!!context.word).map((s) => (
                  <button key={s} onClick={() => send(s)} className="press rounded-full border border-border bg-surface-2 px-3 py-2 text-[0.8125rem] font-extrabold">{s}</button>
                ))}
              </div>
            )}
            {shown.map((m) => (m.role === "user" ? <UserBubble key={m.id} text={textOf(m)} /> : <Bubble key={m.id} text={textOf(m)} />))}
            {waiting && <Bubble thinking />}
            {errorText && !busy && (
              <div className="mb-2.5 ml-10 flex items-center gap-2 rounded-2xl bg-danger-soft py-2.5 pl-3.5 pr-2">
                <CircleAlert className="h-4 w-4 shrink-0 text-danger" />
                <p className="min-w-0 flex-1 text-[0.875rem] font-semibold leading-snug">{errorText}</p>
                <button onClick={retry} className="press px-2 py-1.5 text-[0.875rem] font-black text-primary">Try again</button>
              </div>
            )}
          </div>

          {left === 0 && !busy ? (
            <div className="mx-4 mb-2 mt-1 rounded-2xl bg-primary/10 px-4 py-3.5 text-center">
              <p className="text-[0.9375rem] font-black">Premium is required to ask Kizuki</p>
              <p className="mt-0.5 text-[0.8125rem] font-medium text-muted-foreground">Premium gives you unlimited answers from Kizuki.</p>
              <Button className="mt-2.5 h-12" onClick={() => go("/trial")}>See plans</Button>
            </div>
          ) : (
            <form
              onSubmit={(e) => { e.preventDefault(); send(input); }}
              className="flex items-end gap-2 border-t border-border px-4 py-2"
            >
              <textarea
                value={input}
                onChange={(e) => setInput(e.target.value.slice(0, ASK_MAX_CHARS))}
                onKeyDown={(e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); send(input); } }}
                disabled={busy}
                rows={1}
                maxLength={ASK_MAX_CHARS}
                aria-label="Your question"
                placeholder={context.word ? "Ask about this word…" : "Ask about this line…"}
                className="max-h-28 min-h-[44px] flex-1 resize-none rounded-[22px] border-2 border-border bg-surface-2 px-4 py-2.5 text-[0.9375rem] font-medium outline-none placeholder:text-faint focus:border-primary disabled:opacity-70"
              />
              {busy ? (
                <button type="button" aria-label="Stop answer" onClick={() => void stop()} className="press flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-surface-2">
                  <Square className="h-4 w-4" fill="currentColor" />
                </button>
              ) : (
                <button type="submit" aria-label="Send question" disabled={empty} className={cn("press flex h-11 w-11 shrink-0 items-center justify-center rounded-full", empty ? "bg-primary-dim text-primary-dim-foreground" : "bg-primary text-primary-foreground")}>
                  <ArrowUp className="h-5 w-5" strokeWidth={3} />
                </button>
              )}
            </form>
          )}
          {/* There are no free questions any more: the Premium card explains access. */}
          {left === null && (
            <p className="px-5 pb-1.5 text-center text-[0.6875rem] font-semibold text-faint">
              AI answers can be wrong — double-check anything important.
            </p>
          )}
        </>
      )}
    </div>
  );
}

/** Light markdown: **bold** and "- " bullets, one paragraph per line. */
export function AskText({ text }: { text: string }) {
  const lines = text.split("\n").filter((l) => l.trim() !== "");
  const spans = (line: string) => line.split("**").map((p, i) => (p ? (i % 2 ? <b key={i} className="font-black">{p}</b> : <Fragment key={i}>{p}</Fragment>) : null));
  return (
    <div className="space-y-1.5">
      {lines.map((l, i) =>
        /^\s*[-*•]\s+/.test(l) ? (
          <p key={i} className="flex"><span className="shrink-0">•&nbsp;&nbsp;</span><span>{spans(l.replace(/^\s*[-*•]\s+/, ""))}</span></p>
        ) : (
          <p key={i}>{spans(l.trim())}</p>
        ),
      )}
    </div>
  );
}

function Bubble({ text = "", thinking = false }: { text?: string; thinking?: boolean }) {
  return (
    <div className="mb-2.5 flex items-start gap-2.5 pr-6">
      <Mascot pose="face" className="h-[30px] w-[30px] shrink-0" />
      <div className="min-w-0 rounded-2xl rounded-tl-[4px] bg-surface-2 px-3.5 py-2.5 text-[0.9375rem] font-medium leading-[1.45]">
        {thinking ? (
          <span className="flex items-center gap-2 text-[0.875rem] font-semibold text-muted-foreground">
            <span className="flex gap-1">
              {[0, 1, 2].map((i) => <span key={i} className="h-1.5 w-1.5 animate-pulse rounded-full bg-muted-foreground" style={{ animationDelay: `${i * 160}ms` }} />)}
            </span>
            Kizuki is thinking…
          </span>
        ) : (
          <AskText text={text} />
        )}
      </div>
    </div>
  );
}

function UserBubble({ text }: { text: string }) {
  return (
    <div className="mb-2.5 flex justify-end pl-12">
      <p className="rounded-2xl rounded-tr-[4px] bg-primary px-3.5 py-2.5 text-[0.9375rem] font-bold leading-snug text-primary-foreground">{text}</p>
    </div>
  );
}
