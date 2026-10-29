import 'dart:async';

import 'package:flutter/material.dart';

import '../services/haptics.dart';
import '../theme/tokens.dart';
import 'ui.dart';
import '../i18n/i18n.dart';

/// Top toasts (incl. "Achievement unlocked") — mirrors Toasts in AppFrame.tsx.
enum ToastTone { normal, achievement, error }

class ToastData {
  final int id;
  final String title;
  final String? description;
  final String? icon;
  final ToastTone tone;
  ToastData(this.id, this.title, this.description, this.icon, this.tone);
}

class Toasts extends ChangeNotifier {
  static final Toasts I = Toasts();
  final List<ToastData> items = [];
  int _seq = 1;

  void show(String title, {String? description, String? icon, ToastTone tone = ToastTone.normal}) {
    final t = ToastData(_seq++, title, description, icon, tone);
    if (tone == ToastTone.achievement) Haptics.celebrate();
    if (tone == ToastTone.error) Haptics.error();
    items.add(t);
    if (items.length > 3) items.removeAt(0);
    notifyListeners();
    Timer(Duration(milliseconds: tone == ToastTone.achievement ? 4200 : 3000), () => dismiss(t.id));
  }

  void dismiss(int id) {
    items.removeWhere((x) => x.id == id);
    notifyListeners();
  }
}

void toast(String title, {String? description, String? icon, ToastTone tone = ToastTone.normal}) =>
    Toasts.I.show(title, description: description, icon: icon, tone: tone);

class ToastLayer extends StatelessWidget {
  const ToastLayer({super.key});
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: false,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ListenableBuilder(
            listenable: Toasts.I,
            builder: (context, _) => Column(mainAxisSize: MainAxisSize.min, children: [
              for (final t in Toasts.I.items)
                _ToastCard(key: ValueKey(t.id), t: t),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  final ToastData t;
  const _ToastCard({super.key, required this.t});
  @override
  Widget build(BuildContext context) {
    final bg = t.tone == ToastTone.error ? T.dangerSoft : (t.tone == ToastTone.achievement ? T.surface2 : T.surface3);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Opacity(opacity: v.clamp(0, 1), child: Transform.translate(offset: Offset(0, -24 * (1 - v)), child: child)),
      child: GestureDetector(
        onTap: () => Toasts.I.dismiss(t.id),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: t.tone == ToastTone.achievement ? Border.all(color: T.gold.withValues(alpha: 0.6), width: 2) : null,
            boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 30, offset: Offset(0, 12), spreadRadius: -12)],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Row(children: [
              if (t.icon != null) Padding(padding: const EdgeInsets.only(right: 12), child: Text(t.icon!, style: const TextStyle(fontSize: 26))),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  if (t.tone == ToastTone.achievement) caps(tr('Achievement unlocked'), c: T.gold),
                  Text(tr(t.title), style: txt(15, w: FontWeight.w800)),
                  if (t.description != null) Text(tr(t.description!), style: txt(13, w: FontWeight.w400, c: T.muted)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
