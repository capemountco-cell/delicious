import Anthropic from "@anthropic-ai/sdk";
import { createFileRoute } from "@tanstack/react-router";

import { parseTidyInput, tidyVideo } from "@/lib/tidy";

// POST /api/tidy — used by the delicious iOS app.
// Body: { url, title?, author?, provider? } → { title, tags } or 204 when unavailable.
// The app treats anything other than 200 as "keep what we have", silently.

const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });

export const Route = createFileRoute("/api/tidy")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        const apiKey = process.env["ANTHROPIC_API_KEY"];
        if (!apiKey) return new Response(null, { status: 204 });

        let body: unknown;
        try {
          body = await request.json();
        } catch {
          return json({ error: "invalid json" }, 400);
        }
        const input = parseTidyInput(body);
        if (!input) return json({ error: "invalid input" }, 400);

        try {
          const result = await tidyVideo(
            new Anthropic({ apiKey, timeout: 20_000, maxRetries: 1 }),
            input,
          );
          return result ? json(result) : new Response(null, { status: 204 });
        } catch (error) {
          if (error instanceof Anthropic.RateLimitError) {
            console.warn("tidy: rate limited");
          } else if (error instanceof Anthropic.APIError) {
            console.error(`tidy: API error ${error.status}`);
          } else {
            console.error("tidy: failed", error);
          }
          return new Response(null, { status: 204 });
        }
      },
    },
  },
});
