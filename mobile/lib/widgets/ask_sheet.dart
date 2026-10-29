import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/ask.dart';
import '../data/paywall.dart';
import '../data/tour.dart';
import '../logic/logic.dart';
import '../services/ask_service.dart';
import '../services/analytics.dart';
import '../services/sync_service.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'ui.dart';
import 'tour.dart';
import '../i18n/i18n.dart';

/// "Ask Kizuki" chat about a line (and optionally a tapped word) — mirrors AskSheet.tsx.
Future<void> showAskSheet(BuildContext context, AskContext ctx) =>
    showMimiSheet<void>(context, (_) => AskSheet(ctx: ctx), maxHeightFactor: 0.92)
        .whenComplete(() => Tour.I.emit(TourEvent.askClosed));

class AskSheet extends StatefulWidget {
  final AskContext ctx;
  const AskSheet({super.key, required this.ctx});
  @override
  State<AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends State<AskSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<AskMessage> _msgs = [];
  late final bool _tourExample = Tour.I.running;
  AskRequest? _req;
  bool _waiting = false;
  String? _error;
  int _seq = 0;

  bool get _busy => _req != null;

  @override
  void initState() {
    super.initState();
    Analytics.track('ask_opened', {'has_word_context': widget.ctx.word != null});
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _req?.close();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      });

  Future<void> _send(String raw) async {
    final app = context.read<AppState>();
    final q = cleanQuestion(raw);
    if (q.isEmpty || _busy || !canAsk(app.premium.active, app.asksTodayCount, freeDailyAsks)) return;
    Analytics.track('ask_submitted', {'has_word_context': widget.ctx.word != null});
    _input.clear();
    final answerId = 'a${_seq++}';
    final req = AskRequest();
    setState(() {
      _msgs.add(AskMessage('u${_seq++}', 'user', q));
      _error = null;
      _waiting = true;
      _req = req;
    });
    _scrollDown();
    var text = '';
    var stopped = false;
    try {
      await for (final d in req.send(widget.ctx, List.of(_msgs))) {
        if (!mounted || _req != req) {
          stopped = true;
          break;
        }
        text += d;
        setState(() {
          _waiting = false;
          final i = _msgs.indexWhere((m) => m.id == answerId);
          if (i < 0) {
            _msgs.add(AskMessage(answerId, 'assistant', text));
          } else {
            _msgs[i] = _msgs[i].withText(text);
          }
        });
        _scrollDown();
      }
      if (_req != req) stopped = true;
      if (!mounted || stopped) return;
      if (text.trim().isEmpty) {
        setState(() => _error = askErrorText(500));
      } else {
        app.recordAsk();
      }
    } on AskFailure catch (e) {
      Analytics.track('ask_failed', {'category': 'request'});
      if (mounted && _req == req) setState(() => _error = e.message);
    } finally {
      req.close();
      if (mounted && _req == req) {
        setState(() {
          _req = null;
          _waiting = false;
        });
      }
    }
  }

  void _stop() {
    Analytics.track('ask_stopped');
    _req?.close();
    setState(() {
      _req = null;
      _waiting = false;
    });
  }

  /// Re-send the last question after a failure (the learner taps "Try again").
  void _retry() {
    final i = _msgs.lastIndexWhere((m) => m.role == 'user');
    if (i < 0) return;
    final q = _msgs[i].text;
    setState(() {
      _msgs.removeRange(i, _msgs.length);
      _error = null;
    });
    _send(q);
  }

  void _go(String path) {
    final router = GoRouter.of(context);
    Navigator.of(context).popUntil((r) => r is! PopupRoute);
    router.push(path);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final mq = MediaQuery.of(context);
    final insets = mq.viewInsets.bottom;
    final height = math.max(260.0, math.min(mq.size.height * (_tourExample ? 0.56 : 0.8), mq.size.height * 0.92 - 28 - insets));
    final signedIn = SyncService.I.session != null;
    final left = asksLeft(app.premium.active, app.asksTodayCount, freeDailyAsks);
    final word = widget.ctx.word;

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: TourAnchor(id: 'askPanel', enabled: _tourExample, child: SizedBox(
        height: height,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: Row(children: [
              const Mascot(MascotPose.think, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('Ask Kizuki'), style: txt(18, w: FontWeight.w900)),
                  word != null
                      ? Text.rich(TextSpan(children: trSpans('About [{word}] in this line', jp(13, c: T.foreground), {'word': word.head})), style: txt(13, c: T.muted))
                      : Text(tr('About this line'), style: txt(13, c: T.muted)),
                ]),
              ),
            ]),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: T.surface2.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.ctx.ja, maxLines: 2, overflow: TextOverflow.ellipsis, style: jp(15, h: 1.35)),
              if (widget.ctx.en.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(widget.ctx.en, maxLines: 2, overflow: TextOverflow.ellipsis, style: txt(13, w: FontWeight.w400, c: T.muted)),
              ],
            ]),
          ),
          if (_tourExample) Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(tr('EXAMPLE · NO QUESTION SENT'), style: txt(11, w: FontWeight.w800, c: T.muted)),
              const SizedBox(height: 10),
              _UserBubble(text: tr('What does this word mean here?')),
              _Bubble(text: word != null && word.gloss.isNotEmpty
                ? tr('**{surface}** here means **{gloss}**.\nThe sentence above shows the context.', {'surface': word.surface, 'gloss': word.gloss})
                : widget.ctx.en.isNotEmpty ? tr('This line means: **{en}**', {'en': widget.ctx.en}) : tr('Ask about grammar, meaning or another example from this line.')),
            ]),
          )) else if (!signedIn) Expanded(child: _locked()) else ...[
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                children: [
                  _Bubble(text: askGreeting(word)),
                  if (_msgs.isEmpty && left != 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 40, top: 2, bottom: 8),
                      child: Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final s in askSuggestions(word != null))
                          Press(
                            key: ValueKey('ask-suggestion-$s'),
                            onTap: () => _send(s),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(99), border: Border.all(color: T.border)),
                              child: Text(s, style: txt(13, w: FontWeight.w800)),
                            ),
                          ),
                      ]),
                    ),
                  for (final m in _msgs) m.role == 'user' ? _UserBubble(text: m.text) : _Bubble(text: m.text),
                  if (_waiting) const _Bubble(thinking: true),
                  if (_error != null) _ErrorBubble(text: _error!, onRetry: _retry),
                ],
              ),
            ),
            if (left == 0 && !_busy) _limit() else _composer(),
            // There are no free questions any more: the Premium card explains access.
            if (left == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: Text(
                  tr('AI answers can be wrong — double-check anything important.'),
                  textAlign: TextAlign.center,
                  style: txt(11, w: FontWeight.w600, c: T.faint),
                ),
              ),
          ],
        ]),
      )),
    );
  }

  Widget _composer() {
    final empty = cleanQuestion(_input.text).isEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: T.border))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: TextField(
            key: const ValueKey('ask-input'),
            controller: _input,
            minLines: 1,
            maxLines: 4,
            maxLength: askMaxChars,
            enabled: !_busy,
            textInputAction: TextInputAction.send,
            onSubmitted: _send,
            style: txt(15, w: FontWeight.w500),
            cursorColor: T.primary,
            decoration: InputDecoration(
              counterText: '',
              isDense: true,
              hintText: widget.ctx.word != null ? tr('Ask about this word…') : tr('Ask about this line…'),
              hintStyle: txt(15, w: FontWeight.w500, c: T.faint),
              filled: true,
              fillColor: T.surface2,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: T.border, width: 2)),
              disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: T.border, width: 2)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: T.primary, width: 2)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: _busy ? tr('Stop answer') : tr('Send question'),
          child: Press(
            key: ValueKey(_busy ? 'ask-stop' : 'ask-send'),
            onTap: _busy ? _stop : (empty ? null : () => _send(_input.text)),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: _busy ? T.surface2 : (empty ? T.primaryDim : T.primary), shape: BoxShape.circle),
              child: Icon(_busy ? LucideIcons.square : LucideIcons.arrowUp, size: _busy ? 16 : 20, color: _busy ? T.foreground : (empty ? T.primaryDimFg : T.primaryFg)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _limit() => Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(color: T.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Text(tr('Premium is required to ask Kizuki'), textAlign: TextAlign.center, style: txt(15, w: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(tr('Premium gives you unlimited answers from Kizuki.'), textAlign: TextAlign.center, style: txt(13, w: FontWeight.w500, c: T.muted)),
          const SizedBox(height: 10),
          Button3D(label: tr('See plans'), height: 48, onPressed: () => _go('/trial')),
        ]),
      );

  Widget _locked() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(children: [
          const Mascot(MascotPose.wave, size: 96),
          const SizedBox(height: 12),
          Text(tr('Ask Kizuki anything'), textAlign: TextAlign.center, style: txt(20, w: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(tr('Sign in with your Premium account to ask about this line. Your words and streak sync too.'),
              textAlign: TextAlign.center, style: txt(15, w: FontWeight.w500, c: T.muted, h: 1.4)),
          const SizedBox(height: 16),
          Button3D(key: const ValueKey('ask-signup'), label: tr('Sign in'), height: 52, onPressed: () => _go('/account')),
        ]),
      );
}

/// Light markdown: **bold** and "- " bullets, one paragraph per line.
Widget askRichText(String s, TextStyle base) {
  final lines = s.split('\n').where((l) => l.trim().isNotEmpty).toList();
  List<InlineSpan> spans(String line) {
    final parts = line.split('**');
    return [for (var i = 0; i < parts.length; i++) if (parts[i].isNotEmpty) TextSpan(text: parts[i], style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w900) : null)];
  }

  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    for (var i = 0; i < lines.length; i++)
      Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
        child: RegExp(r'^\s*[-*•]\s+').hasMatch(lines[i])
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('•  ', style: base),
                Expanded(child: Text.rich(TextSpan(children: spans(lines[i].replaceFirst(RegExp(r'^\s*[-*•]\s+'), ''))), style: base)),
              ])
            : Text.rich(TextSpan(children: spans(lines[i].trim())), style: base),
      ),
  ]);
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool thinking;
  const _Bubble({this.text = '', this.thinking = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Mascot(MascotPose.face, size: 30),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: T.surface2,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              ),
              child: thinking
                  ? Row(mainAxisSize: MainAxisSize.min, children: [const _Dots(), const SizedBox(width: 8), Text(tr('Kizuki is thinking…'), style: txt(14, w: FontWeight.w600, c: T.muted))])
                  : askRichText(text, txt(15, w: FontWeight.w500, h: 1.45)),
            ),
          ),
          const SizedBox(width: 24),
        ]),
      );
}

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 48),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: T.primary,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(4), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
            ),
            child: Text(tr(text), style: txt(15, w: FontWeight.w700, c: T.primaryFg, h: 1.4)),
          ),
        ),
      );
}

class _ErrorBubble extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;
  const _ErrorBubble({required this.text, required this.onRetry});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(left: 40, bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(color: T.dangerSoft, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          const Icon(LucideIcons.circleAlert, size: 16, color: T.danger),
          const SizedBox(width: 8),
          Expanded(child: Text(tr(text), style: txt(14, w: FontWeight.w600, h: 1.35))),
          Press(
            key: const ValueKey('ask-retry'),
            onTap: onRetry,
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Text(tr('Try again'), style: txt(14, w: FontWeight.w900, c: T.primary))),
          ),
        ]),
      );
}

class _Dots extends StatefulWidget {
  const _Dots();
  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: T.muted.withValues(alpha: 0.35 + 0.65 * (0.5 + 0.5 * math.sin((_c.value * 2 * math.pi) - i * 0.9)).clamp(0.0, 1.0)),
                shape: BoxShape.circle,
              ),
            ),
        ]),
      );
}
