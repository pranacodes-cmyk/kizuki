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
  setUp(() => Tour.I.reset());

  String id() => Tour.I.step?.id ?? 'none';

  test('the tour covers the whole loop: feed, word card, Explore, Vocab and the first review', () {
    final ids = tourSteps.map((s) => s.id).toList();
    expect(ids, ['hello', 'clip', 'subs', 'tapWord', 'meaning', 'explain', 'askOpen', 'askInfo', 'askClose', 'legend', 'controls', 'swipe', 'explore', 'search', 'vocabTab', 'review', 'reveal', 'grade', 'done']);
    expect(tourSteps.expand((s) => s.screens).toSet(), {'/feed', '/explore', '/vocab', '/review'});
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
    expect(id(), 'explain');
    Tour.I.next();
    expect(id(), 'askOpen');
    Tour.I.emit(TourEvent.askOpened);
    expect(id(), 'askInfo');
    Tour.I.next();
    Tour.I.emit(TourEvent.askClosed);
    expect(id(), 'askClose');
    Tour.I.emit(TourEvent.cardClosed);
    expect(id(), 'legend');
  });

  test('closing the card before Explain skips the card steps', () {
    Tour.I.start();
    Tour.I.goTo(tourIndexOf('meaning'));
    Tour.I.emit(TourEvent.cardClosed);
    expect(id(), 'legend');
  });

  test('route steps move when the learner opens Explore, Vocab and the review', () {
    Tour.I.start();
    Tour.I.goTo(tourIndexOf('explore'));
    Tour.I.route('/vocab');
    expect(id(), 'explore');
    Tour.I.route('/explore');
    expect(id(), 'search');
    Tour.I.next();
    Tour.I.route('/vocab');
    expect(id(), 'review');
    Tour.I.route('/review');
    expect(id(), 'reveal');
    Tour.I.emit(TourEvent.reveal);
    Tour.I.emit(TourEvent.graded);
    expect(id(), 'done');
  });

  test('a missing target jumps over the steps that depend on it', () {
    Tour.I.start();
    Tour.I.goTo(tourIndexOf('tapWord'));
    Tour.I.skipStep();
    expect(id(), 'legend');
    Tour.I.goTo(tourIndexOf('review'));
    Tour.I.skipStep();
    expect(id(), 'done');
  });

  test('tips never cover what they explain', () {
    TourStep s(String id) => tourSteps[tourIndexOf(id)];
    // Word card: both tips sit above the sheet (never over the word), and the explanation is lit whole.
    expect(s('meaning').place, 'top');
    expect([s('explain').target, s('explain').place, s('explain').fullHole], ['card', 'top', true]);
    // Flashcard: the whole card is the target, the tip rests on its empty lower part, the hand below the word.
    expect([s('reveal').target, s('reveal').place, s('reveal').fullHole], ['reviewCard', 'bottom', true]);
    expect(s('reveal').handY! > 0.5, isTrue);
    expect(tourControls.map((c) => c.$1).toList(), ['replay', 'loop', 'speed', 'save', 'display']);
    expect(tourLegend.map((l) => l.$1).toList(), ['new', 'learning', 'known', 'speaking']);
  });

  test('finishing calls onFinish once and stops the tour', () {
    var calls = 0;
    Tour.I.onFinish = () => calls++;
    Tour.I.start();
    Tour.I.goTo(tourIndexOf('done'));
    Tour.I.next();
    expect(Tour.I.running, isFalse);
    Tour.I.finish();
    expect(calls, 1);
  });

  test('text is personal', () {
    expect(tourText(tourSteps.first, name: 'Mohit', minutes: 10), startsWith('Hi Mohit!'));
    expect(tourText(tourSteps.first, name: ' ', minutes: 10), startsWith('Hi!'));
    expect(tourText(tourSteps.last, name: '', minutes: 15), contains('15 minutes a day'));
  });

  Future<(AppState, ValueNotifier<String>)> pumpHost(WidgetTester tester, {required VoidCallback onWord}) async {
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
              const TourAnchor(id: 'player', child: SizedBox(height: 200, width: double.infinity, child: ColoredBox(color: T.stage))),
              TourAnchor(
                id: 'transcript',
                child: Column(children: [
                  TourAnchor(id: 'word', child: TextButton(onPressed: onWord, child: const Text('言葉'))),
                  const SizedBox(height: 200),
                ]),
              ),
            ]),
          ),
          Positioned.fill(child: TourHost(path: path)),
        ]),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    return (app, path);
  }

  testWidgets('overlay: tap steps, a blocked tap outside the spotlight, the word tap, and the Next fallback', (tester) async {
    var wordTaps = 0;
    final (app, _) = await pumpHost(tester, onWord: () {
      wordTaps++;
      Tour.I.emit(TourEvent.word);
    });
    expect(Tour.I.running, isTrue);
    expect(find.text('Hi Mohit! Let me show you how Kizuki works. It takes about a minute.'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(id(), 'clip');
    await tester.tapAt(const Offset(200, 800)); // tap anywhere
    await tester.pump(const Duration(milliseconds: 500));
    expect(id(), 'subs');
    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 600));
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
    await tester.tap(find.text('Got it'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(id(), 'legend', reason: 'legend needs a beat before Got it works');
    await tester.pump(const Duration(milliseconds: tourLegendDelayMs));
    await tester.tap(find.text('Got it'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(id(), 'controls');
    // The controls tip names every player button, drawn like the buttons themselves.
    await tester.pump(const Duration(milliseconds: tourTargetWaitMs + 400));
    for (final (_, label) in tourControls) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Aa'), findsOneWidget);
    expect(find.text('Tap anywhere'), findsNothing);
    expect(app.tutorialFeed, isFalse);
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
