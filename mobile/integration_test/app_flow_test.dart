import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimi/data/tour.dart';
import 'package:mimi/main.dart' as kizuki;
import 'package:mimi/screens/settings.dart';
import 'package:mimi/state/app_state.dart';
import 'package:mimi/widgets/feed_pager.dart';
import 'package:mimi/widgets/feed_preview.dart';
import 'package:mimi/widgets/tour.dart';
import 'package:mimi/widgets/ui.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

/// End-to-end on a real Android emulator (GitHub Actions → .github/scripts/e2e.sh):
/// first launch → onboarding (name step with the real keyboard up) → plan → founder video →
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
    await waitFor(find.byType(TextField), what: 'name field');
    // Open the real soft keyboard: "Build my plan" must stay fully above it (it used to be cut off).
    await tester.tap(find.byType(TextField), warnIfMissed: false);
    await wait(2500);
    // On a real device the soft keyboard owns text input, so type through the field's controller.
    final nameField = tester.widget<TextField>(find.byType(TextField));
    nameField.controller!.text = 'Mohit';
    nameField.onChanged?.call('Mohit');
    await wait(600);
    {
      final view = tester.view;
      final screenH = view.physicalSize.height / view.devicePixelRatio;
      final keyboard = view.viewInsets.bottom / view.devicePixelRatio;
      final build = tester.getRect(find.ancestor(of: find.text('Build my plan'), matching: find.byType(Button3D)).first);
      final skip = tester.getRect(find.ancestor(of: find.text('Skip'), matching: find.byType(Button3D)).first);
      debugPrint('E2E_INFO name step: screen=${screenH.toStringAsFixed(0)} keyboard=${keyboard.toStringAsFixed(0)} build=$build skip=$skip');
      await shot('04a_onboarding_name_keyboard');
      if (keyboard > 0) {
        expect(build.bottom, lessThanOrEqualTo(screenH - keyboard + 1), reason: 'Build my plan is fully above the keyboard');
        expect(skip.bottom, lessThanOrEqualTo(screenH - keyboard + 1), reason: 'Skip is fully above the keyboard');
        expect(build.top, greaterThanOrEqualTo(0));
      }
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await wait(900);
    await shot('04_onboarding_name');
    await tapText('Build my plan', after: 1000);
    await shot('05_building');
    expect(state().profile.reasons, ['work']);
    expect(state().profile.name, 'Mohit');
    expect(state().profile.jlpt, 'N5');

    // ---- Plan → founder → paywall → account ----------------------------------------
    await waitFor(find.text('Continue'), seconds: 40, what: 'plan screen');
    await shot('06_plan');
    await tapText('Continue', after: 1500);
    // The welcome message is the real presenter video (not the fox fallback).
    await waitFor(find.byType(VideoPlayer), seconds: 15, what: 'presenter video');
    await shot('07_founder');
    await wait(4000);
    await shot('07b_founder_playing');
    await tapText('Continue', after: 1200);
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
    await tapText('Maybe later', after: 1500);

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
    expect(find.text('New'), findsWidgets);
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
    await waitFor(find.textContaining('words you know'), what: 'vocab screen');
    await shot('15_vocab');
    await tapText('to review', contains: true, after: 1800);
    await shot('16_review');
    // The whole card is the reveal target (no separate "Show answer" button).
    final reveal = find.textContaining('Tap to reveal');
    if (reveal.evaluate().isNotEmpty) {
      await tester.tap(reveal.first, warnIfMissed: false);
      await wait(1200);
      await waitFor(find.text('DEFINITION'), what: 'flashcard answer');
      expect(find.text('Again'), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);
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
    await tapText('Next');
    await atStep('clip', '22_tour_clip');
    await tapText('Next');
    await atStep('subs', '23_tour_subs');
    await tapText('Next');
    await atStep('tapWord', '24_tour_tap_word');
    await tapAnchor('word');
    await atStep('meaning', '25_tour_meaning');
    await tapAnchor('cardExplain');
    await atStep('explain', '26_tour_explain');
    await tester.tapAt(const Offset(40, 60)); // tap above the card
    await atStep('legend', '27_tour_legend');
    await wait(tourLegendDelayMs);
    await tapText('Got it');
    await atStep('controls', '28_tour_controls');
    await tapText('Next');
    await atStep('swipe', '29_tour_swipe');
    debugPrint('E2E_SWIPE up');
    await atStep('explore', '30_tour_explore');
    await tapAnchor('exploreTab');
    await atStep('search', '31_tour_search');
    await tapText('Next');
    await atStep('vocabTab', '32_tour_vocab_tab');
    await tapAnchor('vocabTab');
    await atStep('review', '33_tour_review');
    await tapAnchor('reviewButton');
    await atStep('reveal', '34_tour_reveal');
    await tapAnchor('reviewCard');
    await atStep('grade', '35_tour_grade');
    await tapText('Good');
    await atStep('done', '36_tour_done');
    await tapText("Let's go!", after: 1200);
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
