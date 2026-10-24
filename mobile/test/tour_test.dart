import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimi/data/tour.dart';
import 'package:mimi/state/app_state.dart';
import 'package:mimi/theme/tokens.dart';
import 'package:mimi/widgets/tour.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Welcome tour: the step machine (same rules as src/lib/tour.test.ts) and the overlay.
void main() {
  var closes = 0;
  final went = <String>[];
  setUp(() {
    Tour.I.reset();
    closes = 0;
    went.clear();
    Tour.I.closeSheets = () => closes++;
    Tour.I.go = went.add;
  });

  String id() => Tour.I.step?.id ?? 'none';

  test('a short do-what-I-point tour: word card, Ask Kizuki, swipe, Vocab, first review, back to videos', () {
    final ids = tourSteps.map((s) => s.id).toList();
    expect(ids, ['hello', 'controls', 'tapWord', 'meaning', 'askOpen', 'askInfo', 'legend', 'swipe', 'vocabTab', 'kanaDecks', 'review', 'reveal', 'grade', 'done']);
    expect(tourSteps.length, lessThanOrEqualTo(14));
    expect(tourSteps.expand((s) => s.screens).toSet(), {'/feed', '/explore', '/vocab', '/review'});
    // No step points at the whole transcript, the button row or Explore any more.
    expect(tourSteps.map((s) => s.target).whereType<String>().toSet().intersection({'transcript', 'player', 'exploreTab', 'exploreSearch'}), isEmpty);
    // Every skipTo points at a real step.
    for (final s in tourSteps.where((s) => s.skipTo != null)) {
      expect(tourIndexOf(s.skipTo!), lessThan(tourSteps.length), reason: s.id);
    }
  });

  test('action steps only move on the thing they ask for', () {
    Tour.I.start();
    Tour.I.goTo(tourIndexOf('tapWord'));
    Tour.I.emit(TourEvent.swipe);
    expect(id(), 'tapWord');
    Tour.I.emit(TourEvent.word);
    expect(id(), 'meaning');
    Tour.I.emit(TourEvent.explain);
    expect(id(), 'askOpen');
    Tour.I.emit(TourEvent.askOpened);
    expect(id(), 'askInfo');
    expect(closes, 0);
  });

  test('"Back to the video" closes both cards for the learner and moves on', () {
    Tour.I.start();
    Tour.I.goTo(tourIndexOf('askInfo'));
    expect(tourSteps[tourIndexOf('askInfo')].button, 'Back to the video');
    Tour.I.advance();
    expect(id(), 'legend');
    expect(closes, 1);
    // The closing sheets' own events arrive afterwards and change nothing.
    Tour.I.emit(TourEvent.askClosed);
    Tour.I.emit(TourEvent.cardClosed);
    expect(id(), 'legend');
    expect(closes, 1);
  });

  test('closing a card by hand never gets stuck: it skips the card steps and closes the other card', () {
    for (final step in tourCardSteps) {
      for (final e in [TourEvent.cardClosed, TourEvent.askClosed]) {
        Tour.I.reset();
        closes = 0;
        Tour.I.start();
        Tour.I.goTo(tourIndexOf(step));
        Tour.I.emit(e);
        expect(id(), 'legend', reason: '$step + $e');
        expect(closes, 1, reason: '$step + $e');
      }
    }
  });

  test('route steps move when the learner opens Vocab and the review', () {
    Tour.I.start();
    Tour.I.goTo(tourIndexOf('swipe'));
    Tour.I.emit(TourEvent.swipe);
    expect(id(), 'vocabTab');
    Tour.I.route('/explore');
    expect(id(), 'vocabTab');
    Tour.I.route('/vocab');
    expect(id(), 'kanaDecks');
    Tour.I.advance();
    expect(id(), 'review');
    Tour.I.route('/review');
    expect(id(), 'reveal');
    Tour.I.emit(TourEvent.reveal);
    expect(id(), 'grade');
    Tour.I.emit(TourEvent.graded);
    expect(id(), 'done');
  });

  test('the last button finishes the tour and goes back to the feed', () {
    var calls = 0;
    Tour.I.onFinish = () => calls++;
    Tour.I.start();
    Tour.I.goTo(tourIndexOf('done'));
    expect(tourSteps.last.button, 'Back to videos');
    Tour.I.advance();
    expect(Tour.I.running, isFalse);
    expect(calls, 1);
    expect(went, ['/feed']);
    Tour.I.finish();
    expect(calls, 1);
  });

  test('a missing target jumps over the steps that depend on it', () {
    Tour.I.start();
    Tour.I.goTo(tourIndexOf('tapWord'));
    Tour.I.skipStep();
    expect(id(), 'legend');
    Tour.I.goTo(tourIndexOf('review'));
    Tour.I.advance(); // "Next" on an action step whose target never showed
    expect(id(), 'done');
  });

  test('tips never cover what they explain', () {
    TourStep s(String id) => tourSteps[tourIndexOf(id)];
    // Word card: the whole card stays lit (the meaning is readable), the hand points at the button.
    expect([s('meaning').target, s('meaning').handAt, s('meaning').place, s('meaning').fullHole], ['card', 'cardExplain', 'top', true]);
    expect([s('askOpen').target, s('askOpen').handAt, s('askOpen').place, s('askOpen').fullHole], ['card', 'askButton', 'top', true]);
    // Flashcard: the whole card is the target, the tip rests on its empty lower part, the hand below the word.
    expect([s('reveal').target, s('reveal').place, s('reveal').fullHole], ['reviewCard', 'bottom', true]);
    expect(s('reveal').handY! > 0.5, isTrue);
    // Three plain underline rows, no "green box" talk.
    expect(tourLegend.map((l) => l.$1).toList(), ['new', 'learning', 'known']);
    expect(tourSteps.any((s) => s.text.toLowerCase().contains('green')), isFalse);
    expect(tourSteps.any((s) => (s.hint ?? '').contains('above each card')), isFalse);
  });

  test('text is personal', () {
    expect(tourText(tourSteps.first, name: 'Mohit', minutes: 10), startsWith('Hi Mohit!'));
    expect(tourText(tourSteps.first, name: ' ', minutes: 10), startsWith('Hi!'));
    expect(tourText(tourSteps.last, name: '', minutes: 15), contains('15 minutes a day'));
  });

  Future<(AppState, ValueNotifier<String>)> pumpHost(WidgetTester tester, {required VoidCallback onWord, Widget? scrolledAway}) async {
    SharedPreferences.setMockInitialValues({});
    final app = AppState();
    await app.load();
    app.completeOnboarding();
    app.setProfile((p) => p.name = 'Mohit');
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final path = ValueNotifier('/feed');
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: app,
      child: MaterialApp(
        theme: buildTheme(),
        home: Stack(children: [
          Scaffold(
            body: Column(children: [
              const SizedBox(height: 60),
              const SizedBox(height: 200, width: double.infinity, child: ColoredBox(color: T.stage)),
              SizedBox(
                height: 300,
                child: SingleChildScrollView(
                  child: Column(children: [
                    ?scrolledAway,
                    TourAnchor(id: 'word', child: TextButton(onPressed: onWord, child: const Text('言葉'))),
                    const SizedBox(height: 200),
                  ]),
                ),
              ),
            ]),
          ),
          Positioned.fill(child: TourHost(path: path, go: went.add, closeSheets: () => closes++)),
        ]),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    return (app, path);
  }

  testWidgets('overlay: hello, a blocked tap outside the spotlight, the word tap, the Next fallback and the legend', (tester) async {
    var wordTaps = 0;
    final (app, _) = await pumpHost(tester, onWord: () {
      wordTaps++;
      Tour.I.emit(TourEvent.word);
    });
    expect(Tour.I.running, isTrue);
    expect(find.textContaining('Hi Mohit!'), findsOneWidget);
    await tester.tap(find.text('Show me'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(id(), 'controls');
    await tester.pump(const Duration(milliseconds: tourTargetWaitMs + 400));
    await tester.tap(find.text('Try a word'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(id(), 'tapWord');
    expect(find.text('Tap the highlighted word'), findsOneWidget);

    // Outside the spotlight nothing happens…
    await tester.tapAt(const Offset(30, 820));
    await tester.pump(const Duration(milliseconds: 300));
    expect(id(), 'tapWord');
    // …the highlighted word itself works.
    await tester.tap(find.text('言葉'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(wordTaps, 1);
    expect(id(), 'meaning');

    // No word card in this test: after the wait, "Next" appears and skips the card steps.
    await tester.pump(const Duration(milliseconds: tourTargetWaitMs + 400));
    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(id(), 'legend');
    for (final (_, label, _) in tourLegend) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Got it'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(id(), 'legend', reason: 'legend needs a beat before Got it works');
    await tester.pump(const Duration(milliseconds: tourLegendDelayMs));
    await tester.tap(find.text('Got it'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(id(), 'swipe');
    expect(app.tutorialFeed, isFalse);
  });

  testWidgets('a word scrolled out of its transcript is not spotlit (it used to light the video)', (tester) async {
    await pumpHost(tester, onWord: () {}, scrolledAway: const SizedBox(height: 900));
    Tour.I.goTo(tourIndexOf('tapWord'));
    await tester.pump(const Duration(milliseconds: 600));
    final host = tester.renderObject<RenderBox>(find.byType(TourHost));
    expect(TourAnchor.rectOf('word', host), isNull);
  });

  testWidgets('"Back to the video" closes the cards; the last step goes back to the feed', (tester) async {
    final (app, path) = await pumpHost(tester, onWord: () {});
    Tour.I.goTo(tourIndexOf('askInfo'));
    await tester.pump(const Duration(milliseconds: tourTargetWaitMs + 600));
    // askPanel isn't on screen here, so the tip offers its button after the wait.
    await tester.tap(find.text('Back to the video'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(closes, 1);
    expect(id(), 'legend');

    path.value = '/review';
    Tour.I.goTo(tourIndexOf('done'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Back to videos'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(Tour.I.running, isFalse);
    expect(went, ['/feed']);
    expect(app.tutorialFeed, isTrue);
  });

  testWidgets('overlay hides on other screens and Skip tour remembers it', (tester) async {
    final (app, path) = await pumpHost(tester, onWord: () {});
    expect(find.text('Skip tour'), findsOneWidget);
    path.value = '/profile';
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Skip tour'), findsNothing);
    path.value = '/feed';
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Skip tour'));
    await tester.pump(const Duration(milliseconds: 400)); // debounced save
    expect(Tour.I.running, isFalse);
    expect(app.tutorialFeed, isTrue);
  });
}
