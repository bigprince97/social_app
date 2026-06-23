import "jsr:@supabase/functions-js/edge-runtime.d.ts";

type VersionConfig = {
  label: string;
  env: string;
};

const apiBase = "https://api.scripture.api.bible/v1";

const versions: Record<string, VersionConfig> = {
  niv: { label: "NIV", env: "API_BIBLE_NIV_ID" },
  esv: { label: "ESV", env: "API_BIBLE_ESV_ID" },
  nlt: { label: "NLT", env: "API_BIBLE_NLT_ID" },
  bsb: { label: "BSB", env: "API_BIBLE_BSB_ID" },
  ja_shinkyodo: {
    label: "新共同訳",
    env: "API_BIBLE_JA_SHINKYODO_ID",
  },
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ ok: false, code: "method_not_allowed", message: "Only POST is supported." });
  }

  try {
    const body = await req.json();
    const action = String(body.action ?? "");
    const versionId = String(body.version ?? "");
    const version = versions[versionId];
    if (!version) {
      return json({
        ok: false,
        code: "unsupported_version",
        message: `Unsupported Bible version: ${versionId}`,
      });
    }

    const apiKey = Deno.env.get("API_BIBLE_KEY");
    const bibleId = Deno.env.get(version.env);
    if (!apiKey || !bibleId) {
      return json({
        ok: false,
        code: "missing_api_bible_config",
        message:
          `${version.label} 还没有配置 API.Bible。请在 Supabase Function secrets 中设置 API_BIBLE_KEY 和 ${version.env}。`,
      });
    }

    if (action === "chapter") {
      return await chapter(body, apiKey, bibleId, version);
    }
    if (action === "search") {
      return await search(body, apiKey, bibleId, version);
    }
    return json({
      ok: false,
      code: "unsupported_action",
      message: `Unsupported action: ${action}`,
    });
  } catch (error) {
    return json({
      ok: false,
      code: "function_error",
      message: error instanceof Error ? error.message : String(error),
    });
  }
});

async function chapter(
  body: Record<string, unknown>,
  apiKey: string,
  bibleId: string,
  version: VersionConfig,
): Promise<Response> {
  const book = String(body.book ?? "").toUpperCase();
  const chapterNumber = Number(body.chapter);
  if (!book || !Number.isFinite(chapterNumber)) {
    return json({
      ok: false,
      code: "bad_chapter_request",
      message: "Missing book or chapter.",
    });
  }

  const chapterId = `${book}.${chapterNumber}`;
  const url = new URL(`${apiBase}/bibles/${bibleId}/chapters/${chapterId}`);
  url.searchParams.set("content-type", "text");
  url.searchParams.set("include-notes", "false");
  url.searchParams.set("include-titles", "false");
  url.searchParams.set("include-chapter-numbers", "false");
  url.searchParams.set("include-verse-numbers", "true");
  url.searchParams.set("include-verse-spans", "false");

  const data = await apiFetch(url, apiKey);
  const row = data.data ?? {};
  return json({
    ok: true,
    version: version.label,
    chapterId,
    title: row.reference ?? chapterId,
    text: normalizePassageText(String(row.content ?? "")),
    copyright: row.copyright ?? data.copyright ?? null,
  });
}

async function search(
  body: Record<string, unknown>,
  apiKey: string,
  bibleId: string,
  version: VersionConfig,
): Promise<Response> {
  const query = String(body.query ?? "").trim();
  const limit = clamp(Number(body.limit ?? 40), 1, 50);
  if (!query) {
    return json({ ok: true, version: version.label, results: [] });
  }

  const url = new URL(`${apiBase}/bibles/${bibleId}/search`);
  url.searchParams.set("query", query);
  url.searchParams.set("limit", String(limit));
  url.searchParams.set("sort", "relevance");

  const data = await apiFetch(url, apiKey);
  const verses = Array.isArray(data.data?.verses) ? data.data.verses : [];
  const results = verses.map((verse: Record<string, unknown>) => {
    const parsed = parseVerseId(String(verse.id ?? verse.orgId ?? ""));
    return {
      book: parsed.book,
      chapter: parsed.chapter,
      verse: parsed.verse,
      reference: verse.reference ?? "",
      snippet: cleanupText(String(verse.text ?? "")),
    };
  }).filter((row: { book: string | null; chapter: number | null }) =>
    row.book && row.chapter
  );

  return json({
    ok: true,
    version: version.label,
    results,
    total: data.data?.total ?? results.length,
  });
}

async function apiFetch(url: URL, apiKey: string): Promise<Record<string, any>> {
  const response = await fetch(url, {
    headers: {
      "api-key": apiKey,
      "accept": "application/json",
    },
  });
  const text = await response.text();
  let data: Record<string, any> = {};
  try {
    data = text ? JSON.parse(text) : {};
  } catch (_) {
    data = { raw: text };
  }
  if (!response.ok) {
    const message = data.message ?? data.error ?? `API.Bible returned ${response.status}`;
    throw new Error(String(message));
  }
  return data;
}

function parseVerseId(id: string): {
  book: string | null;
  chapter: number | null;
  verse: number | null;
} {
  const parts = id.split(".");
  if (parts.length < 2) {
    return { book: null, chapter: null, verse: null };
  }
  return {
    book: parts[0] || null,
    chapter: Number.isFinite(Number(parts[1])) ? Number(parts[1]) : null,
    verse: Number.isFinite(Number(parts[2])) ? Number(parts[2]) : null,
  };
}

function normalizePassageText(text: string): string {
  return cleanupText(text)
    .replace(/\[(\d{1,3})\]/g, "\n$1 ")
    .replace(/^\s+/, "")
    .replace(/\n{2,}/g, "\n")
    .trim();
}

function cleanupText(text: string): string {
  return decodeHtml(text)
    .replace(/<[^>]*>/g, " ")
    .replace(/\r/g, "\n")
    .replace(/\u00a0/g, " ")
    .replace(/[ \t]+/g, " ")
    .replace(/[ \t]*\n[ \t]*/g, "\n")
    .trim();
}

function decodeHtml(text: string): string {
  return text
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, "\"")
    .replace(/&#39;/g, "'");
}

function clamp(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) return min;
  return Math.max(min, Math.min(max, Math.floor(value)));
}

function json(payload: Record<string, unknown>): Response {
  return new Response(JSON.stringify(payload), {
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Connection": "keep-alive",
    },
  });
}
