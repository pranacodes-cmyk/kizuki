# Kizuki learning widgets — Android + iOS

## Reference confirmed
The downloaded Moji Reel shows an iPhone lock-screen widget: a large kanji beside its reading, English meaning and a short example. The video shows different words at different times. Kizuki currently has no native widgets.

## What to build

### 1. Real native widgets, not just an app preview
- **Android home screen:** compact word widget and a wider word + review widget.
- **iPhone home screen:** small and medium widgets, plus a larger learning widget where the layout remains readable.
- **iPhone lock screen:** a rectangular kanji/word widget inspired by the reference, and a compact review-count option.
- Android lock-screen widget availability varies by OS/device; do not promise universal support or add a fake lock-screen overlay.

### 2. Original Kizuki design
- Keep Kizuki’s AMOLED black, warm orange accents, readable Japanese typography and own fox branding. Do not copy Moji’s assets or footage.
- Make the Japanese word the focal point. Reading and meaning remain legible at actual widget sizes.
- Home-screen widgets include a restrained review/streak section where space allows; lock-screen widgets stay uncluttered.
- Support system text sizing, narrow widgets and iOS’s tinted-widget appearance.
- Aim for a beautiful, shareable result; virality is not guaranteed.

### 3. Useful learning, beyond a random kanji
- Rotate a small offline collection of level-appropriate words drawn from Kizuki’s existing content.
- Offer an explicit option to use saved learning words; prioritize words awaiting review without changing their review schedules.
- Show reading and meaning, with a short example only when verified example content exists.
- Tapping the word opens its learning destination in Kizuki; tapping review opens the existing review flow. Existing account and Premium gates still apply.
- Use OS-scheduled refreshes and immediate refresh after relevant app changes. Neither platform guarantees exact two-hour updates.

### 4. Widget controls in the app
- Add a **Widgets** entry in Settings, implemented in Flutter first and then mirrored in the web phone preview.
- Provide matching previews, word-source selection and reading/meaning visibility controls.
- Native addition uses the platform’s supported widget picker or installation instructions; the web version simulates the result and never claims to install a system widget.
- Default lock-screen content avoids account details. Saved-word sharing is opt-in, and shared snapshots are cleared/replaced on sign-out, account change, reset and deletion.

## Technical implementation
- Keep selection/access rules in the existing mirrored Dart/TypeScript logic files, with matching concrete tests.
- Publish a compact offline widget snapshot from Flutter; native widgets do not fetch private backend data or run video players.
- Android uses an app-widget provider and native launcher layouts with safe click intents.
- iOS uses a WidgetKit extension, shared App Group storage and widget URLs, embedded in the existing Runner app.
- Add the iOS extension target, App Group entitlements and matching signing profiles to the release setup. Use available Apple account automation first; ask for a necessary account action only if access prevents automation. Never ship entitlements against an incompatible profile.
- Preserve existing authentication deep links, purchase gates and release signing keys.
- Record widget architecture in AGENTS.md; define any additional appearance tokens centrally and mirror them.

## Verification and delivery
- Run mirrored selection/privacy/deep-link tests, existing relevant tests and Flutter checks.
- Verify Android widget rendering, resizing, refresh and tap destinations in the emulator release checks.
- Verify the signed iOS extension builds with its App Group/profile and inspect home/lock-screen layouts on an available simulator/device. Report any unavailable native checks explicitly.
- Check the web controls and previews at phone sizes; they are not evidence that native widgets work.
- Return the downloaded reference and summarize implemented features, checks and any Apple-signing blockers. Store uploads and public releases remain separate actions unless requested.