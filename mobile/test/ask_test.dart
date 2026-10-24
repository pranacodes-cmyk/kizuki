import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimi/data/ask.dart';
import 'package:mimi/services/sync_service.dart';
import 'package:mimi/state/app_state.dart';
import 'package:mimi/theme/tokens.dart';
import 'package:mimi/widgets/ask_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ctx = AskContext(
  clipId: 'c1',
  title: 'Ordering at a cafe',
  level: 'N5',
  learnerLevel: 'N5',
  ja: 'コーヒーを一つください',
  en: 'One coffee, please.',
  word: AskWord(surface: 'ください', head: 'くださる', reading: 'くださる', gloss: 'please give me'),
);

Future<AppState> _open(WidgetTester tester, {int asked = 0, bool premium = false}) async {
  SharedPreferences.setMockInitialValues({});
  final app = AppState();
  await app.load();
  if (premium) app.startTrial('yearly');
  app.asksDay = app.today;
  app.asksN = asked;
  tester.view.physicalSize = const Size(402 * 3, 874 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: app,
    child: MaterialApp(
      theme: buildTheme(),
      home: Scaffold(body: Builder(builder: (c) => Center(child: TextButton(onPressed: () => showAskSheet(c, _ctx), child: const Text('open'))))),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pump(const Duration(milliseconds: 600));
  return app;
}

Session _fakeSession() => Session(
      accessToken: 'test',
      tokenType: 'bearer',
      user: const User(id: 'u1', appMetadata: {}, userMetadata: {}, aud: 'authenticated', createdAt: '2026-01-01T00:00:00Z'),
    );

void main() {
  tearDown(() => SyncService.I.session = null);

  testWidgets('signed out: the tutor asks for a free account first', (tester) async {
    SyncService.I.session = null;
    await _open(tester);
    expect(find.byKey(const ValueKey('ask-signup')), findsOneWidget);
    expect(find.byKey(const ValueKey('ask-input')), findsNothing);
  });

  testWidgets('signed in without Premium: no questions, the Premium card instead', (tester) async {
    SyncService.I.session = _fakeSession();
    await _open(tester, asked: 0);
    expect(find.byKey(const ValueKey('ask-input')), findsNothing);
    expect(find.text('Premium is required to ask Kizuki'), findsOneWidget);
    expect(find.textContaining('free questions'), findsNothing);
  });

  testWidgets('premium learners are never limited', (tester) async {
    SyncService.I.session = _fakeSession();
    await _open(tester, asked: 40, premium: true);
    expect(find.byKey(const ValueKey('ask-input')), findsOneWidget);
    expect(find.byKey(ValueKey('ask-suggestion-${askSuggestions(true).first}')), findsOneWidget);
    expect(find.text('Premium is required to ask Kizuki'), findsNothing);
  });
}
