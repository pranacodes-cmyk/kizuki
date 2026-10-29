import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../i18n/i18n.dart';
import '../logic/logic.dart';
import '../services/analytics.dart';
import '../services/haptics.dart';
import '../theme/mascot_motion.dart';
import '../theme/tokens.dart';
import '../widgets/lively_mascot.dart';
import '../widgets/ui.dart';

/// App language picker — mirrors src/routes/language.tsx.
///
/// First run (before the welcome screen) and Settings → App language. The phone's language is
/// preselected when Kizuki speaks it; the heading and button preview the highlighted language
/// before anything is saved.
class LanguageScreen extends StatefulWidget {
  final bool fromSettings;
  const LanguageScreen({super.key, this.fromSettings = false});
  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  late String picked = I18n.chosen ? I18n.lang.value : I18n.suggested();

  Future<void> _continue() async {
    Haptics.tap();
    final before = I18n.lang.value;
    await I18n.set(picked);
    Analytics.track('language_selected', {
      'language': picked,
      'previous_language': before,
      'suggested': picked == I18n.suggested(),
      'source': widget.fromSettings ? 'settings' : 'first_run',
    });
    if (!mounted) return;
    if (widget.fromSettings) {
      context.canPop() ? context.pop() : context.go('/settings');
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(children: [
      if (widget.fromSettings)
        TopBar(title: trIn(picked, 'App language'), onBack: () => context.canPop() ? context.pop() : context.go('/settings'))
      else
        const SizedBox(height: 12),
      Expanded(
        child: FadedScroll(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!widget.fromSettings) ...[
              const Center(child: LivelyMascot(MascotPose.wave, size: 112, idle: MascotIdle.float, entrance: true)),
              const SizedBox(height: 12),
            ],
            Text(trIn(picked, 'Choose your language'), textAlign: widget.fromSettings ? TextAlign.start : TextAlign.center, style: txt(26, w: FontWeight.w900, h: 1.2)),
            const SizedBox(height: 8),
            Text(
              trIn(picked, 'Kizuki explains Japanese in this language. You can change it anytime in Settings.'),
              textAlign: widget.fromSettings ? TextAlign.start : TextAlign.center,
              style: txt(15, w: FontWeight.w400, c: T.muted),
            ),
            const SizedBox(height: 20),
            for (final l in languages) ...[
              _LanguageRow(language: l, active: picked == l.code, onTap: () => setState(() => picked = l.code)),
              const SizedBox(height: 10),
            ],
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
        child: Button3D(label: widget.fromSettings ? trIn(picked, 'Save') : trIn(picked, 'Continue'), onPressed: _continue),
      ),
    ]);
    return Scaffold(body: SafeArea(child: body));
  }
}

class _LanguageRow extends StatelessWidget {
  final Language language;
  final bool active;
  final VoidCallback onTap;
  const _LanguageRow({required this.language, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: active,
        label: language.native == language.english ? language.native : '${language.native}, ${language.english}',
        child: Press(
          onTap: () {
            Haptics.select();
            onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: active ? T.primary.withValues(alpha: 0.1) : T.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: active ? T.primary : T.border, width: 2),
            ),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: T.surface2, shape: BoxShape.circle),
                child: Pop(active: active, child: Text(language.flag, style: const TextStyle(fontSize: 24, height: 1))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ExcludeSemantics(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(language.native, maxLines: 1, overflow: TextOverflow.ellipsis, style: txt(16, w: FontWeight.w800)),
                    if (language.native != language.english)
                      Text(language.english, maxLines: 1, overflow: TextOverflow.ellipsis, style: txt(13, w: FontWeight.w600, c: T.muted)),
                  ]),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? T.primary : Colors.transparent,
                  border: Border.all(color: active ? T.primary : T.surface3, width: 2),
                ),
                child: active ? const Icon(LucideIcons.check, size: 15, color: T.primaryFg) : null,
              ),
            ]),
          ),
        ),
      );
}
