import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimi/main.dart' as kizuki;
import 'package:mimi/state/app_state.dart';
import 'package:provider/provider.dart';

/// End-to-end on a real Android emulator (GitHub Actions → .github/scripts/e2e.sh):
/// first launch → onboarding → plan → founder → paywall → account → feed with the real
/// YouTube player → tap a word → save it → Vocab → Review → Explore → Profile → Settings.
///
/// Each `E2E_SHOT <name>` log line makes the host script capture the real device screen
/// (including the YouTube player, which Flutter's own screenshots can't see).
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
    // On a real device the soft keyboard owns text input, so type through the field's controller.
    final nameField = tester.widget<TextField>(find.byType(TextField));
    nameField.controller!.text = 'Mohit';
    nameField.onChanged?.call('Mohit');
    await wait(400);
    FocusManager.instance.primaryFocus?.unfocus();
    await wait(600);
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
    await shot('07_founder');
    await tapText('Continue', after: 1200);
    await shot('08_trial');
    await tapText(r'Try for $0.00', after: 1800);
    await tapText('Continue for free', after: 1200);
    await shot('09_trial_plans');
    await tapText('Not now', after: 1200);
    await shot('10_account');
    await tapText('Maybe later', after: 1500);

    // ---- Feed with the real YouTube player -----------------------------------------
    await waitFor(find.text('Skip tour'), seconds: 40, what: 'welcome tour on the feed');
    await shot('11_feed_tour');
    await tapText('Skip tour', after: 1500);
    expect(state().tutorialFeed, isTrue);
    await wait(9000); // let the embedded player load the first clip
    await shot('12_feed_player');

    // Tap the first real word of the first line.
    Finder? word;
    for (var i = 0; i < 8 && word == null; i++) {
      final f = find.descendant(of: find.byKey(ValueKey('word-0-$i')), matching: find.byType(GestureDetector));
      if (f.evaluate().isNotEmpty) word = f.first;
    }
    expect(word, isNotNull, reason: 'the first transcript line has a tappable word');
    await tester.tap(word!, warnIfMissed: false);
    await waitFor(find.text('Save word'), what: 'word card');
    await shot('13_word_card');
    await tapText('Save word', after: 1200);
    expect(state().words, isNotEmpty);
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
    final reveal = find.textContaining('Show');
    if (reveal.evaluate().isNotEmpty) {
      await tester.tap(reveal.first, warnIfMissed: false);
      await wait(1200);
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
    debugPrint('E2E_DONE');
  }, timeout: const Timeout(Duration(minutes: 12)));
}
