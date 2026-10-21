// Saved-words export (CSV, opens in Anki / Sheets) — mirrored in mobile/lib/services/export_service.dart.
import type { Content } from "./content";
import { wordStatus } from "./logic";
import type { SavedWord } from "./store";

const cell = (v: string) => (/[",\n\r]/.test(v) ? `"${v.replace(/"/g, '""')}"` : v);

export function wordsCsv(words: SavedWord[], content: Content | null) {
  const rows = [["word", "reading", "romaji", "meaning", "sentence", "translation", "status", "saved"]];
  for (const w of words) {
    if (w.status === "removed") continue;
    const line = content?.byId[w.clipId]?.lines[w.line];
    const st = w.status === "ignored" ? "ignored" : wordStatus({ status: w.status, card: w.card });
    rows.push([w.word, w.reading, w.romaji, w.gloss, line?.ja ?? "", line?.en ?? "", st, new Date(w.addedAt).toISOString().slice(0, 10)]);
  }
  return rows.map((r) => r.map(cell).join(",")).join("\n");
}

export function downloadText(filename: string, text: string, mime = "text/csv;charset=utf-8") {
  const blob = new Blob(["\ufeff" + text], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
