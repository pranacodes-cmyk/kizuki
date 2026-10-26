import 'dart:math' as math;

import 'package:flutter/material.dart' hide Card;
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/content.dart';
import '../data/models.dart' as m;
import '../data/tour.dart' show TourEvent;
import '../logic/logic.dart';
import '../services/haptics.dart';
import '../services/analytics.dart';
import '../services/tts.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/clip_player.dart' show watchUrl;
import '../widgets/context_player.dart';
import '../widgets/lively_mascot.dart';
import '../widgets/saved_word_sheet.dart';
import '../widgets/toast.dart';
import '../widgets/tour.dart';
import '../widgets/ui.dart';
import '../widgets/word_card.dart' show posNames;

/// How the review timing works, in plain words (no interval codes) — same text in review.tsx.
const reviewDoneNote = "Each word comes back right before you'd forget it. Forgotten words come back sooner.";

/// Flashcard review (words with original clip audio, or kana decks) — mirrors src/routes/review.tsx.
class ReviewScreen extends StatefulWidget {
  final String deck; // words | hiragana | katakana
  final bool extra;
  const ReviewScreen({super.key, required this.deck, this.extra = false});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late ReviewSession sess;
  int total = 0;
  bool revealed = false, finished = false;
  late final List<KanaCard> kanaCards = widget.deck == 'words' ? const [] : kanaDeck(widget.deck);
  Content? content;
  late final bool firstTime;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    firstTime = !app.tutorialReview;
    _startSession(app, extra: widget.extra);
    Content.load().then((c) {
      if (mounted) setState(() => content = c);
    });
  }

  void _startSession(AppState app, {required bool extra}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final ids = widget.deck == 'words' ? (extra ? customStudyKeys(app.wordLites, now) : app.dueKeys) : kanaQueue(kanaCards, app.kana, now);
    sess = ReviewSession(ids);
    total = ids.length;
    Analytics.track('review_session_started', {'deck': widget.deck, 'card_count': total, 'extra': extra});
  }

  Card? _card(AppState app, String? id) {
    if (id == null) return null;
    if (widget.deck == 'words') return app.words[id]?.card;
    return app.kana[id] ?? newCard(DateTime.now().millisecondsSinceEpoch);
  }

  void _answer(String grade) {
    final app = context.read<AppState>();
    final id = sess.current;
    final card = _card(app, id);
    if (id == null || card == null) return;
    Analytics.track('review_answered', {'deck': widget.deck, 'grade': grade});
    final next = sess.answer(card, grade, DateTime.now().millisecondsSinceEpoch);
    if (widget.deck == 'words') {
      app.answerWord(id, next);
    } else {
      app.answerKana(id, next);
    }
    Tour.I.emit(TourEvent.graded);
    // Remembered feels like a small win, Forgot stays gentle, the last card celebrates.
    Haptics.play(sess.done ? HapticKind.celebrate : (grade == 'again' ? HapticKind.light : HapticKind.success));
    setState(() {
      revealed = false;
      if (sess.done) {
        app.finishReviewSession();
        app.completeTutorial('review');
        finished = true;
      }
    });
  }

  void _reveal() {
    Analytics.track('review_card_revealed', {'deck': widget.deck});
    setState(() => revealed = true);
    Tour.I.emit(TourEvent.reveal);
  }

  Future<void> _exit() async {
    final app = context.read<AppState>();
    if (finished && !app.planModalSeen) {
      await showMimiModal<void>(context, (_) => const _PlanModal(), dismissible: false);
      app.setPlanModalSeen();
    } else if (finished && app.reviewSessions >= 2 && !app.ratingAsked) {
      // Store rules: show only the official Apple/Google rating sheet, never our own question first.
      app.setRatingAsked();
      try {
        final r = InAppReview.instance;
        if (await r.isAvailable()) await r.requestReview();
      } catch (_) {}
    }
    if (mounted) context.go('/vocab');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final settings = app.settings;

    if (total == 0 || finished) {
      final extraAvail = widget.deck == 'words' && customStudyKeys(app.wordLites, DateTime.now().millisecondsSinceEpoch).isNotEmpty;
      return Scaffold(
        body: Stack(children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    LivelyMascot(finished ? MascotPose.brave : MascotPose.cheer, size: 144, entrance: true, hopAfterMs: 400, tappable: true),
                    const SizedBox(height: 12),
                    Text(finished ? 'Well done!' : 'All caught up!', style: txt(28, w: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(LucideIcons.check, size: 20, color: T.success),
                      const SizedBox(width: 6),
                      Text(finished ? '${sess.answered} card${sess.answered == 1 ? '' : 's'} reviewed' : 'Nothing due right now', style: txt(16, w: FontWeight.w800, c: T.success)),
                    ]),
                    const SizedBox(height: 10),
                    Text(reviewDoneNote, textAlign: TextAlign.center, style: txt(15, w: FontWeight.w600, c: T.muted, h: 1.4)),
                  ]),
                ),
                Button3D(label: "I'm done for now", onPressed: _exit),
                if (extraAvail) ...[
                  const SizedBox(height: 12),
                  Button3D(
                    label: 'Keep studying',
                    variant: BtnVariant.surface,
                    onPressed: () {
                      if (widget.extra) {
                        setState(() {
                          _startSession(app, extra: true);
                          finished = false;
                          revealed = false;
                        });
                      } else {
                        context.pushReplacement('/review?deck=words&mode=extra');
                      }
                    },
                  ),
                ],
                const SizedBox(height: 8),
              ]),
            ),
          ),
          if (finished) const Positioned.fill(child: Confetti()),
        ]),
      );
    }

    final id = sess.current;
    final word = widget.deck == 'words' && id != null ? app.words[id] : null;
    final kana = widget.deck != 'words' && id != null ? kanaCards.where((k) => k.id == id).firstOrNull : null;
    final card = _card(app, id);
    final progress = total == 0 ? 1.0 : (sess.answered / (total > sess.answered + sess.queue.length ? total : sess.answered + sess.queue.length)).clamp(0.0, 1.0);

    // Kiku-style flashcard: the whole card is the one thing to tap (no separate "Show answer").
    Widget front() => Stack(children: [
          Positioned.fill(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (word != null && settings.flashFront == 'en')
                  Text(word.gloss, textAlign: TextAlign.center, style: txt(28, w: FontWeight.w900))
                else ...[
                  if (word != null && settings.flashFurigana && word.reading != word.word) Text(word.reading, style: jp(18, c: T.muted)),
                  Text(word?.word ?? kana?.kana ?? '', textAlign: TextAlign.center, style: jp(56, w: FontWeight.w900, h: 1.2)),
                  if (word != null && settings.flashRomaji) Text(word.romaji, style: txt(16, c: T.muted)),
                ],
              ]),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 4,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(LucideIcons.pointer, size: 16, color: T.faint),
              const SizedBox(width: 6),
              Flexible(child: Text(firstTime ? 'Remember it? Tap to reveal' : 'Tap to reveal', textAlign: TextAlign.center, maxLines: 2, style: txt(15, w: FontWeight.w700, c: T.faint))),
            ]),
          ),
        ]);

    Widget chip(String s, {Color bg = T.surface2, Color fg = T.muted}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
          child: Text(s, style: txt(12, w: FontWeight.w800, c: fg)),
        );

    Widget backWord() {
      final w = word;
      if (w == null) return const SizedBox.shrink();
      final c = content;
      final clip = c?.byId[w.clipId];
      final entry = w.dictId != null ? c?.dict[w.dictId] : null;
      final senses = entry == null ? const <m.Sense>[] : entry.m.take(3).toList();
      final pos = senses.isNotEmpty && senses.first.pos.isNotEmpty ? senses.first.pos.first : (posNames[w.pos] ?? (w.pos == 'other' ? null : w.pos));
      final showClipMeaning = senses.isEmpty ? w.gloss.isNotEmpty : !repeatsSense(w.gloss, senses.first.g);
      return SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (w.reading != w.word) Text(w.reading, style: jp(16, c: T.muted)),
                Text(w.word, style: jp(40, w: FontWeight.w900, h: 1.2)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(w.romaji, style: txt(15, c: T.muted)),
                  if (pos != null) chip(pos, fg: T.foreground),
                  if (w.jlpt != null) chip('N${w.jlpt}', bg: T.successSoft, fg: T.success),
                ]),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(button: true, label: 'Play pronunciation', child: Press(onTap: () => Tts.speak(w.reading.isNotEmpty ? w.reading : w.word), child: Container(width: 44, height: 44, decoration: const BoxDecoration(color: T.surface2, shape: BoxShape.circle), child: const Icon(LucideIcons.volume2, size: 20)))),
            ),
          ]),
          const SizedBox(height: 16),
          caps('Definition'),
          const SizedBox(height: 8),
          if (showClipMeaning)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: T.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Text.rich(TextSpan(children: [TextSpan(text: 'In this clip: ', style: txt(14, w: FontWeight.w800, c: T.primary)), TextSpan(text: w.gloss, style: txt(16, w: FontWeight.w800))])),
            ),
          for (var i = 0; i < senses.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 22, height: 22, alignment: Alignment.center, decoration: const BoxDecoration(color: T.surface2, shape: BoxShape.circle), child: Text('${i + 1}', style: txt(12, w: FontWeight.w900))),
                const SizedBox(width: 10),
                Expanded(child: Text(senses[i].g, style: txt(i == 0 ? 17 : 15, w: i == 0 ? FontWeight.w800 : FontWeight.w400, c: i == 0 ? T.foreground : T.muted, h: 1.35))),
              ]),
            ),
          if (clip != null) ...[
            const SizedBox(height: 20),
            caps('Example sentence'),
            const SizedBox(height: 8),
            HighlightedLine(clip: clip, line: w.line, idx: w.idx, size: 20),
            if (w.line < clip.lines.length)
              Padding(padding: const EdgeInsets.only(top: 6), child: Text(clip.lines[w.line].en, style: txt(15, w: FontWeight.w400, c: T.muted, h: 1.4))),
            const SizedBox(height: 16),
            Button3D(
              variant: BtnVariant.surface,
              height: 48,
              label: 'Watch original',
              onPressed: () => showMimiSheet<void>(context, (_) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(clip.title, style: txt(18, w: FontWeight.w900)),
                  const SizedBox(height: 12),
                  ContextPlayer(key: ValueKey('ctx-$id-${sess.answered}'), clip: clip, line: w.line, autoplay: true),
                  TextButton(onPressed: () => launchUrl(Uri.parse(watchUrl(clip.videoId, clip.start)), mode: LaunchMode.externalApplication), child: Text('${c?.videos[clip.videoId]?.channel ?? 'YouTube'} · Watch on YouTube')),
                  const SizedBox(height: 12),
                  HighlightedLine(clip: clip, line: w.line, idx: w.idx),
                  TextButton(onPressed: () { Navigator.of(context).pop(); context.push('/clip/${clip.id}'); }, child: const Text('Open the clip')),
                ]),
              )),
            ),
          ],
        ]),
      );
    }

    Widget backKana() => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(kana?.kana ?? '', style: jp(64, w: FontWeight.w900, h: 1)),
          const SizedBox(height: 16),
          Text(kana?.romaji ?? '', style: txt(32, w: FontWeight.w900, c: T.primary)),
          const SizedBox(height: 20),
          Semantics(button: true, label: 'Play sound', child: Press(onTap: () => Tts.speak(kana?.kana ?? ''), child: Container(width: 48, height: 48, decoration: const BoxDecoration(color: T.surface2, shape: BoxShape.circle), child: const Icon(LucideIcons.volume2, size: 20)))),
        ]);

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          SizedBox(
            height: 48,
            child: Row(children: [
              const SizedBox(width: 8),
              IconButton(tooltip: 'Close review', onPressed: () => context.go('/vocab'), icon: const Icon(LucideIcons.x, size: 24, color: T.muted)),
              Expanded(
                child: LayoutBuilder(
                  builder: (_, c) => Container(
                    height: 12,
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(99)),
                    child: AnimatedContainer(duration: const Duration(milliseconds: 300), width: c.maxWidth * (progress < 0.04 ? 0.04 : progress), decoration: BoxDecoration(color: T.success, borderRadius: BorderRadius.circular(99))),
                  ),
                ),
              ),
              SizedBox(width: 48, child: Text('${sess.queue.length}', textAlign: TextAlign.right, style: txt(13, w: FontWeight.w900, c: T.muted))),
              const SizedBox(width: 16),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(a), child: c)),
                child: TourAnchor(
                  key: ValueKey('$id-${sess.answered}'),
                  id: 'reviewCard',
                  enabled: !revealed,
                  child: _SwipeCard(
                    revealed: revealed,
                    onReveal: _reveal,
                    onSwipe: _answer,
                    child: !revealed ? front() : (word != null ? backWord() : backKana()),
                  ),
                ),
              ),
            ),
          ),
          // Grade buttons slide in once the answer shows — before that the card is the only target.
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: revealed && card != null
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      if (firstTime) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Did you remember it?', style: txt(13, w: FontWeight.w700, c: T.faint))),
                      // Plain words only — no "1m / 10m" timing codes; the app picks the timing.
                      TourAnchor(id: 'grade', child: Row(children: [
                        Expanded(child: _GradeBtn(label: 'Forgot', icon: LucideIcons.x, bg: T.dangerSoft, fg: T.danger, onTap: () => _answer('again'))),
                        const SizedBox(width: 12),
                        Expanded(child: _GradeBtn(label: 'Remembered', icon: LucideIcons.check, bg: T.successSoft, fg: T.success, onTap: () => _answer('good'))),
                      ])),
                    ]),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ]),
      ),
    );
  }
}

class _GradeBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg, fg;
  final VoidCallback onTap;
  const _GradeBtn({required this.label, required this.icon, required this.bg, required this.fg, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Press(
          onTap: onTap,
          child: Container(
            height: 60,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 8),
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: txt(17, w: FontWeight.w900, c: fg))),
            ]),
          ),
        ),
      );
}

/// The flashcard: tap anywhere to flip it; once revealed, swipe right = Good, left = Again.
class _SwipeCard extends StatefulWidget {
  final Widget child;
  final bool revealed;
  final VoidCallback onReveal;
  final ValueChanged<String> onSwipe;
  const _SwipeCard({required this.child, required this.revealed, required this.onReveal, required this.onSwipe});
  @override
  State<_SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<_SwipeCard> with SingleTickerProviderStateMixin {
  double dx = 0;
  late final AnimationController _back = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _back.addListener(() => setState(() => dx = _from * (1 - Curves.easeOut.transform(_back.value))));
  }

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final good = ((dx - 20) / 100).clamp(0.0, 1.0);
    final again = ((-dx - 20) / 100).clamp(0.0, 1.0);
    Widget stamp(String s, Color c) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: T.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: c, width: 2)),
          child: Text(s, style: txt(14, w: FontWeight.w900, c: c)),
        );
    final face = Container(
      key: ValueKey(widget.revealed),
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: T.surface, borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 50, offset: Offset(0, 20), spreadRadius: -20)]),
      child: widget.child,
    );
    return Semantics(
      button: !widget.revealed,
      label: widget.revealed ? null : 'Reveal the answer',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.revealed ? null : widget.onReveal,
        onHorizontalDragUpdate: widget.revealed ? (d) => setState(() => dx += d.delta.dx * 0.9) : null,
        onHorizontalDragEnd: widget.revealed
            ? (_) {
                if (dx > 110) {
                  widget.onSwipe('good');
                } else if (dx < -110) {
                  widget.onSwipe('again');
                } else {
                  _from = dx;
                  _back.forward(from: 0);
                }
              }
            : null,
        child: Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.rotate(
            angle: (dx / 200).clamp(-1.0, 1.0) * 0.17,
            child: Stack(children: [
              // Flip: the front turns away, then the answer turns in.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 360),
                switchInCurve: const Interval(0.5, 1, curve: Curves.easeOut),
                switchOutCurve: const Interval(0.5, 1, curve: Curves.easeIn),
                layoutBuilder: (current, previous) => Stack(children: [...previous, ?current]),
                // One continuous turn: the old face rotates 0 → 90°, the new one −90° → 0.
                transitionBuilder: (c, a) {
                  final incoming = c.key == ValueKey(widget.revealed);
                  return AnimatedBuilder(
                    animation: a,
                    child: c,
                    builder: (_, child) => Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0012)
                        ..rotateY((1 - a.value) * math.pi / 2 * (incoming ? -1 : 1)),
                      child: child,
                    ),
                  );
                },
                child: face,
              ),
              Positioned(right: 16, top: 16, child: IgnorePointer(child: Opacity(opacity: good, child: stamp('REMEMBERED', T.success)))),
              Positioned(left: 16, top: 16, child: IgnorePointer(child: Opacity(opacity: again, child: stamp('FORGOT', T.danger)))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PlanModal extends StatefulWidget {
  const _PlanModal();
  @override
  State<_PlanModal> createState() => _PlanModalState();
}

class _PlanModalState extends State<_PlanModal> with SingleTickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..forward();
  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.read<AppState>().profile;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text("This is how you'll understand Japanese in ${p.fluencyMonths} months", textAlign: TextAlign.center, style: txt(22, w: FontWeight.w900, h: 1.2)),
      const SizedBox(height: 20),
      for (var n = 0; n < 3; n++)
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 450 + n * 250),
          curve: Interval((200 + n * 250) / (450 + n * 250), 1),
          builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(-12 * (1 - v), 0), child: child)),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Text(const ['▶️', '🔖', '🔁'][n], style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Text(const ['Watch clips', 'Save words', 'Review daily'][n], style: txt(16, w: FontWeight.w800)),
            ]),
          ),
        ),
      const SizedBox(height: 4),
      Text("It's that simple. Show up for ${p.dailyMinutes} minutes a day and you'll surprise yourself.", textAlign: TextAlign.center, style: txt(15, w: FontWeight.w400, c: T.muted)),
      const SizedBox(height: 20),
      AnimatedBuilder(
        animation: _fill,
        builder: (context, _) {
          final ready = _fill.isCompleted;
          return GestureDetector(
            onTap: ready ? () => Navigator.of(context).pop() : null,
            child: Container(
              height: 56,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: T.primaryDim, borderRadius: BorderRadius.circular(16)),
              child: Stack(children: [
                FractionallySizedBox(widthFactor: _fill.value, child: Container(color: T.primary)),
                Center(child: Text("Let's do it!", style: txt(17, w: FontWeight.w800, c: T.primaryFg))),
              ]),
            ),
          );
        },
      ),
    ]);
  }
}
