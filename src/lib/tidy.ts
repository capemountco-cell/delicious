import Anthropic from "@anthropic-ai/sdk";

// Server-only helper for the iOS app's "tidy" endpoint (src/routes/api/tidy.ts).
// Takes what we already know about a saved video link and returns a short,
// clean title plus a few tags. The API key stays on the server.

export interface TidyInput {
  url: string;
  title?: string;
  author?: string;
  provider?: string;
}

export interface TidyResult {
  title: string;
  tags: string[];
}

const MAX_FIELD = 500;

export function parseTidyInput(body: unknown): TidyInput | null {
  if (!body || typeof body !== "object") return null;
  const b = body as { url?: unknown; title?: unknown; author?: unknown; provider?: unknown };
  if (typeof b.url !== "string" || !/^https?:\/\//i.test(b.url) || b.url.length > 2048) return null;
  const out: TidyInput = { url: b.url };
  for (const key of ["title", "author", "provider"] as const) {
    const v = b[key];
    if (typeof v === "string" && v.trim()) out[key] = v.trim().slice(0, MAX_FIELD);
  }
  return out;
}

export function normalizeTidyResult(raw: unknown): TidyResult | null {
  if (!raw || typeof raw !== "object") return null;
  const r = raw as { title?: unknown; tags?: unknown };
  if (typeof r.title !== "string" || !r.title.trim()) return null;
  const tags = Array.isArray(r.tags)
    ? r.tags
        .filter((t): t is string => typeof t === "string")
        .map((t) => t.trim().toLowerCase().replace(/^#/, "").slice(0, 24))
        .filter(Boolean)
    : [];
  return { title: r.title.trim().slice(0, 80), tags: [...new Set(tags)].slice(0, 3) };
}

const SYSTEM = `You tidy up saved video links for a personal video library.
Given a link and whatever metadata is known, return:
- title: a clean, human title of at most 60 characters. Remove clickbait, emoji spam, hashtags, "| Channel name" suffixes and ALL CAPS. Keep the real subject. If nothing useful is known, describe the link plainly (for example "Video from @handle on X").
- tags: one to three short lowercase topic words (for example "music", "cooking", "tech", "comedy", "sports", "news", "travel"). Prefer common, reusable words so tags group well.
Never invent facts that are not supported by the metadata or the URL.`;

const SCHEMA = {
  type: "object",
  properties: {
    title: { type: "string" },
    tags: { type: "array", items: { type: "string" } },
  },
  required: ["title", "tags"],
  additionalProperties: false,
} as const;

export async function tidyVideo(client: Anthropic, input: TidyInput): Promise<TidyResult | null> {
  const response = await client.beta.messages.create({
    model: "claude-opus-5-5",
    max_tokens: 1024,
    betas: ["server-side-fallback-2026-07-01"],
    fallbacks: "default",
    output_config: { effort: "low", format: { type: "json_schema", schema: SCHEMA } },
    system: SYSTEM,
    messages: [{ role: "user", content: JSON.stringify(input) }],
  });
  if (response.stop_reason === "refusal") return null;
  const text = response.content.find((b) => b.type === "text");
  if (!text || text.type !== "text") return null;
  try {
    return normalizeTidyResult(JSON.parse(text.text));
  } catch {
    return null;
  }
}
