// Japanese text-to-speech for words and example sentences — mirrors flutter_tts in the app.
let voice: SpeechSynthesisVoice | null | undefined;

function pickVoice() {
  if (voice !== undefined) return voice;
  const all = window.speechSynthesis?.getVoices() ?? [];
  if (!all.length) return null; // voices load async; try again next time
  voice = all.find((v) => v.lang === "ja-JP" && /google|kyoko|otoya|haruka/i.test(v.name)) ?? all.find((v) => v.lang.startsWith("ja")) ?? null;
  return voice;
}

export function speak(text: string, rate = 0.9) {
  if (typeof window === "undefined" || !("speechSynthesis" in window) || !text) return false;
  const u = new SpeechSynthesisUtterance(text);
  u.lang = "ja-JP";
  u.rate = rate;
  const v = pickVoice();
  if (v) u.voice = v;
  window.speechSynthesis.cancel();
  window.speechSynthesis.speak(u);
  return true;
}
