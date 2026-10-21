# Mimi — product spec (working name)

Goal: a Japanese listening-immersion app that matches Kiku feature-for-feature and
visual language (dark UI, orange 3D buttons, card grids, mascot moments) but is
simpler to use, more personal, more reliable and better at converting.
Own brand: name "Mimi" (耳 = ear) and an original fox mascot. No Kiku copy, art or brand.

## Clients
- `mobile/` Flutter app — the shipped Android product (APK).
- Root TanStack web app — the interactive prototype rendered in a phone frame.
- Same screens, same copy, same data, same rules in both.

## Content (the core)
- Curated YouTube videos played only through the official embedded player
  (web iframe API / Flutter `youtube_player_iframe`). Never downloaded or re-hosted.
- Each clip = videoId + start/end (8–40 s) + verbatim Japanese lines with timings,
  word tokens (surface, base form, kana reading, romaji, part of speech), English
  line translation, dictionary senses (JMdict), JLPT level, topics, grammar points,
  and a precomputed "explain in context" note + example sentences per word.
- Transcripts are produced by Gemini watching the YouTube URL (Google's own
  sanctioned video-understanding path), tokenised by kuromoji, looked up in JMdict.
- Embeddability verified via YouTube oEmbed before a video ships.
- Personalisation: clips carry topic + level tags; onboarding answers (reasons, level,
  challenges, minutes) drive the For You ranking and the plan.

## Beat-Kiku list (simpler + better)
1. Word card has labelled tabs (Meaning · Explain · Examples · Notes); Explain is instant and offline (precomputed), "Ask Mimi" chat for follow-ups.
2. Word progress is automatic (SRS-driven) — no 6-level manual status menu; one-tap "I know this" / "Ignore".
3. Vocab: one search + 4 simple chips (All · Due · Learning · Known) instead of a 40-chip filter sheet.
4. Quick "Aa" display sheet on the player (furigana / romaji / translation / speed) instead of deep settings.
5. Plan summary actually reflects the user's answers (Kiku shows "15-minute lessons" after the user picks 25).
6. Plan-ready screen previews the real first clips picked for the user.
7. Line controls: replay line, previous/next line, 0.75× speed, loop.
8. Examples tab shows the word in other Mimi clips ("Hear it again") + example sentences.
9. Offline-first: all clip data bundled; progress syncs to the cloud when signed in.
10. Honest, personal founder message (user records the real one; script provided).

## Onboarding flow (mirrors Kiku)
Welcome → Why (multi) → Level → Challenges (multi, benefit ticker) → 2.7× proof →
Where heard → Fluency date slider → Daily minutes slider → Reminder window (+permission)
→ Streak commitment → Building plan (reviews) → Plan ready (personal) → Founder
message (captioned video) → Paywall: try free → reminder → plans → Create account →
Feed + welcome tour.

## Monetisation
Simulated purchases (RevenueCat later). Free tier: 10 clips/day + reviews. Premium:
unlimited clips + Ask Mimi chat. Trial 7 days.
