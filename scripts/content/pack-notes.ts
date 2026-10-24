// Re-export existing notes without rebuilding transcripts or requiring the source dictionary.
import fs from "node:fs";
import path from "node:path";
import { runtimeNotes } from "./runtime-notes";

const root = path.resolve(import.meta.dir, "../..");
const mobile = path.join(root, "mobile/assets/data");
const index = JSON.parse(fs.readFileSync(path.join(mobile, "content.json"), "utf8"));
const clips = index.parts.flatMap((part: string) => JSON.parse(fs.readFileSync(path.join(mobile, part), "utf8")).clips);
let before = 0, after = 0;
for (const clip of clips) {
  const existing = path.join(mobile, "explain", `${clip.id}.json`);
  if (!fs.existsSync(existing)) continue;
  const old = fs.readFileSync(existing, "utf8");
  const source = JSON.parse(fs.readFileSync(path.join(import.meta.dir, "explain", `${clip.id}.json`), "utf8"));
  const current = JSON.parse(old);
  if (JSON.stringify(current.w) !== JSON.stringify(source.w) || JSON.stringify(current.l) !== JSON.stringify(source.l)) {
    throw new Error(`Source differs from shipped notes: ${clip.id}`);
  }
  const packed = runtimeNotes(source);
  before += Buffer.byteLength(old);
  after += Buffer.byteLength(packed);
  // Flutter first, then web; all words and line explanations stay identical.
  fs.writeFileSync(existing, packed);
  fs.writeFileSync(path.join(root, "public/data/explain", `${clip.id}.json`), packed);
}
console.log(JSON.stringify({ files: clips.length, before, after, savedPerClient: before - after }));