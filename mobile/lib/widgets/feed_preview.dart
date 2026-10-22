import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../data/models.dart' as m;
import '../screens/plan.dart' show feedOrder;
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'ui.dart';

/// The learner's own first clips, playing inside the trial screen's phone mockup: the
/// subtitles follow along, a finger taps a word, its card slides up, then it swipes to the
/// next clip. Uses the YouTube thumbnail only (never the video). Mirrors
/// src/components/mimi/FeedPreview.tsx.
class FeedPreview extends StatefulWidget {
  const FeedPreview({super.key});
  @override
  State<FeedPreview> createState() => _FeedPreviewState();
}

/// One clip line to demo: the line, the word the finger taps, and what its card shows.
class PreviewDemo {
  final m.Clip clip;
  final int line, word;
  final String channel, gloss;
  const PreviewDemo(this.clip, this.line, this.word, this.channel, this.gloss);
}

const _tappable = {'noun', 'verb', 'adjective'};

/// A short, translated line with a dictionary word to tap (FeedPreview.tsx: previewDemoOf).
PreviewDemo? previewDemoOf(Content c, m.Clip clip) {
  for (var li = 0; li < clip.lines.length; li++) {
    final l = clip.lines[li];
    final real = l.words.where((w) => !w.isPunct).length;
    if (real < 3 || real > 9 || l.en.trim().isEmpty) continue;
    for (var wi = 0; wi < l.words.length; wi++) {
      final w = l.words[wi];
      if (w.isPunct || w.d == null || !_tappable.contains(w.p) || w.s.characters.length < 2) continue;
      final e = c.dict[w.d];
      if (e == null || e.gloss.isEmpty) continue;
      return PreviewDemo(clip, li, wi, c.videos[clip.videoId]?.channel ?? '', e.gloss);
    }
  }
  return null;
}

/// Up to [n] demos from the learner's personal feed order.
List<PreviewDemo> previewDemos(Content c, List<String> order, {int n = 3}) {
  final out = <PreviewDemo>[];
  for (final id in order) {
    final clip = c.byId[id];
    final d = clip == null ? null : previewDemoOf(c, clip);
    if (d != null) out.add(d);
    if (out.length >= n) break;
  }
  return out;
}

/// The lines shown after the demo line: up to [n], skipping repeats of a sentence already on
/// screen (teachers often say a line twice; in a demo that just looks like a glitch).
List<m.Line> previewFollowing(m.Clip clip, int line, {int n = previewFollowingLines}) {
  final seen = {clip.lines[line].ja.trim()};
  final out = <m.Line>[];
  for (var li = line + 1; li < clip.lines.length && out.length < n; li++) {
    final l = clip.lines[li];
    if (seen.add(l.ja.trim())) out.add(l);
  }
  return out;
}

/// Loop timing (fractions of [previewLoopMs]).
const previewLoopMs = 7000;
/// How many transcript lines after the demo line the mockup shows (FeedPreview.tsx: PREVIEW_FOLLOWING_LINES).
const previewFollowingLines = 3;

const _karaokeEnd = 0.40, _fingerIn = 0.47, _cardIn = 0.50, _cardOut = 0.76, _swipeFrom = 0.82;

class _FeedPreviewState extends State<FeedPreview> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(milliseconds: previewLoopMs));
  List<PreviewDemo>? demos;
  int i = 0;
  final _stackKey = GlobalKey();
  final _wordKey = GlobalKey();
  Offset? _wordAt;

  @override
  void initState() {
    super.initState();
    Content.load().then((c) {
      if (!mounted) return;
      final d = previewDemos(c, feedOrder(c, context.read<AppState>()));
      setState(() => demos = d);
      if (d.isNotEmpty) _t.forward(from: 0);
    }, onError: (_) {
      if (mounted) setState(() => demos = const []);
    });
    _t.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted && (demos?.isNotEmpty ?? false)) {
        setState(() {
          i = (i + 1) % demos!.length;
          _wordAt = null;
        });
        _t.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  void _measureWord() {
    final stack = _stackKey.currentContext?.findRenderObject();
    final word = _wordKey.currentContext?.findRenderObject();
    if (stack is! RenderBox || word is! RenderBox || !word.attached) return;
    final at = word.localToGlobal(word.size.center(Offset.zero), ancestor: stack);
    final o = _wordAt;
    if (o == null || (o - at).distance > 0.5) setState(() => _wordAt = at);
  }

  @override
  Widget build(BuildContext context) {
    final d = demos;
    if (d == null) return Container(color: T.stage);
    if (d.isEmpty) return const _StaticPreview();
    final demo = d[i % d.length];
    final still = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final v = still ? 0.6 : _t.value;
        // Where the tapped word is right now (fonts and the thumbnail can still move it).
        if (_wordAt == null || (v > _karaokeEnd - 0.03 && v < _cardIn + 0.07)) WidgetsBinding.instance.addPostFrameCallback((_) => _measureWord());
        final line = demo.clip.lines[demo.line];
        final realIdx = [for (var k = 0; k < line.words.length; k++) if (!line.words[k].isPunct) k];
        final spoken = v < _karaokeEnd ? realIdx[math.min(realIdx.length - 1, (v / _karaokeEnd * realIdx.length).floor())] : -1;
        final tapped = v >= _fingerIn + 0.01;
        final cardV = _ramp(v, _cardIn, _cardIn + 0.04) * (1 - _ramp(v, _cardOut, _cardOut + 0.04));
        final swipeV = _ramp(v, _swipeFrom, 1.0);
        return Stack(key: _stackKey, clipBehavior: Clip.hardEdge, children: [
          // The feed page; it scrolls up as the finger swipes.
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(0, -40 * Curves.easeIn.transform(swipeV)),
              child: Opacity(
                opacity: 1 - 0.6 * swipeV,
                child: _Page(demo: demo, spoken: spoken, selected: tapped && cardV > 0, saved: tapped, wordKey: _wordKey, progress: v),
              ),
            ),
          ),
          // Word card.
          if (cardV > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FractionalTranslation(translation: Offset(0, 1 - Curves.easeOutCubic.transform(cardV)), child: _Card(demo: demo)),
            ),
          // Finger: tap the word, then swipe up.
          if (!still && _wordAt != null && v >= _karaokeEnd && v < _cardIn + 0.06) _finger(Offset.lerp(_wordAt! + const Offset(30, 60), _wordAt!, Curves.easeOut.transform(_ramp(v, _karaokeEnd, _fingerIn)))!, press: _ramp(v, _fingerIn - 0.01, _fingerIn + 0.02), opacity: _ramp(v, _karaokeEnd, _karaokeEnd + 0.03) * (1 - _ramp(v, _cardIn - 0.01, _cardIn + 0.03))),
          if (!still && v >= _swipeFrom - 0.02)
            LayoutBuilder(builder: (_, c) => _finger(Offset(c.maxWidth * 0.6, c.maxHeight * (0.78 - 0.4 * Curves.easeInOut.transform(swipeV))), press: 1, opacity: 1 - _ramp(v, 0.96, 1.0))),
        ]);
      },
    );
  }

  Widget _finger(Offset at, {required double press, required double opacity}) => Positioned(
        left: at.dx - 10,
        top: at.dy - 4,
        child: IgnorePointer(
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Stack(clipBehavior: Clip.none, children: [
              if (press > 0 && press < 1)
                Positioned(
                  left: -14 + 10 - 18 * press,
                  top: -14 + 4 - 18 * press,
                  child: Container(
                    width: 28 + 36 * press,
                    height: 28 + 36 * press,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: T.primary.withValues(alpha: 1 - press), width: 3)),
                  ),
                ),
              Transform.scale(scale: 1 - 0.12 * math.sin(press * math.pi), child: Icon(LucideIcons.pointer, size: 30, color: T.foreground, shadows: [Shadow(color: T.stage.withValues(alpha: 0.8), blurRadius: 10)])),
            ]),
          ),
        ),
      );
}

double _ramp(double v, double a, double b) => ((v - a) / (b - a)).clamp(0.0, 1.0);

class _Page extends StatelessWidget {
  final PreviewDemo demo;
  final int spoken;
  final bool selected, saved;
  final GlobalKey wordKey;
  final double progress;
  const _Page({required this.demo, required this.spoken, required this.selected, required this.saved, required this.wordKey, required this.progress});

  @override
  Widget build(BuildContext context) {
    final clip = demo.clip;
    final line = clip.lines[demo.line];
    // The lines after the demo line fill the page like the real feed's transcript.
    final after = previewFollowing(clip, demo.line);
    return ColoredBox(
      color: T.stage,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(children: [
            Text('For you', style: txt(11, w: FontWeight.w900)),
            const SizedBox(width: 10),
            Text('Explore', style: txt(11, w: FontWeight.w800, c: T.faint)),
            const Spacer(),
            const Icon(LucideIcons.flame, size: 12, color: T.primary),
            Text(' 1', style: txt(10, w: FontWeight.w900, c: T.primary)),
          ]),
        ),
        Stack(children: [
          ClipThumb(clip.thumb),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(height: 3, color: T.surface3, alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: progress.clamp(0.02, 1.0), child: Container(color: T.primary))),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
          child: Text(demo.channel.isEmpty ? 'YouTube' : '${demo.channel} · YouTube', maxLines: 1, overflow: TextOverflow.ellipsis, style: txt(9, w: FontWeight.w700, c: T.faint)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          child: Wrap(runSpacing: 4, children: [
            for (var k = 0; k < line.words.length; k++) _token(line.words[k], k),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Text(line.en, maxLines: 2, overflow: TextOverflow.ellipsis, style: txt(10.5, w: FontWeight.w600, c: T.muted, h: 1.3)),
        ),
        Expanded(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (r) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)], stops: [0, 0.7, 1]).createShader(r),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final l in after)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.ja, maxLines: 1, overflow: TextOverflow.ellipsis, style: jp(13, c: T.faint)),
                      if (l.en.isNotEmpty) Text(l.en, maxLines: 1, overflow: TextOverflow.ellipsis, style: txt(9.5, w: FontWeight.w600, c: T.faint)),
                    ]),
                  ),
              ]),
            ),
          ),
        ),
        Container(
          height: 34,
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          decoration: BoxDecoration(color: T.surface, borderRadius: BorderRadius.circular(99)),
          child: const Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            Icon(LucideIcons.play, size: 14, color: T.primary),
            Icon(LucideIcons.bookmark, size: 14, color: T.faint),
            Icon(LucideIcons.repeat, size: 14, color: T.faint),
            Icon(LucideIcons.user, size: 14, color: T.faint),
          ]),
        ),
      ]),
    );
  }

  Widget _token(m.Word w, int k) {
    if (w.isPunct) return Text(w.s, style: jp(15, h: 1.5));
    final isDemo = k == demo.word;
    final status = isDemo && saved ? 'learning' : (_tappable.contains(w.p) ? 'new' : 'known');
    final underline = status == 'new' ? T.info : (status == 'learning' ? T.learning : T.stage.withValues(alpha: 0));
    return Container(
      key: isDemo ? wordKey : null,
      margin: const EdgeInsets.only(right: 1),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: isDemo && selected ? T.primary.withValues(alpha: 0.25) : null,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: k == spoken ? T.success : T.stage.withValues(alpha: 0), width: 1.5),
      ),
      child: Container(
        padding: const EdgeInsets.only(bottom: 1),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: underline, width: 2))),
        child: Text(w.s, style: jp(15, w: FontWeight.w700, c: isDemo && selected ? T.primary : T.foreground, h: 1.3)),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final PreviewDemo demo;
  const _Card({required this.demo});
  @override
  Widget build(BuildContext context) {
    final w = demo.clip.lines[demo.line].words[demo.word];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      decoration: const BoxDecoration(color: T.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 28, height: 3, decoration: BoxDecoration(color: T.surface3, borderRadius: BorderRadius.circular(99)))),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Flexible(child: Text(w.b.isNotEmpty ? w.b : w.s, maxLines: 1, overflow: TextOverflow.ellipsis, style: jp(22, w: FontWeight.w900, h: 1.1))),
          if (w.r.isNotEmpty) ...[const SizedBox(width: 6), Text(w.r, style: jp(11, c: T.muted))],
        ]),
        const SizedBox(height: 2),
        Text(demo.gloss, maxLines: 2, overflow: TextOverflow.ellipsis, style: txt(13, w: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(children: [
          _chip('Meaning', on: true),
          const SizedBox(width: 6),
          _chip('Explain', on: false),
          const Spacer(),
          const Icon(LucideIcons.check, size: 12, color: T.success),
          Text(' Saved', style: txt(10, w: FontWeight.w900, c: T.success)),
        ]),
      ]),
    );
  }

  Widget _chip(String label, {required bool on}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: on ? T.primary : T.surface2, borderRadius: BorderRadius.circular(99)),
        child: Text(label, style: txt(10, w: FontWeight.w900, c: on ? T.primaryFg : T.muted)),
      );
}

/// Shown if the library couldn't load: the same scene, drawn.
class _StaticPreview extends StatelessWidget {
  const _StaticPreview();
  @override
  Widget build(BuildContext context) => ColoredBox(
        color: T.stage,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '今日', style: jp(16, c: T.primary).copyWith(backgroundColor: T.primary.withValues(alpha: 0.25))),
                const TextSpan(text: 'は'),
                TextSpan(text: '楽しかった', style: jp(16).copyWith(decoration: TextDecoration.underline, decorationColor: T.learning, decorationThickness: 2)),
                const TextSpan(text: 'ね！'),
              ]),
              style: jp(16, h: 1.3),
            ),
            const SizedBox(height: 6),
            Text("Today was fun, wasn't it!", style: txt(12, w: FontWeight.w400, c: T.muted)),
          ]),
        ),
      );
}
