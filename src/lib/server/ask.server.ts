// Server-only: the "Ask Kizuki" tutor. Validates the request, checks the learner's session and
// streams an answer from Lovable AI (Responses API) as an AI SDK UI-message stream.
import { createOpenAI } from "@ai-sdk/openai";
import { createClient } from "@supabase/supabase-js";
import { convertToModelMessages, streamText, type UIMessage } from "ai";
import { z } from "zod";

import { ASK_MAX_CHARS, ASK_MAX_MESSAGES } from "@/lib/logic";
import { hasStoreSubscription } from './subscription.server';

import { createLovableAiGatewayRunIdFetch, getLovableAiGatewayRunId, withLovableAiGatewayRunIdHeader } from "./run-id";

const GATEWAY_URL = "https://ai.gateway.lovable.dev/v1";
const MODEL = "openai/gpt-6-astra";

export const ASK_CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, content-type, x-lovable-aig-run-id",
};

const Part = z.object({ type: z.string().max(40), text: z.string().max(8000).optional() }).passthrough();
const Message = z.object({ id: z.string().max(120), role: z.enum(["user", "assistant"]), parts: z.array(Part).max(40) });
const Body = z.object({
  context: z.object({
    clipId: z.string().max(80),
    title: z.string().max(300),
    level: z.string().max(4),
    learnerLevel: z.string().max(4),
    line: z.object({ ja: z.string().min(1).max(500), en: z.string().max(800) }),
    word: z.object({ surface: z.string().max(60), head: z.string().max(60), reading: z.string().max(80), gloss: z.string().max(400) }).nullable(),
  }),
  messages: z.array(Message).min(1).max(ASK_MAX_MESSAGES),
});
export type AskBody = z.infer<typeof Body>;

const json = (status: number, error: string) =>
  new Response(JSON.stringify({ error }), { status, headers: { "Content-Type": "application/json", ...ASK_CORS } });

const textOf = (m: z.infer<typeof Message>) =>
  m.parts.filter((p) => p.type === "text" && typeof p.text === "string").map((p) => p.text).join("");

function instructions(c: AskBody["context"]) {
  const word = c.word
    ? `\nThe learner tapped the word 「${c.word.surface}」 (dictionary form ${c.word.head}${c.word.reading ? `, read ${c.word.reading}` : ""}${c.word.gloss ? `, meaning "${c.word.gloss}"` : ""}).`
    : "";
  return `You are Kizuki, a warm, encouraging fox who tutors Japanese inside a short-video learning app.
The learner (around JLPT ${c.learnerLevel}) is watching a real YouTube clip titled "${c.title}" (clip level ${c.level}) and asks about this transcript line:
「${c.line.ja}」 — "${c.line.en}"${word}

How to answer:
- Reply in simple, friendly English. Keep it short: 2–5 sentences or up to 4 bullet points, under 130 words.
- Always write Japanese with its kana reading in parentheses after any kanji, e.g. 食べる (たべる).
- Explain like a patient friend: what it means here, why this form, and when people say it. Use **bold** for the key Japanese bit.
- For examples, give at most 2 short sentences, each with an English translation.
- If unsure (auto-transcripts can mishear), say so briefly.
- Only help with Japanese language and culture. For anything else, gently steer back to the clip.`;
}

function errorText(e: unknown) {
  const status = typeof e === "object" && e && "statusCode" in e ? Number((e as { statusCode?: number }).statusCode) : 0;
  if (status === 429) return "Kizuki is busy right now — try again in a moment.";
  if (status === 402 || status === 403) return "Ask Kizuki is paused for now. Please try again later.";
  return "Kizuki couldn't answer that. Please try again.";
}

export async function handleAsk(request: Request): Promise<Response> {
  const apiKey = process.env["LOVABLE_API_KEY"];
  const sbUrl = process.env["SUPABASE_URL"];
  const sbKey = process.env["SUPABASE_PUBLISHABLE_KEY"];
  if (!apiKey || !sbUrl || !sbKey) return json(500, "Ask Kizuki isn't set up yet.");

  // Only signed-in learners can ask (keeps the tutor from being used anonymously).
  const token = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "").trim();
  if (!token) return json(401, "Please sign in to ask Kizuki.");
  const auth = createClient(sbUrl, sbKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: user, error: authError } = await auth.auth.getUser(token);
  if (authError || !user?.user) return json(401, "Please sign in again to ask Kizuki.");
  const billingKey = process.env['REVENUECAT_V2_SECRET_KEY'];
  if (!billingKey) return json(503, "We couldn't verify your subscription. Please try again.");
  try {
    if (!await hasStoreSubscription(user.user.id, billingKey)) return json(403, "Renew or restore your Premium subscription to ask Kizuki.");
  } catch {
    return json(503, "We couldn't verify your subscription. Please try again.");
  }

  let body: AskBody;
  try {
    const parsed = Body.safeParse(await request.json());
    if (!parsed.success) return json(400, "That question couldn't be sent. Please try again.");
    body = parsed.data;
  } catch {
    return json(400, "That question couldn't be sent. Please try again.");
  }
  const last = body.messages[body.messages.length - 1];
  if (!last || last.role !== "user") return json(400, "That question couldn't be sent. Please try again.");
  for (const m of body.messages) {
    const t = textOf(m);
    if (m.role === "user" && (t.trim() === "" || t.length > ASK_MAX_CHARS)) return json(400, `Questions can be up to ${ASK_MAX_CHARS} characters.`);
  }

  return streamAsk(request, body, apiKey);
}

/** Stream the tutor's answer for an already validated, authorised request. */
export async function streamAsk(request: Request, body: AskBody, apiKey: string): Promise<Response> {
  // History keeps only text: the tutor needs the words, not earlier reasoning.
  const ui: UIMessage[] = body.messages
    .map((m) => ({ id: m.id, role: m.role, parts: [{ type: "text" as const, text: textOf(m).slice(0, 6000) }] }))
    .filter((m) => m.parts[0]?.text.trim() !== "");
  const messages = await convertToModelMessages(ui);

  const runIdFetch = createLovableAiGatewayRunIdFetch(getLovableAiGatewayRunId(request));
  const provider = createOpenAI({
    baseURL: GATEWAY_URL,
    apiKey,
    headers: { "Lovable-API-Key": apiKey, "X-Lovable-AIG-SDK": "vercel-ai-sdk" },
    fetch: runIdFetch.fetch,
  });
  const result = streamText({
    model: provider.responses(MODEL),
    instructions: instructions(body.context),
    messages,
    abortSignal: request.signal,
    providerOptions: {
      openai: {
        store: false,
        forceReasoning: true,
        reasoningEffort: "low",
        reasoningSummary: "auto",
        include: ["reasoning.encrypted_content"],
      },
    },
    onError: ({ error }) => console.error("ask: model call failed", error),
  });
  return withLovableAiGatewayRunIdHeader(
    result.toUIMessageStreamResponse({ sendReasoning: true, onError: errorText }),
    runIdFetch,
    ASK_CORS,
  );
}
