import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mimi/data/content.dart';
import 'package:mimi/state/app_state.dart';
import 'package:mimi/theme/tokens.dart';
import 'package:mimi/widgets/word_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cards opened from a tab screen sit above the floating tab bar (like the web Sheet over
/// the TabBar), and closing the word card is clean.
void main() {
  testWidgets('word card covers the tab bar and closes without errors', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final app = AppState();
    await app.load();
    final index = File('assets/data/content.json').readAsStringSync();
    final parts = [for (final p in ((jsonDecode(index) as Map<String, dynamic>)['parts'] as List? ?? const []).cast<String>()) File('assets/data/$p').readAsStringSync()];
    final content = Content.fromJson(index, File('assets/data/dict.json').readAsStringSync(), parts);
    expect(content.clips, isNotEmpty, reason: 'the bundled library loads with all its parts');
    final clip = content.clips.first;
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    var tabTaps = 0;
    final router = GoRouter(initialLocation: '/feed', routes: [
      ShellRoute(
        builder: (c, s, child) => Scaffold(
          body: Stack(children: [
            Positioned.fill(child: child),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(onTap: () => tabTaps++, child: Container(height: 90, color: T.surface2, alignment: Alignment.center, child: const Text('TAB'))),
            ),
          ]),
        ),
        routes: [
          GoRoute(
            path: '/feed',
            builder: (c, s) => Builder(
              builder: (ctx) => Center(
                child: TextButton(onPressed: () => showWordCard(ctx, clip: clip, line: 0, idx: 0, content: content, notes: null), child: const Text('open')),
              ),
            ),
          ),
        ],
      ),
    ]);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: app, child: MaterialApp.router(theme: buildTheme(), routerConfig: router)));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Examples'), findsOneWidget);

    await tester.tap(find.text('TAB'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 600));
    expect(tabTaps, 0, reason: 'the open card must sit above the tab bar');

    if (find.text('Examples').evaluate().isNotEmpty) {
      await tester.tapAt(const Offset(20, 40)); // tap the dimmed area above the card
      await tester.pump(const Duration(milliseconds: 600));
    }
    expect(find.text('Examples'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 400)); // let the debounced save run
  });
}
