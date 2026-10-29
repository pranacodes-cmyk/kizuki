import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/content.dart';
import '../logic/logic.dart';
import '../services/home_widgets.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

class HomeWidgetsScreen extends StatefulWidget {
  const HomeWidgetsScreen({super.key});
  @override
  State<HomeWidgetsScreen> createState() => _HomeWidgetsScreenState();
}
class _HomeWidgetsScreenState extends State<HomeWidgetsScreen> {
  final content = Content.load();
  String family = 'medium';
  int index = 0;
  bool adding = false;
  @override
  Widget build(BuildContext context) {
    final a = context.watch<AppState>();
    return Scaffold(body: SafeArea(child: Column(children: [
      TopBar(title: 'Widgets', onBack: () => context.canPop() ? context.pop() : context.go('/settings')),
      Expanded(child: ListView(padding: const EdgeInsets.all(20), children: [
        Text('A little Japanese.\nEvery time you look.', style: txt(28, w: FontWeight.w900)),
        const SizedBox(height: 20),
        Row(children: [for (final (v, label) in [('small', 'Small'), ('medium', 'Wide'), ('large', 'Large'), ('lock', 'Lock')])
          Expanded(child: Press(onTap: () => setState(() => family = v), child: Container(height: 40, alignment: Alignment.center,
            decoration: BoxDecoration(color: family == v ? T.primary : T.surface2, borderRadius: BorderRadius.circular(8)),
            child: Text(label, style: txt(13, c: family == v ? T.primaryFg : T.muted)))))]),
        const SizedBox(height: 24),
        FutureBuilder<Content>(future: content, builder: (context, snapshot) {
          final c = snapshot.data;
          if (snapshot.hasError) return Text('Words unavailable. Please try again.', style: txt(14, c: T.muted));
          if (c == null) return const SizedBox(height: 210, child: Center(child: CircularProgressIndicator()));
          final pool = HomeWidgets.words(a, c);
          final w = pool.isEmpty ? null : pool[index % pool.length];
          return Center(child: SizedBox(width: family == 'small' ? 170 : double.infinity,
            child: WidgetPreview(word: w, family: family, reading: a.settings.widgetReading, meaning: a.settings.widgetMeaning,
              due: a.settings.widgetSaved ? a.dueKeys.length : 0, streak: a.settings.widgetSaved ? a.streak : 0)));
        }),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => setState(() => index++), icon: const Icon(Icons.refresh), label: const Text('Next word'))),
        const SizedBox(height: 16),
        _toggle('Use my saved learning words', a.settings.widgetSaved, (v) => a.setSettings((s) => s.widgetSaved = v)),
        _toggle('Show reading', a.settings.widgetReading, (v) => a.setSettings((s) => s.widgetReading = v)),
        _toggle('Show meaning', a.settings.widgetMeaning, (v) => a.setSettings((s) => s.widgetMeaning = v)),
        Text('Saved words and review progress will be visible to anyone looking at your screen.', style: txt(12, c: T.muted)),
        const SizedBox(height: 24),
        Button3D(label: adding ? 'Opening…' : 'Add widget', onPressed: adding ? null : () async {
          setState(() => adding = true);
          final pinned = Platform.isAndroid && family != 'lock' && await HomeWidgets.requestPin(family != 'small');
          if (!mounted) return;
          setState(() => adding = false);
          if (pinned) return;
          if (!mounted) return;
          await showMimiModal<void>(this.context, (sheet) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Add Kizuki to your screen', style: txt(20, w: FontWeight.w900)), const SizedBox(height: 12),
            Text(Platform.isIOS ? (family == 'lock' ? 'Touch and hold your Lock Screen → Customize → Lock Screen → Add Widgets → Kizuki.' : 'Touch and hold your Home Screen → Edit → Add Widget → Kizuki. Choose a size, then tap Add Widget.') : (family == 'lock' ? 'Lock-screen widgets are supported only on some Android versions and devices. Use your device’s widget picker if available.' : 'Touch and hold your Home Screen → Widgets → Kizuki. Drag a widget onto your screen.'), style: txt(15, c: T.muted)),
            const SizedBox(height: 20), Button3D(label: 'Got it', onPressed: () => Navigator.of(context, rootNavigator: true).pop()),
          ]));
        }),
      ])),
    ])));
  }
  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) => Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(children: [Expanded(child: Text(label, style: txt(15))), MimiToggle(value: value, onChanged: onChanged)]));
}

class WidgetPreview extends StatelessWidget {
  final WidgetWord? word;
  final String family;
  final bool reading, meaning;
  final int due, streak;
  const WidgetPreview({super.key, required this.word, required this.family, required this.reading, required this.meaning, required this.due, required this.streak});
  @override
  Widget build(BuildContext context) {
    final w = word;
    final lock = family == 'lock', small = family == 'small';
    if (lock) {
      return ClipRRect(borderRadius: BorderRadius.circular(24), child: SizedBox(height: 310, child: Stack(fit: StackFit.expand, children: [
        Image.asset('assets/widgets/wallpaper.jpg', fit: BoxFit.cover),
        Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          Text('Thursday, 29 October', style: txt(14, c: T.foreground)),
          Text('10:05', style: txt(56, w: FontWeight.w900, c: T.foreground)),
          const SizedBox(height: 28),
          Row(children: [Flexible(child: Text(w?.word ?? '気', maxLines: 1, overflow: TextOverflow.ellipsis, style: txt(40, c: T.foreground, family: T.jp))), const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (reading) Text(w?.reading ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: txt(13, c: T.foreground, family: T.jp)),
              if (meaning) Text(w?.meaning ?? 'Japanese', maxLines: 2, overflow: TextOverflow.ellipsis, style: txt(16, c: T.foreground)),
            ])),
          ]),
        ])),
      ])));
    }
    return Container(height: family == 'large' ? 320 : 180, padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.border), borderRadius: BorderRadius.circular(lock ? 16 : 24)),
      child: lock ? Row(children: [Flexible(child: Text(w?.word ?? '気', maxLines: 1, overflow: TextOverflow.ellipsis, style: txt(40, c: T.foreground, family: T.jp))), const SizedBox(width: 16),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (reading) Text(w?.reading ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: txt(13, c: T.muted, family: T.jp)),
          if (meaning) Text(w?.meaning ?? 'Japanese', maxLines: 2, overflow: TextOverflow.ellipsis, style: txt(16)),
        ]))]) : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Image.asset('assets/mascot/mimi-face.png', width: 22, height: 22), const SizedBox(width: 6), Text('kizuki', style: txt(13, w: FontWeight.w900, c: T.primary)), const Spacer(), if (!small) Icon(Icons.auto_awesome, size: 16, color: T.primary)]),
        const Spacer(),
        if (small) ...[
          Text(w?.word ?? '気', maxLines: 1, overflow: TextOverflow.ellipsis, style: txt(34, w: FontWeight.w800, family: T.jp)),
          if (reading) Text(w?.reading ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: txt(12, c: T.primary, family: T.jp)),
          if (meaning) Text(w?.meaning ?? 'Japanese', maxLines: 1, overflow: TextOverflow.ellipsis, style: txt(13)),
        ] else Row(children: [Flexible(child: Text(w?.word ?? '気', maxLines: 1, overflow: TextOverflow.ellipsis, style: txt(42, w: FontWeight.w800, family: T.jp))), const SizedBox(width: 20), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (reading) Text(w?.reading ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: txt(14, c: T.primary, family: T.jp)),
          if (meaning) Text(w?.meaning ?? 'Japanese', maxLines: 2, overflow: TextOverflow.ellipsis, style: txt(17, w: FontWeight.w800)),
        ]))]),
        if (family == 'large' && w != null && w.example.isNotEmpty) ...[const SizedBox(height: 18), Text(w.example, maxLines: 3, overflow: TextOverflow.ellipsis, style: txt(17, c: T.muted, family: T.jp))],
        const Spacer(),
        if (!small) Row(children: [Text(due > 0 ? '$due to review' : 'A moment of discovery', style: txt(12, c: T.muted)), const Spacer(), if (streak > 0) Text('🔥 $streak', style: txt(12, c: T.gold)), const SizedBox(width: 6), const Icon(Icons.arrow_forward, size: 16, color: T.primary)]),
      ]));
  }
}