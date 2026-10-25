import 'package:flutter/widgets.dart';

/// Handles Android Back even when go()/replacement left only one router page.
/// A route-level PopScope alone cannot handle GoRouter's empty-stack fallback.
class OnboardingBack extends StatelessWidget {
  final Widget child;
  final VoidCallback onBack;
  const OnboardingBack({super.key, required this.child, required this.onBack});

  @override
  Widget build(BuildContext context) => BackButtonListener(
        onBackButtonPressed: () async {
          onBack();
          return true;
        },
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) onBack();
          },
          child: child,
        ),
      );
}