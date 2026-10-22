import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mimi/main.dart' show topPath;

/// The welcome tour moves on when the review opens (a pushed screen), so the app must
/// report the pushed screen's path, not the one underneath it.
void main() {
  testWidgets('topPath follows pushed screens and pops back', (tester) async {
    final router = GoRouter(initialLocation: '/vocab', routes: [
      GoRoute(path: '/vocab', builder: (_, _) => const Text('vocab')),
      GoRoute(path: '/review', builder: (_, _) => const Text('review')),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(topPath(router), '/vocab');

    router.push('/review?deck=words');
    await tester.pumpAndSettle();
    expect(find.text('review'), findsOneWidget);
    expect(topPath(router), '/review');
    // (the old way: the configuration's own uri still says the screen underneath)
    expect(router.routerDelegate.currentConfiguration.uri.path, '/vocab');

    router.pop();
    await tester.pumpAndSettle();
    expect(topPath(router), '/vocab');
  });
}
