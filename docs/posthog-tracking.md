# Kizuki product analytics

## Installation and privacy

Official posthog_flutter and posthog-js send to the verified US ingest project. The public write token cannot read reports or configure dashboards. No automatic advertising uploads are enabled. Meta/RevenueCat attribution is unchanged.

Both clients require explicit usage-analytics acceptance before initialization. Acceptance/refusal, last choice time, acceptance time and the notice version are stored separately from cloud learning state on the device. Settings → Usage analytics withdraws consent; blocked actions are not replayed after later acceptance. The web listens for withdrawal in other tabs. Identity is the authenticated Kizuki account ID, not email/name; it resets on account changes. No passwords, credentials, OAuth URL contents, chat/support text, notes, receipts, card details or screen recordings.

## Funnels to save in PostHog

- Acquisition: `screen_viewed` (screen `/`) → `onboarding_step_viewed` → `onboarding_step_completed` (step `streak`) → `screen_viewed` (screen `/founder`) → `paywall_viewed` → `checkout_started` → `checkout_result` (result `done`) → `purchase_account_completed` → `onboarding_completed`.
- Paywall: `paywall_viewed` → `paywall_step_viewed` (step_index `2`) → `plan_selected` → `checkout_started` → `checkout_result`; break down by platform, plan and result. This measures observed store responses, not renewals occurring while the app is closed.
- Activation: `clip_viewed` → `word_card_opened` → `word_saved` → `review_session_started` → `review_answered` → `review_session_completed`.
- Tutor: `ask_opened` → `ask_submitted` → `ask_answer_received`; examine `ask_failed` separately. No conversation text.
- Return usage: `app_resumed`, `screen_viewed`, `study_time_recorded`, `clip_watched`, `review_session_completed`; group by day and identified account.
- Login: `sign_in_started` → `account_signed_in` → `purchase_account_completed`; break down login starts by provider.

Screens are normalized, dynamic clip IDs are sent only in explicit learning events. Screen dwell, tab selection, control type/position (not text), settings, dictionary level/status, bookmarks, welcome-tour steps, player speed/slow loading/failure, and review grade/deck are additional diagnostic events. Generic taps supplement semantic outcomes and must not be treated as purchases or successful answers.

## Reporting filters and verification

Exclude `is_test=true` and `is_simulated=true` from production conversion reports. All web checkout activity is simulated. Native checkout events flag billing simulation. Tests are not customer outcomes.

132 web tests passed. One marked `tracking_test` browser event received HTTP 200 from the actual PostHog ingest endpoint after temporarily bypassing automated-browser detection in the test browser only. The real app retains bot filtering. A navigation aborted another test request; receipt is not dashboard visibility or attribution. Consent/refusal and onboarding progression checked in the actual preview.

Native SDK integration and tests are authored but not compiled or executed here because Flutter is unavailable. Authenticated identity, real purchases and native transmission need the next store build and an app/store test account. Nothing has been published/uploaded in this task. Saved dashboards, retention and store Data safety/App Privacy answers must be configured with account access before release; current retention has not been read.