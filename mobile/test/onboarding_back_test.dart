import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mimi/widgets/onboarding_back.dart';

void main() {
  testWidgets('system Back on a single onboarding route goes back, not out of app', (tester) async {
    var step = 2;
    var calls = 0;
    final router = GoRouter(initialLocation: '/onboarding', routes: [
      GoRoute(path: '/', builder: (_, _) => const Text('welcome')),
      GoRoute(path: '/onboarding', builder: (context, _) => OnboardingBack(
        onBack: () {
          calls++;
          if (step > 0) {
            step--;
          } else {
            context.go('/');
          }
        },
        child: const Scaffold(body: Text('questions')),
      )),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(router.canPop(), isFalse);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(step, 1);
    expect(calls, 1);
    expect(router.state.uri.path, '/onboarding');
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(step, 0);
    expect(calls, 2);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/');
    expect(calls, 3);
  });

  testWidgets('system Back on pushed onboarding handles once and respects open dialogs', (tester) async {
    var calls = 0;
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const Text('welcome')),
      GoRoute(path: '/onboarding', builder: (_, _) => OnboardingBack(
        onBack: () => calls++,
        child: const Scaffold(body: Text('questions')),
      )),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/onboarding');
    await tester.pumpAndSettle();
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(router.state.uri.path, '/onboarding');
    final context = tester.element(find.text('questions'));
    showDialog<void>(context: context, builder: (_) => const AlertDialog(content: Text('dialog')));
    await tester.pumpAndSettle();
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('dialog'), findsNothing);
    expect(calls, 1);
  });
}