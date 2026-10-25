// @vitest-environment node
// Server clip packs: download → verify → use from the next load; the bundle is always the
// fallback. Mirrors mobile/test/content_pack_test.dart.
import { createHash } from "node:crypto";
import { gzipSync } from "node:zlib";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { checkPack, storedPack, syncContentPack } from "./content-pack";

const sha = (s: string) => createHash("sha256").update(s).digest("hex");
const size = (s: string) => Buffer.byteLength(s);

const base = "https://cdn.example.com/storage/v1/object/public/content";
const manifestUrl = `${base}/packs/v2.json`;
const videos = { v1: { title: "Talk", channel: "Ch", channelUrl: "https://youtube.com/@ch" } };
const clip = {
  id: "v1-0", videoId: "v1", title: "Hi", level: "N5", start: 0, end: 4.5, topics: ["daily"], grammar: [], quality: 4,
  lines: [{ start: 0, end: 2, en: "Hi", words: [{ s: "猫", r: "ねこ", t0: 0, t1: 1, d: "1" }] }],
};
const part = JSON.stringify({ clips: [clip] });
const dict = JSON.stringify({ "1": { w: "猫", r: "ねこ", j: 5, c: true, m: [{ pos: ["n"], g: "cat" }], ex: [] } });
const packIndex = JSON.stringify({ version: 2, generatedAt: "2026-10-25", videos, parts: ["content-0.json"], starter: ["v1-0"] });
const notes = JSON.stringify({ "v1-0": { w: { "0.0": { m: "cat", n: "A pet." } }, l: {} } });
const packFiles: Record<string, string> = { "content.json": packIndex, "content-0.json": part, "dict.json": dict, "notes-0.json": notes };

const manifestOf = (files: Record<string, string>) => JSON.stringify({
  format: 1, version: 2,
  files: Object.entries(files).map(([name, text]) => ({ name, sha256: sha(text), bytes: size(text) })),
  notes: ["notes-0.json"],
});
const row = (o: { enabled?: boolean; version?: number | null; url?: string | null } = {}) => ({
  updates_enabled: o.enabled ?? true, pack_version: o.version === undefined ? 2 : o.version, pack_url: o.url === undefined ? manifestUrl : o.url,
});

/** Fake backend + storage. `fetched` collects the checksums of downloaded files. */
function server(settings: object, files: Record<string, string>, opts: { fetched?: string[]; corrupt?: string } = {}) {
  const byHash = Object.fromEntries(Object.values(files).map((t) => [sha(t), t]));
  return vi.fn(async (input: RequestInfo | URL) => {
    const u = String(input);
    if (u.includes("/rest/v1/content_settings")) return new Response(JSON.stringify([settings]));
    if (u === manifestUrl) return new Response(manifestOf(files));
    const m = /\/content\/objects\/([0-9a-f]{64})\.json\.gz$/.exec(new URL(u).pathname);
    const text = m ? byHash[m[1]!] : undefined;
    if (!m || text === undefined) return new Response("missing", { status: 404 });
    opts.fetched?.push(m[1]!);
    return new Response(gzipSync(Buffer.from(text === opts.corrupt ? `${text} ` : text)));
  });
}

describe("server content packs (web)", () => {
  beforeEach(() => {
    const store = new Map<string, string>();
    vi.stubGlobal("localStorage", {
      getItem: (k: string) => store.get(k) ?? null,
      setItem: (k: string, v: string) => void store.set(k, v),
      removeItem: (k: string) => void store.delete(k),
    });
  });
  afterEach(() => vi.unstubAllGlobals());

  it("a newer pack is verified, then used from the next load", async () => {
    vi.stubGlobal("fetch", server(row(), packFiles));
    expect(storedPack(1)).toBe(null);
    expect(await syncContentPack(1)).toBe("activated");
    const p = storedPack(1)!;
    expect(p.version).toBe(2);
    expect(await checkPack(p)).toBe(null);
    expect(await syncContentPack(1)).toBe("keep");
    // A later deploy that bundles the same library version ignores the download.
    expect(storedPack(2)).toBe(null);
  });

  it("the server off switch or a cleared link returns to the bundle", async () => {
    vi.stubGlobal("fetch", server(row(), packFiles));
    expect(await syncContentPack(1)).toBe("activated");
    vi.stubGlobal("fetch", server(row({ enabled: false }), packFiles));
    expect(await syncContentPack(1)).toBe("bundled");
    expect(storedPack(1)).toBe(null);
    vi.stubGlobal("fetch", server(row({ url: null }), packFiles));
    expect(await syncContentPack(1)).toBe("bundled");
  });

  it("a pack not newer than the bundle is never downloaded", async () => {
    const fetched: string[] = [];
    vi.stubGlobal("fetch", server(row({ version: 2 }), packFiles, { fetched }));
    expect(await syncContentPack(2)).toBe("bundled");
    expect(fetched).toEqual([]);
  });

  it("a corrupted download is never used", async () => {
    vi.stubGlobal("fetch", server(row(), packFiles, { corrupt: notes }));
    expect(await syncContentPack(1)).toBe("failed:checksum");
    expect(storedPack(1)).toBe(null);
  });

  it("a pack whose clips the app cannot show is rejected as a whole", async () => {
    const badPart = JSON.stringify({ clips: [{ ...clip, videoId: "unknown" }] });
    vi.stubGlobal("fetch", server(row(), { ...packFiles, "content-0.json": badPart }));
    expect(await syncContentPack(1)).toBe("failed:video");
    expect(storedPack(1)).toBe(null);
  });

  it("offline keeps whatever the device already uses", async () => {
    vi.stubGlobal("fetch", server(row(), packFiles));
    expect(await syncContentPack(1)).toBe("activated");
    vi.stubGlobal("fetch", vi.fn(async () => { throw new TypeError("offline"); }));
    expect(await syncContentPack(1)).toBe("offline");
    expect(storedPack(1)?.version).toBe(2);
  });
});
