import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../services/haptics.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'tour.dart';
import 'ui.dart';

/// Main app shell with the floating bottom navigation pill — mirrors TabBar.tsx.
class TabShell extends StatelessWidget {
  final Widget child;
  const TabShell({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.background,
      body: Stack(children: [
        Positioned.fill(child: child),
        const Positioned(left: 0, right: 0, bottom: 0, child: MimiTabBar()),
      ]),
    );
  }
}

class MimiTabBar extends StatelessWidget {
  const MimiTabBar({super.key});
  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final due = context.select<AppState, int>((a) => a.counts.due);
    final tabs = [
      ('/feed', ['/feed', '/explore'], 'Feed', LucideIcons.play),
      ('/vocab', ['/vocab'], 'Vocab', LucideIcons.bookOpen),
      ('/profile', ['/profile'], 'Profile', LucideIcons.user),
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: T.surface.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: T.border),
              boxShadow: const [BoxShadow(color: Color(0xB3000000), blurRadius: 40, offset: Offset(0, 16), spreadRadius: -12)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (final t in tabs)
                TourAnchor(
                  id: 'vocabTab',
                  enabled: t.$3 == 'Vocab',
                  child: _Tab(
                    key: ValueKey('tab-${t.$3}'),
                    label: t.$3,
                    icon: t.$4,
                    active: t.$2.any(path.startsWith),
                    badge: t.$3 == 'Vocab' ? due : 0,
                    onTap: () {
                      if (!t.$2.any(path.startsWith)) Haptics.select();
                      context.go(t.$1);
                    },
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final int badge;
  final VoidCallback onTap;
  const _Tab({super.key, required this.label, required this.icon, required this.active, required this.badge, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(clipBehavior: Clip.none, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(color: active ? T.surface3 : Colors.transparent, borderRadius: BorderRadius.circular(99)),
            child: Row(children: [
              Icon(icon, size: 20, color: active ? T.foreground : T.faint),
              if (active) Padding(padding: const EdgeInsets.only(left: 8), child: Text(label, style: txt(14, w: FontWeight.w800))),
            ]),
          ),
          if (badge > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 20),
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(color: T.primary, borderRadius: BorderRadius.circular(99)),
                alignment: Alignment.center,
                child: Text(badge > 99 ? '99+' : '$badge', style: txt(11, w: FontWeight.w900, c: T.primaryFg)),
              ),
            ),
        ]),
      ),
    );
  }
}
