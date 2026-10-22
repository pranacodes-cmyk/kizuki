import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimi/data/content.dart';
import 'package:mimi/screens/review.dart';
import 'package:mimi/state/app_state.dart';
import 'package:mimi/theme/tokens.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Kiku-style flashcard: the whole card reveals the answer (no separate "Show answer"),
/// the back never says the same meaning twice, and the grade buttons only appear once revealed.
void main() {
  late Content content;
  setUpAll(() {
    final index = File('assets/data/content.json').readAsStringSync();
    final parts = [for (final p in ((jsonDecode(index) as Map<String, dynamic>)['parts'] as List? ?? const []).cast<String>()) File('assets/data/$p').readAsStringSync()];
    content = Content.fromJson(index, File('assets/data/dict.json').readAsStringSync(), parts);
  });

  // 毎日: dictionary sense 1 is "every day; daily" — the case from the phone screenshot.
  String mainichiId() => content.dict.entries.firstWhere((e) => e.value.w == '毎日').key;

  Future<(AppState, String)> pumpReview(WidgetTester tester, {required String gloss}) async {
    SharedPreferences.setMockInitialValues({});
    final app = AppState();
    await app.load();
    final input = WordInput(dictId: mainichiId(), base: '毎日', word: '毎日', reading: 'まいにち', romaji: 'mainichi', gloss: gloss, pos: 'noun', jlpt: 5, surface: '毎日', clipId: 'no-such-clip', line: 0, idx: 0);
    app.saveWord(input);
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: app, child: MaterialApp(theme: buildTheme(), home: const ReviewScreen(deck: 'words'))));
    await tester.pump(const Duration(milliseconds: 300));
    return (app, input.key);
  }

  testWidgets('tapping the card reveals the answer; grading schedules the next review', (tester) async {
    final (app, key) = await pumpReview(tester, gloss: 'every day');
    expect(find.text('毎日'), findsOneWidget);
    expect(find.textContaining('Tap to reveal'), findsOneWidget);
    expect(find.textContaining('Show answer'), findsNothing, reason: 'the card itself is the only reveal target');
    expect(find.text('Again'), findsNothing);
    expect(find.text('Good'), findsNothing);

    await tester.tap(find.text('毎日'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('DEFINITION'), findsOneWidget);
    expect(find.text('every day; daily'), findsOneWidget);
    // "every day" (this clip) repeats sense 1, so it is not shown a second time.
    expect(find.textContaining('In this clip', findRichText: true), findsNothing);
    expect(find.text('Again'), findsOneWidget);
    expect(find.text('Good'), findsOneWidget);

    final before = DateTime.now().millisecondsSinceEpoch;
    await tester.tap(find.text('Good'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // A new card graded Good comes back in 10 minutes, and the next card starts face down.
    expect(app.words[key]!.card.due - before, greaterThanOrEqualTo(10 * 60 * 1000 - 1000));
    expect(app.totalReviews, 1);
    expect(find.textContaining('Tap to reveal'), findsOneWidget);
    expect(find.text('Good'), findsNothing);
    await tester.pump(const Duration(seconds: 3)); // confetti + debounced save
  });

  testWidgets('a clip meaning that differs from the dictionary is shown once, above it', (tester) async {
    await pumpReview(tester, gloss: 'each day');
    await tester.tap(find.text('毎日'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('In this clip', findRichText: true), findsOneWidget);
    expect(find.text('every day; daily'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
}
