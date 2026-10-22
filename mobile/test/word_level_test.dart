import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimi/logic/logic.dart';
import 'package:mimi/state/app_state.dart';
import 'package:mimi/theme/tokens.dart';
import 'package:mimi/widgets/word_level.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kiku-style word levels: one button shows the level, its sheet changes it (and the next review).
void main() {
  Future<(AppState, String)> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final app = AppState();
    await app.load();
    const input = WordInput(base: '食べる', word: '食べる', reading: 'たべる', romaji: 'taberu', gloss: 'to eat', pos: 'verb', surface: '食べ', clipId: 'c', line: 0, idx: 0);
    app.saveWord(input);
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: app,
      child: MaterialApp(theme: buildTheme(), home: Scaffold(body: Center(child: LevelPill(wordKey: input.key, word: input.word)))),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    return (app, input.key);
  }

  Future<void> pick(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const ValueKey('level-pill')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('How well do you know', findRichText: true), findsOneWidget);
    await tester.tap(find.text(label).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('a saved word starts at 1 New; picking Familiar moves its review 3 days out', (tester) async {
    final (app, key) = await pump(tester);
    expect(find.text('New'), findsOneWidget);
    final before = DateTime.now().millisecondsSinceEpoch;
    await pick(tester, 'Familiar');
    final w = app.words[key]!;
    expect(wordLevel(status: w.status, card: w.card), 3);
    expect((w.card.due - before) / 86400000, closeTo(3, 0.01));
    expect(find.text('Familiar'), findsOneWidget, reason: 'the pill shows the new level');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Known and Ignored take the word out of reviews', (tester) async {
    final (app, key) = await pump(tester);
    await pick(tester, 'Known');
    expect(app.words[key]!.status, 'known');
    await pick(tester, 'Ignored');
    expect(app.words[key]!.status, 'ignored');
    expect(app.dueKeys, isEmpty);
    await tester.pump(const Duration(seconds: 1));
  });
}
