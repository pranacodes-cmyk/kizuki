import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/onboarding.dart';
import '../logic/logic.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';

/// Onboarding questions — mirrors src/routes/onboarding.tsx (same 10 steps and copy).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

List<String> _toggle(List<String> list, String id) => list.contains(id) ? list.where((x) => x != id).toList() : [...list, id];

const _steps = ['reasons', 'level', 'challenges', 'method', 'source', 'fluency', 'minutes', 'window', 'streak', 'name'];

class _OnboardingScreenState extends State<OnboardingScreen> {
  int i = 0;
  int dir = 1;

  void next() {
    if (i == _steps.length - 1) {
      context.push('/building');
      return;
    }
    setState(() {
      dir = 1;
      i++;
    });
  }

  void back() {
    if (i == 0) {
      context.pop();
    } else {
      setState(() {
        dir = -1;
        i--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.profile;
    final step = _steps[i];
    Widget body;
    switch (step) {
      case 'reasons':
        body = _MultiGrid(
          title: 'Why do you want to learn Japanese?',
          subtitle: "Pick all that apply — we'll find clips you'll love.",
          options: reasonOptions,
          value: p.reasons,
          onToggle: (id) => app.setProfile((x) => x.reasons = _toggle(x.reasons, id)),
          onNext: next,
        );
      case 'level':
        body = _Level(value: p.level, onPick: (lv) {
          app.setProfile((x) {
            x.level = lv;
            x.jlpt = levelToJlpt(lv);
          });
          Timer(const Duration(milliseconds: 220), next);
        });
      case 'challenges':
        body = _MultiGrid(
          title: "What's hardest for you right now?",
          subtitle: 'Select all that apply.',
          options: challengeOptions,
          value: p.challenges,
          onToggle: (id) => app.setProfile((x) => x.challenges = _toggle(x.challenges, id)),
          onNext: next,
          benefit: true,
        );
      case 'method':
        body = _Method(onNext: next);
      case 'source':
        body = _Source(onPick: (id) {
          app.setProfile((x) => x.source = id);
          Timer(const Duration(milliseconds: 220), next);
        });
      case 'fluency':
        body = _Fluency(months: p.fluencyMonths, onChange: (m) => app.setProfile((x) {
              x.fluencyMonths = m;
              x.dailyMinutes = recommendedMinutes(m);
            }), onNext: next);
      case 'minutes':
        body = _Minutes(minutes: p.dailyMinutes, months: p.fluencyMonths, onChange: (m) => app.setProfile((x) => x.dailyMinutes = m), onNext: next);
      case 'window':
        body = _Window(value: p.window, minutes: p.dailyMinutes, onChange: (w) => app.setProfile((x) => x.window = w), onNext: () async {
          await NotificationService.requestPermission();
          next();
        });
      case 'streak':
        body = _Streak(value: p.streakGoal, onChange: (d) => app.setProfile((x) => x.streakGoal = d), onNext: next);
      default:
        body = _Name(value: p.name, onChange: (n) => app.setProfile((x) => x.name = n), onNext: next);
    }
    return PopScope(
      canPop: i == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(children: [
            ProgressHeader(progress: (i + 1) / (_steps.length + 1), onBack: back),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(position: Tween(begin: Offset(0.15 * dir, 0), end: Offset.zero).animate(a), child: child),
                ),
                child: KeyedSubtree(key: ValueKey(step), child: body),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? extra;
  const _Title(this.title, {this.subtitle, this.extra});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: txt(26, w: FontWeight.w900, h: 1.2)),
          if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(subtitle!, style: txt(15, w: FontWeight.w400, c: T.muted))),
          ?extra,
        ]),
      );
}

Widget _footer(List<Widget> children) => Padding(padding: const EdgeInsets.fromLTRB(24, 12, 24, 8), child: Column(mainAxisSize: MainAxisSize.min, children: children));

class _GridCard extends StatelessWidget {
  final bool active;
  final String emoji, label;
  final VoidCallback onTap;
  const _GridCard({required this.active, required this.emoji, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Press(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: active ? T.primary.withValues(alpha: 0.1) : T.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? T.primary : T.border, width: 2),
          ),
          child: Stack(children: [
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
                Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: txt(15, w: FontWeight.w800, h: 1.2)),
              ]),
            ),
            if (active)
              Positioned(
                right: 8,
                top: 8,
                child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: T.primary, shape: BoxShape.circle), child: const Icon(LucideIcons.check, size: 14, color: T.primaryFg)),
              ),
          ]),
        ),
      );
}

class _ListOption extends StatelessWidget {
  final bool active;
  final Widget left;
  final String label;
  final String? hint;
  final VoidCallback onTap;
  const _ListOption({required this.active, required this.left, required this.label, this.hint, required this.onTap});
  @override
  Widget build(BuildContext context) => Press(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: active ? T.primary.withValues(alpha: 0.1) : T.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? T.primary : T.border, width: 2),
          ),
          child: Row(children: [
            SizedBox(width: 40, height: 40, child: Center(child: left)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: txt(16, w: FontWeight.w800)),
                if (hint != null) Text(hint!, style: txt(13, w: FontWeight.w400, c: T.muted)),
              ]),
            ),
          ]),
        ),
      );
}

class _MultiGrid extends StatelessWidget {
  final String title, subtitle;
  final List<Option> options;
  final List<String> value;
  final ValueChanged<String> onToggle;
  final VoidCallback onNext;
  final bool benefit;
  const _MultiGrid({required this.title, required this.subtitle, required this.options, required this.value, required this.onToggle, required this.onNext, this.benefit = false});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _Title(title, subtitle: subtitle),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 120),
          itemCount: options.length,
          itemBuilder: (_, i) => _GridCard(
            active: value.contains(options[i].id),
            emoji: options[i].emoji,
            label: options[i].label,
            onTap: () => onToggle(options[i].id),
          ),
        ),
      ),
      _footer([
        if (benefit)
          SizedBox(
            height: 44,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: value.isEmpty
                  ? const SizedBox()
                  : Row(key: ValueKey(value.last), crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Padding(padding: EdgeInsets.only(top: 2), child: Icon(LucideIcons.check, size: 16, color: T.success)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(challengeBenefit(value.last), style: txt(14, w: FontWeight.w700, c: T.success))),
                    ]),
            ),
          ),
        Button3D(label: 'Continue', onPressed: value.isEmpty ? null : onNext),
      ]),
    ]);
  }
}

class _Bars extends StatelessWidget {
  final int n;
  const _Bars(this.n);
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 24,
        child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var b = 1; b <= 5; b++)
            Container(margin: const EdgeInsets.only(right: 3), width: 5, height: 24 * b * 0.2, decoration: BoxDecoration(color: b <= n ? T.primary : T.surface3, borderRadius: BorderRadius.circular(2))),
        ]),
      );
}

class _Level extends StatefulWidget {
  final int value;
  final ValueChanged<int> onPick;
  const _Level({required this.value, required this.onPick});
  @override
  State<_Level> createState() => _LevelState();
}

class _LevelState extends State<_Level> {
  int? picked;
  @override
  Widget build(BuildContext context) => Column(children: [
        const _Title('How much Japanese do you know?', subtitle: "We'll match clips to your level.", extra: Padding(padding: EdgeInsets.only(top: 12), child: Pill('You can change this anytime in settings'))),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(24, 20, 24, 8), children: [
            for (var idx = 0; idx < levelOptions.length; idx++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ListOption(
                  active: picked == idx,
                  left: _Bars(idx + 1),
                  label: levelOptions[idx].label,
                  hint: levelOptions[idx].hint,
                  onTap: () {
                    setState(() => picked = idx);
                    widget.onPick(idx);
                  },
                ),
              ),
          ]),
        ),
      ]);
}

class _Method extends StatelessWidget {
  final VoidCallback onNext;
  const _Method({required this.onNext});
  @override
  Widget build(BuildContext context) => Column(children: [
        const _Title('Learn the way you learned your first language', subtitle: 'By listening to real people — not by memorising rules.'),
        Container(
          margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: T.surface, borderRadius: BorderRadius.circular(28)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            caps('Real Japanese you hear in 10 minutes'),
            const SizedBox(height: 20),
            SizedBox(
              height: 230,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('~10 lines', style: txt(14, w: FontWeight.w800, c: T.muted)),
                  const SizedBox(height: 8),
                  _GrowBar(height: 36, color: T.surface3, delay: 200),
                  const SizedBox(height: 8),
                  Text('Drill apps', style: txt(13, c: T.muted)),
                ]),
                const SizedBox(width: 32),
                Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('100+ lines', style: txt(14, w: FontWeight.w800, c: T.primary)),
                  const Mascot(MascotPose.cheer, size: 48),
                  _GrowBar(height: 130, color: T.primary, delay: 350),
                  const SizedBox(height: 8),
                  Text('With Kizuki', style: txt(13)),
                ]),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(children: [
            for (final t in ['Hear real native speed from day one', 'Every word explained in its sentence', 'Remember words with the original audio'])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [const Icon(LucideIcons.check, size: 16, color: T.success), const SizedBox(width: 8), Expanded(child: Text(t, style: txt(15)))]),
              ),
          ]),
        ),
        const Spacer(),
        _footer([Button3D(label: 'Continue', onPressed: onNext)]),
      ]);
}

class _GrowBar extends StatelessWidget {
  final double height;
  final Color color;
  final int delay;
  const _GrowBar({required this.height, required this.color, required this.delay});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 700 + delay),
        curve: Interval(delay / (700 + delay), 1, curve: Curves.easeOutCubic),
        builder: (_, v, _) => Container(width: 80, height: height * v, decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(12)))),
      );
}

class _Source extends StatefulWidget {
  final ValueChanged<String> onPick;
  const _Source({required this.onPick});
  @override
  State<_Source> createState() => _SourceState();
}

class _SourceState extends State<_Source> {
  String? picked;
  @override
  Widget build(BuildContext context) => Column(children: [
        const _Title('Where did you hear about Kizuki?', subtitle: 'Helps us reach more learners like you.'),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(24, 20, 24, 16), children: [
            for (final o in sourceOptions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ListOption(
                  active: picked == o.id,
                  left: Text(o.emoji, style: const TextStyle(fontSize: 26)),
                  label: o.label,
                  onTap: () {
                    setState(() => picked = o.id);
                    widget.onPick(o.id);
                  },
                ),
              ),
          ]),
        ),
      ]);
}

class _MimiSlider extends StatelessWidget {
  final double value, min, max;
  final int divisions;
  final Color color;
  final ValueChanged<double> onChanged;
  const _MimiSlider({required this.value, required this.min, required this.max, required this.divisions, required this.color, required this.onChanged});
  @override
  Widget build(BuildContext context) => SliderTheme(
        data: SliderThemeData(
          trackHeight: 12,
          activeTrackColor: color,
          inactiveTrackColor: T.surface2,
          thumbColor: color,
          overlayColor: color.withValues(alpha: 0.15),
          thumbShape: const _RingThumb(),
          showValueIndicator: ShowValueIndicator.never,
          tickMarkShape: SliderTickMarkShape.noTickMark,
          activeTickMarkColor: Colors.transparent,
          inactiveTickMarkColor: Colors.transparent,
        ),
        child: Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
      );
}

class _RingThumb extends SliderComponentShape {
  const _RingThumb();
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(32, 32);
  @override
  void paint(PaintingContext context, Offset center, {required Animation<double> activationAnimation, required Animation<double> enableAnimation, required bool isDiscrete, required TextPainter labelPainter, required RenderBox parentBox, required SliderThemeData sliderTheme, required TextDirection textDirection, required double value, required double textScaleFactor, required Size sizeWithOverflow}) {
    final c = context.canvas;
    c.drawCircle(center, 16, Paint()..color = T.foreground);
    c.drawCircle(center, 12, Paint()..color = sliderTheme.thumbColor ?? T.primary);
  }
}

class _Fluency extends StatelessWidget {
  final int months;
  final ValueChanged<int> onChange;
  final VoidCallback onNext;
  const _Fluency({required this.months, required this.onChange, required this.onNext});
  @override
  Widget build(BuildContext context) => Column(children: [
        const _Title('When do you want to understand Japanese?', subtitle: "Set a goal. We'll keep it realistic."),
        const SizedBox(height: 16),
        Pill('🇯🇵 Conversational by ${goalDateLabel(DateTime.now(), months)}', tone: PillTone.success),
        const SizedBox(height: 24),
        Ring(value: months / 36, color: T.success, child: Column(mainAxisSize: MainAxisSize.min, children: [Text('$months', style: txt(52, w: FontWeight.w900, h: 1)), Text('months', style: txt(16, c: T.muted))])),
        const SizedBox(height: 28),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _MimiSlider(value: months.toDouble(), min: 3, max: 36, divisions: 33, color: T.success, onChanged: (v) => onChange(v.round()))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('3 months', style: txt(12, c: T.faint)), Text('3 years', style: txt(12, c: T.faint))])),
        const Spacer(),
        _footer([Button3D(label: 'Continue', onPressed: onNext)]),
      ]);
}

class _Minutes extends StatelessWidget {
  final int minutes, months;
  final ValueChanged<int> onChange;
  final VoidCallback onNext;
  const _Minutes({required this.minutes, required this.months, required this.onChange, required this.onNext});
  @override
  Widget build(BuildContext context) {
    final rec = recommendedMinutes(months);
    return Column(children: [
      const _Title('How much time can you give each day?', subtitle: 'Consistency beats intensity. Even 5 minutes works.'),
      const SizedBox(height: 16),
      Pill('🧠 About ${wordsPerMonth(minutes)} new words a month', tone: PillTone.primary),
      const SizedBox(height: 24),
      Ring(value: minutes / 60, color: T.primary, child: Column(mainAxisSize: MainAxisSize.min, children: [Text('$minutes', style: txt(52, w: FontWeight.w900, h: 1)), Text('minutes', style: txt(16, c: T.muted))])),
      const SizedBox(height: 28),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _MimiSlider(value: minutes.toDouble(), min: 5, max: 60, divisions: 11, color: T.primary, onChanged: (v) => onChange(v.round()))),
      const SizedBox(height: 12),
      minutes >= rec ? Pill('✓ Enough to reach your $months-month goal', tone: PillTone.success) : Pill('$rec min/day recommended for $months months'),
      const Spacer(),
      _footer([Button3D(label: "I'm committed", onPressed: onNext)]),
    ]);
  }
}

class _Window extends StatefulWidget {
  final String value;
  final int minutes;
  final ValueChanged<String> onChange;
  final VoidCallback onNext;
  const _Window({required this.value, required this.minutes, required this.onChange, required this.onNext});
  @override
  State<_Window> createState() => _WindowState();
}

class _WindowState extends State<_Window> {
  bool picked = false;
  @override
  Widget build(BuildContext context) => Column(children: [
        _Title('When can you spend ${widget.minutes} minutes?', subtitle: "We'll send one friendly reminder so you never break your streak."),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(24, 20, 24, 8), children: [
            for (final o in windowOptions)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ListOption(
                  active: picked && widget.value == o.id,
                  left: Text(o.emoji, style: const TextStyle(fontSize: 26)),
                  label: o.label,
                  hint: o.hint,
                  onTap: () {
                    setState(() => picked = true);
                    widget.onChange(o.id);
                  },
                ),
              ),
          ]),
        ),
        _footer([
          Text('Learners with reminders on are far more likely to keep their streak.', textAlign: TextAlign.center, style: txt(13, w: FontWeight.w400, c: T.muted)),
          const SizedBox(height: 12),
          Button3D(label: picked ? 'Remind me ${windowLabel(widget.value)}' : 'Pick a time', onPressed: picked ? widget.onNext : null),
        ]),
      ]);
}

class _Streak extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChange;
  final VoidCallback onNext;
  const _Streak({required this.value, required this.onChange, required this.onNext});
  @override
  Widget build(BuildContext context) => Column(children: [
        const Padding(padding: EdgeInsets.only(top: 8), child: Mascot(MascotPose.brave, size: 128)),
        const _Title('Make a promise to yourself', subtitle: 'Pick a streak goal. Kizuki will cheer you on.'),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(24, 20, 24, 8), children: [
            for (final o in streakOptions)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ListOption(active: value == o.days, left: Text(o.emoji, style: const TextStyle(fontSize: 26)), label: '${o.days}-day streak', hint: o.label, onTap: () => onChange(o.days)),
              ),
          ]),
        ),
        _footer([Button3D(label: 'Commit to $value days', onPressed: onNext)]),
      ]);
}

class _Name extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChange;
  final VoidCallback onNext;
  const _Name({required this.value, required this.onChange, required this.onNext});
  @override
  State<_Name> createState() => _NameState();
}

class _NameState extends State<_Name> {
  late final _c = TextEditingController(text: widget.value);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // Close the keyboard first so the next screen doesn't open half-covered.
  void _go() {
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    // With the keyboard up the fox steps aside, so the field and both buttons stay visible.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    // The buttons live outside the scrolling part, so they always sit right above the keyboard.
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: keyboard
                  ? const SizedBox(width: double.infinity, height: 4)
                  : const Padding(padding: EdgeInsets.only(top: 16), child: Mascot(MascotPose.wave, size: 128)),
            ),
            const _Title('Last thing — what should Kizuki call you?', subtitle: 'So your plan feels like yours.'),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: MimiField(controller: _c, hint: 'Your first name', maxLength: 30, onChanged: widget.onChange, onSubmitted: (_) => _c.text.trim().isNotEmpty ? _go() : null, autofill: const [AutofillHints.givenName]),
            ),
          ]),
        ),
      ),
      _footer([
        ListenableBuilder(listenable: _c, builder: (_, _) => Button3D(label: 'Build my plan', onPressed: _c.text.trim().isEmpty ? null : _go)),
        const SizedBox(height: 8),
        Button3D(label: 'Skip', variant: BtnVariant.ghost, height: 48, onPressed: _go),
      ]),
    ]);
  }
}

/// Text input styled like the web inputs.
class MimiField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int? maxLength;
  final bool obscure;
  final TextInputType? keyboard;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofill;
  final Widget? suffix;
  final IconData? prefixIcon;
  final int minLines, maxLines;
  const MimiField({super.key, required this.controller, required this.hint, this.maxLength, this.obscure = false, this.keyboard, this.onChanged, this.onSubmitted, this.autofill, this.suffix, this.prefixIcon, this.minLines = 1, this.maxLines = 1});
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        autofillHints: autofill,
        maxLength: maxLength,
        minLines: minLines,
        maxLines: maxLines,
        style: txt(16, w: FontWeight.w700),
        cursorColor: T.primary,
        decoration: InputDecoration(
          counterText: '',
          hintText: hint,
          hintStyle: txt(16, w: FontWeight.w700, c: T.faint),
          filled: true,
          fillColor: T.surface,
          prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, color: T.faint, size: 20),
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: T.border, width: 2)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: T.primary, width: 2)),
        ),
      );
}
