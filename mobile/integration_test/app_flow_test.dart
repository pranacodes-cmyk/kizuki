import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimi/data/tour.dart';
import 'package:mimi/main.dart' as kizuki;
import 'package:mimi/screens/founder.dart';
import 'package:mimi/screens/settings.dart';
import 'package:mimi/screens/trial.dart';
import 'package:mimi/state/app_state.dart';
import 'package:mimi/widgets/feed_pager.dart';
import 'package:mimi/widgets/feed_preview.dart';
import 'package:mimi/widgets/tour.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

/// End-to-end on a real Android emulator (GitHub Actions → .github/scripts/e2e.sh):
/// first launch → nine-step onboarding → plan → founder video →
/// paywall with the feed demo → account → feed with the real YouTube player → tap a word →
/// save it → Vocab → Review → Explore → Profile → Settings → replay the welcome tour and walk
/// all of it (feed, word card, Explore, Vocab, first review) → real finger swipes on the feed.
///
/// Each `E2E_SHOT <name>` log line makes the host script capture the real device screen
/// (including the YouTube player, which Flutter's own screenshots can't see). Each
/// `E2E_SWIPE <kind>` line makes it swipe the real screen with `adb shell input swipe`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('first launch → onboarding → feed → saved word → review', (tester) async {
    Future<void> wait(int ms) => tester.pump(Duration(milliseconds: ms));

    Future<void> shot(String name) async {
      await wait(700);
      debugPrint('E2E_SHOT $name');
      await wait(1800); // host captures the screen
    }

    Future<void> waitFor(Finder f, {int seconds = 25, String? what}) async {
      final end = DateTime.now().add(Duration(seconds: seconds));
      while (DateTime.now().isBefore(end)) {
        await wait(250);
        if (f.evaluate().isNotEmpty) return;
      }
      await shot('timeout_${(what ?? 'step').replaceAll(RegExp(r'[^a-z0-9]+'), '_')}');
      fail('Timed out after ${seconds}s waiting for ${what ?? f.describeMatch(Plurality.one)}');
    }

    Future<void> tapText(String text, {int after = 700, bool contains = false}) async {
      final f = contains ? find.textContaining(text) : find.text(text);
      await waitFor(f, what: text);
      await tester.ensureVisible(f.last);
      await wait(200);
      await tester.tap(f.last, warnIfMissed: false);
      await wait(after);
    }

    Future<void> waitUntil(bool Function() ok, {int seconds = 20, required String what}) async {
      final end = DateTime.now().add(Duration(seconds: seconds));
      while (DateTime.now().isBefore(end)) {
        await wait(200);
        if (ok()) return;
      }
      await shot('timeout_${what.replaceAll(RegExp(r'[^a-z0-9]+'), '_')}');
      fail('Timed out after ${seconds}s waiting for $what');
    }

    /// The active clip's "0:03 / 0:14" label (shows whether YouTube is actually playing).
    String playerTime() {
      final labels = find.byWidgetPredicate((w) => w is Text && RegExp(r'^\d+:\d\d / \d+:\d\d$').hasMatch(w.data ?? ''));
      return labels.evaluate().map((e) => (e.widget as Text).data).join(', ');
    }

    BuildContext ctx() => tester.element(find.byType(Navigator).first);
    AppState state() => Provider.of<AppState>(ctx(), listen: false);

    // ---- First launch -------------------------------------------------------------
    await kizuki.startApp();
    await waitFor(find.text('Get started'), seconds: 40, what: 'welcome screen');
    // A fresh install asks about usage analytics first; it covers the welcome screen.
    await waitFor(find.text('No thanks'), seconds: 20, what: 'analytics choice');
    await shot('00_analytics_choice');
    await tapText('No thanks', after: 900);
    expect(find.text('Allow analytics'), findsNothing);
    await shot('01_welcome');

    // ---- Onboarding (same answers as the widget test) ------------------------------
    await tapText('Get started', after: 900);
    await shot('02_onboarding_reasons');
    await tapText('Work', after: 300);
    await tapText('Continue', after: 900);
    await tapText("I'm new to Japanese", after: 1200);
    await tapText('Understanding natives', after: 300);
    await tapText('Continue', after: 900);
    await shot('03_onboarding_method');
    await tapText('Continue', after: 1500);
    await tapText('YouTube', after: 1200);
    await tapText('Continue', after: 900);
    await tapText("I'm committed", after: 900);
    await tapText('Evening', after: 300);
    await tapText('Remind me in the evening', after: 1500);
    await waitFor(find.text('Make a promise to yourself'), seconds: 40, what: 'streak goal step');
    await tapText('30-day streak', after: 300);
    await tapText('Commit to 30 days', after: 900);
    await shot('05_building');
    expect(state().profile.reasons, ['work']);
    expect(state().profile.jlpt, 'N5');

    // ---- Plan → founder (remote switch) → paywall → account ------------------------
    await waitFor(find.text('Continue'), seconds: 40, what: 'plan screen');
    await shot('06_plan');
    await tapText('Continue', after: 1500);
    // The founder screen can be switched off remotely; both paths meet at the trial.
    final founder = find.byType(FounderScreen), trial = find.byType(TrialScreen);
    await waitFor(find.byWidgetPredicate((w) => w is FounderScreen || w is TrialScreen), seconds: 20, what: 'founder or trial');
    if (founder.evaluate().isNotEmpty) {
      // The welcome message is the real presenter video (not the fox fallback).
      await waitFor(find.byType(VideoPlayer), seconds: 15, what: 'presenter video');
      await shot('07_founder');
      await wait(4000);
      await shot('07b_founder_playing');
      await tapText('Continue', after: 1200);
    } else {
      debugPrint('E2E_INFO founder screen switched off remotely: plan went straight to trial');
    }
    await waitFor(trial, seconds: 20, what: 'trial');
    await shot('08_trial');
    // The phone mockup plays the personal feed demo (it used to be empty).
    await wait(3500);
    await shot('08b_trial_demo');
    final previewPager = find.descendant(of: find.byType(FeedPreview), matching: find.byType(PageView));
    expect(previewPager, findsOneWidget);
    await tester.fling(previewPager, const Offset(0, -200), 1200);
    await wait(1500);
    await shot('08c_trial_demo');
    await tester.fling(previewPager, const Offset(0, 200), 1200);
    await wait(1000);
    await tapText(r'Try for $0.00', after: 1800);
    await tapText('Continue for free', after: 1200);
    await shot('09_trial_plans');
    await tapText('Start my free week', after: 1800);
    expect(state().premium.active, isTrue);
    await shot('10_account');
    expect(state().purchaseAccountPending, isTrue);
    expect(find.text('Maybe later'), findsNothing);
    expect(find.byKey(const ValueKey('account-google')), findsOneWidget);
    // Signed-out feed fixture with the simulated (test-build) entitlement kept active: the
    // checkout gate above is verified, not bypassed by UI. A real authenticated checkout
    // test requires an approved test account.
    state().confirmPurchaseAccount();
    state().completeOnboarding();
    GoRouter.of(ctx()).go('/feed');
    await wait(1500);

    // ---- Feed with the real YouTube player -----------------------------------------
    await waitFor(find.text('Skip tour'), seconds: 40, what: 'welcome tour on the feed');
    await shot('11_feed_tour');
    await tapText('Skip tour', after: 1500);
    expect(state().tutorialFeed, isTrue);
    await wait(9000); // let the embedded player load the first clip
    await shot('12_feed_player');
    debugPrint('E2E_INFO first clip after 9s: ${playerTime()}');

    // Tap the first real word of the first line.
    Finder? word;
    for (var i = 0; i < 8 && word == null; i++) {
      final f = find.descendant(of: find.byKey(ValueKey('word-0-$i')), matching: find.byType(GestureDetector));
      if (f.evaluate().isNotEmpty) word = f.first;
    }
    expect(word, isNotNull, reason: 'the first transcript line has a tappable word');
    await tester.tap(word!, warnIfMissed: false);
    await waitFor(find.text('Examples'), what: 'word card');
    await wait(1200);
    await shot('13_word_card');
    // Auto-save is on by default, so the tap usually saved the word already; otherwise save it.
    if (find.text('Save word').evaluate().isNotEmpty) await tapText('Save word', after: 1200);
    expect(state().words, isNotEmpty);
    // The saved word shows its level button (Kiku-style badge), starting at 1 · New.
    expect(find.byKey(const ValueKey('level-pill')), findsOneWidget);
    expect(find.text('Learning'), findsWidgets);
    await shot('14_word_saved');

    // Ask Kizuki from the word card (signed out → it offers a free account first).
    await tapText('Explain', after: 800);
    await tapText('Still curious? Ask Kizuki', after: 1500);
    await waitFor(find.byKey(const ValueKey('ask-signup')), what: 'ask kizuki sign-up prompt');
    await shot('14b_ask_kizuki');
    await tester.tapAt(const Offset(40, 60)); // dismiss the ask sheet
    await wait(1200);
    await tester.tapAt(const Offset(40, 60)); // dismiss the sheet
    await wait(1200);

    // ---- Vocab → Review --------------------------------------------------------------
    await tester.tap(find.byKey(const ValueKey('tab-Vocab')), warnIfMissed: false);
    await waitFor(find.text('Words you know'), what: 'vocab screen');
    await shot('15_vocab');
    await tapText('to review', contains: true, after: 1800);
    await shot('16_review');
    // The whole card is the reveal target (no separate "Show answer" button).
    final reveal = find.textContaining('Tap to reveal');
    if (reveal.evaluate().isNotEmpty) {
      await tester.tap(reveal.first, warnIfMissed: false);
      await wait(1200);
      await waitFor(find.text('DEFINITION'), what: 'flashcard answer');
      expect(find.text('Forgot'), findsOneWidget);
      expect(find.text('Remembered'), findsOneWidget);
      await shot('17_review_answer');
    }

    // ---- Explore, Profile, Settings ---------------------------------------------------
    GoRouter.of(ctx()).go('/explore');
    await wait(2500);
    await shot('18_explore');
    GoRouter.of(ctx()).go('/profile');
    await wait(2000);
    await shot('19_profile');
    GoRouter.of(ctx()).push('/settings');
    await wait(2000);
    await shot('20_settings');

    // ---- Replay the welcome tour and walk all of it ----------------------------------
    String step() => Tour.I.step?.id ?? 'none';
    Finder anchor(String id) => find.byWidgetPredicate((w) => w is TourAnchor && w.id == id && w.enabled);
    Future<void> atStep(String id, String name) async {
      await waitUntil(() => step() == id, what: 'tour step $id (now ${step()})');
      await wait(1400); // spotlight measured + bubble in
      await shot(name);
    }

    Future<void> tapAnchor(String id) async {
      await waitFor(anchor(id), what: 'tour target $id');
      await tester.tap(anchor(id).last, warnIfMissed: false);
      await wait(900);
    }

    // Real finger swipes (adb) must reach the app, like a person's.
    binding.shouldPropagateDevicePointerEvents = true;
    // The settings list is long: scroll to the row first (it isn't built until it's near).
    final settingsList = find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Replay the welcome tour'), 500, scrollable: settingsList);
    await wait(600);
    await tapText('Replay the welcome tour', after: 2500);
    await atStep('hello', '21_tour_hello');
    expect(find.textContaining('Hi Mohit!'), findsOneWidget);
    await tapText('Show me');
    await atStep('controls', '21b_tour_controls');
    await tapText('Try a word');
    await atStep('tapWord', '22_tour_tap_word');
    await tapAnchor('word');
    await atStep('meaning', '23_tour_meaning');
    await tapAnchor('cardExplain');
    await atStep('askOpen', '24_tour_explain');
    await tapAnchor('askButton');
    await atStep('askInfo', '25_tour_ask');
    expect(find.text('EXAMPLE · NO QUESTION SENT'), findsOneWidget);
    // The tour closes Ask Kizuki and the word card itself.
    await tapText('Back to the video');
    await atStep('legend', '26_tour_legend');
    await wait(tourLegendDelayMs);
    await tapText('Got it');
    await atStep('swipe', '27_tour_swipe');
    debugPrint('E2E_SWIPE up');
    await atStep('vocabTab', '28_tour_vocab_tab');
    await tapAnchor('vocabTab');
    await atStep('kanaDecks', '28b_tour_kana');
    await tapText('Got it');
    await atStep('review', '29_tour_review');
    await tapAnchor('reviewButton');
    await atStep('reveal', '30_tour_reveal');
    await tapAnchor('reviewCard');
    await atStep('grade', '31_tour_grade');
    await tapText('Remembered');
    await atStep('done', '32_tour_done');
    await tapText('Back to videos', after: 1500);
    expect(Tour.I.running, isFalse);
    expect(state().tutorialFeed, isTrue);

    // ---- Feed: real swipes, one clip each, and no wobble while the subtitles run -------
    GoRouter.of(ctx()).go('/feed');
    await wait(6000);
    final pager = find.descendant(of: find.byType(FeedPager), matching: find.byType(PageView));
    await waitFor(pager, what: 'feed pager');
    PageController pages() => tester.widget<PageView>(pager.first).controller!;
    int page() => pages().page!.round();
    bool settled(int p) {
      final pos = pages().position;
      return !pos.isScrollingNotifier.value && (pos.pixels - p * pos.viewportDimension).abs() < 1;
    }

    Future<void> swipe(String kind, int expectPage, String name) async {
      debugPrint('E2E_SWIPE $kind');
      await wait(1500);
      await waitUntil(() => settled(expectPage), seconds: 10, what: 'feed page $expectPage after a $kind swipe (now ${pages().page})');
      await wait(1200);
      await shot(name);
    }

    final start = page();
    debugPrint('E2E_INFO feed before swipes: page $start, player ${playerTime()}');
    await shot('37_feed_before_swipes');
    // Up on the subtitles, five times: five new clips, never two at once.
    for (var i = 1; i <= 5; i++) {
      await swipe('up', start + i, '38_swipe_up_$i');
    }
    await swipe('down', start + 4, '39_swipe_down');
    await swipe('short', start + 4, '40_swipe_short_springs_back');
    // The host's adb input command emits sparse event samples on the software
    // emulator (a 60ms/140ms gesture arrives with no usable release velocity).
    // Inject a measured quick gesture through the device test; the five full
    // swipes, reverse swipe and short slow swipe above remain real adb gestures.
    await tester.fling(pager.first, const Offset(0, -80), 1500);
    await waitUntil(() => settled(start + 5), seconds: 10, what: 'quick flick settles one clip ahead');
    await shot('41_swipe_quick_flick');

    // Wobble check: while the clip plays and the subtitles move on, the page stays put.
    final here = page();
    final h0 = pages().position.viewportDimension;
    final player = anchor('player');
    final top0 = player.evaluate().isEmpty ? null : tester.getRect(player.first).top;
    var worst = 0.0;
    for (var i = 0; i < 40; i++) {
      await wait(250);
      worst = [worst, (pages().position.pixels - here * h0).abs(), if (top0 != null && player.evaluate().isNotEmpty) (tester.getRect(player.first).top - top0).abs()].reduce((a, b) => a > b ? a : b);
    }
    debugPrint('E2E_INFO feed wobble over 10s: ${worst.toStringAsFixed(2)}px; player ${playerTime()}');
    expect(worst, lessThan(1.0), reason: 'the feed must not move up and down while subtitles play');
    await shot('42_feed_after_10s');
    binding.shouldPropagateDevicePointerEvents = false;
    debugPrint('E2E_DONE');
  }, timeout: const Timeout(Duration(minutes: 20)));
}
