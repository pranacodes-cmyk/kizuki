import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/legal.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// Legal page (Privacy / Terms) — mirrors LegalPage.tsx. Copy lives in data/legal.dart,
/// generated word for word from src/lib/legal.ts. Lines starting with "• " are bullets.
class LegalScreen extends StatelessWidget {
  final String kind; // terms | privacy
  const LegalScreen({super.key, required this.kind});
  @override
  Widget build(BuildContext context) {
    final doc = kind == 'terms' ? termsDoc : privacyDoc;
    final body = txt(15, w: FontWeight.w400, c: T.muted, h: 1.6);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: doc.title, onBack: () => context.canPop() ? context.pop() : context.go('/settings')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 48), children: [
              Text('Last updated: ${doc.updated}', style: txt(13, w: FontWeight.w700, c: T.faint)),
              const SizedBox(height: 12),
              Text(doc.intro, style: body),
              for (final s in doc.sections)
                Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.h, style: txt(17, w: FontWeight.w900, h: 1.3)),
                    for (final line in s.body)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: line.startsWith('• ')
                            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 9, right: 10),
                                  child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: T.primary, shape: BoxShape.circle)),
                                ),
                                Expanded(child: Text(line.substring(2), style: body)),
                              ])
                            : Text(line, style: body),
                      ),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
