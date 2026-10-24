// Rebuild cached generated shards with editorial exclusions; no AI/media calls.
import fs from "node:fs";
import path from "node:path";
import exclusions from "./excluded-clips.json";

const root = path.resolve(import.meta.dir, "../..");
const source = path.join(root, "public/data");
const manifest = JSON.parse(fs.readFileSync(path.join(source, "content.json"), "utf8"));
const excluded = new Set(Object.keys(exclusions));
const clips = manifest.parts.flatMap((p: string) => JSON.parse(fs.readFileSync(path.join(source, p), "utf8")).clips)
  .filter((c: { id: string }) => !excluded.has(c.id));
for (const dir of ["mobile/assets/data", "public/data"]) {
  const target = path.join(root, dir);
  for (const part of manifest.parts) fs.rmSync(path.join(target, part), { force: true });
  const parts: string[] = [];
  for (let i = 0; i * 300 < clips.length; i++) {
    const part = `content-${i}.json`;
    parts.push(part);
    fs.writeFileSync(path.join(target, part), JSON.stringify({ clips: clips.slice(i * 300, (i + 1) * 300) }));
  }
  fs.writeFileSync(path.join(target, "content.json"), JSON.stringify({ ...manifest, generatedAt: new Date().toISOString().slice(0, 10), parts }));
}
console.log(`Rebuilt both libraries: ${clips.length} clips, excluded ${excluded.size} invalid segment(s).`);