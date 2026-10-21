import { createFileRoute } from "@tanstack/react-router";

// Public path so the Android app can reach it; the handler itself requires a signed-in learner.
export const Route = createFileRoute("/api/public/ask")({
  server: {
    handlers: {
      OPTIONS: async () => {
        const { ASK_CORS } = await import("@/lib/server/ask.server");
        return new Response(null, { status: 204, headers: ASK_CORS });
      },
      POST: async ({ request }) => {
        const { handleAsk } = await import("@/lib/server/ask.server");
        return handleAsk(request);
      },
    },
  },
});
