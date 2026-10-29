import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/content.dart';
import '../data/models.dart' as m;
import '../data/tour.dart' show TourEvent;
import '../logic/logic.dart' show pickTourWord;
import '../services/haptics.dart';
import '../services/analytics.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'clip_player.dart';
import 'clip_sheets.dart';
import 'toast.dart';
import 'tour.dart';
import 'transcript.dart';
import 'ui.dart';
import 'word_card.dart';
import '../i18n/i18n.dart';

String fmtTime(double s) {
  final v = math.max(0, s).floor();
  return '${v ~/ 60}:${(v % 60).toString().padLeft(2, '0')}';
}

/// After the learner scrolls the transcript, auto-follow waits this long (ClipView.tsx: FOLLOW_PAUSE_MS).
const int transcriptFollowPauseMs = 4000;

/// One clip: official YouTube player + controls + interactive transcript + word card.
/// Mirrors ClipView.tsx.
class ClipView extends StatefulWidget {
  final m.Clip clip;
  final Content content;
  final bool active;
  final double bottomInset;

  /// Only the feed's active clip carries the welcome-tour spotlight targets.
  final bool tourTargets;

  /// In the feed a vertical swipe ANYWHERE on the clip changes clips (TikTok rule), so the
  /// transcript never takes drags there — it only follows the spoken line by itself.
  /// On the stand-alone clip page the learner can scroll it freely.
  final bool inFeed;
  /// The next clip in the feed: its player loads and cues ahead of the swipe (never plays).
  final bool warm;
  const ClipView({super.key, required this.clip, required this.content, required this.active, this.bottomInset = 96, this.tourTargets = false, this.inFeed = false, this.warm = false});
  @override
  State<ClipView> createState() => _ClipViewState();
}

class _ClipViewState extends State<ClipView> {
  final _player = GlobalKey<ClipPlayerState>();
  final _scroll = ScrollController();
  late List<GlobalKey> _lineKeys = List.generate(widget.clip.lines.length, (_) => GlobalKey());
  late double time = widget.clip.start;
  bool playing = false;
  double rate = 1;
  int? loopLine;
  m.ClipNotes? notes;
  (int, int)? sel;
  int _lastLine = -1;

  // last manual transcript scroll (clip page only)
  int _userScrollAt = 0;

  // watch time
  bool _marked = false;
  int _played = 0, _pending = 0;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    if (widget.active) _activate();
    Tour.I.addListener(_onTour);
    Content.shown.addListener(_onContentLanguage);
  }

  /// Welcome tour: hold the clip still while it asks you to tap a word in it, with that word's
  /// line in view (a word scrolled out of the transcript can't be spotlit).
  void _onTour() {
    if (!(widget.active && widget.tourTargets && Tour.I.step?.id == 'tapWord')) return;
    _player.currentState?.pause();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final w = _tourWord(context.read<AppState>(), activeLineIndex(widget.clip, time));
      if (w != null) _followLine(w.$1, force: true);
    });
  }

  @override
  void didUpdateWidget(covariant ClipView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clip.id != widget.clip.id) _lineKeys = List.generate(widget.clip.lines.length, (_) => GlobalKey());
    if (oldWidget.active != widget.active) {
      if (widget.active) {
        _activate();
      } else {
        _flushWatch();
        setState(() {
          loopLine = null;
          sel = null;
          time = widget.clip.start;
          _marked = false;
          _played = 0;
        });
      }
    }
  }

  @override
  void dispose() {
    Content.shown.removeListener(_onContentLanguage);
    Tour.I.removeListener(_onTour);
    _tick?.cancel();
    _flushWatch(notify: false);
    _scroll.dispose();
    super.dispose();
  }

  /// The library switched language: the open clip's explanations follow.
  void _onContentLanguage() {
    if (!widget.active) return;
    widget.content.notes(widget.clip.id).then((n) {
      if (mounted) setState(() => notes = n);
    });
  }

  void _activate() {
    Analytics.track('clip_viewed', {'clip_id': widget.clip.id, 'source': widget.inFeed ? 'feed' : 'clip', 'jlpt': widget.clip.level});
    widget.content.notes(widget.clip.id).then((n) {
      if (mounted) setState(() => notes = n);
    });
  }

  void _markWatched() {
    if (_marked) return;
    _marked = true;
    context.read<AppState>().markClipWatched(widget.clip.id);
  }

  void _flushWatch({bool notify = true}) {
    if (_pending > 0) {
      final p = _pending;
      _pending = 0;
      if (notify || mounted) context.read<AppState>().addWatchSeconds(p);
    }
  }

  void _onPlaying(bool v) {
    if (v == playing) return;
    if (widget.active) Analytics.track(v ? 'clip_played' : 'clip_paused', {'clip_id': widget.clip.id});
    setState(() => playing = v);
    _tick?.cancel();
    if (v) {
      final dur = widget.clip.duration;
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        _played++;
        _pending++;
        if (_played >= dur * 0.8) _markWatched();
        if (_pending >= 10) _flushWatch();
      });
    } else {
      _flushWatch();
    }
  }

  void _onTime(double t) {
    if (!mounted) return;
    setState(() => time = t);
    final current = activeLineIndex(widget.clip, t);
    if (current != _lastLine && current >= 0) {
      _lastLine = current;
      _followLine(current);
    }
  }

  /// Keep the spoken line in view by scrolling ONLY this transcript. (Scrollable.ensureVisible
  /// also scrolled the feed's PageView, so the whole screen wobbled and swipes misfired.)
  void _followLine(int i, {bool force = false}) {
    if (i >= _lineKeys.length || !_scroll.hasClients) return;
    if (!force && DateTime.now().millisecondsSinceEpoch - _userScrollAt < transcriptFollowPauseMs) return;
    final box = _lineKeys[i].currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;
    final pos = _scroll.position;
    final target = viewport.getOffsetToReveal(box, 0.25).offset.clamp(pos.minScrollExtent, pos.maxScrollExtent);
    if ((pos.pixels - target).abs() < 24) return;
    _scroll.animateTo(target, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
  }

  /// A manual transcript scroll pauses auto-follow for a moment (clip page only).
  bool _onTranscriptScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if ((n is ScrollStartNotification && n.dragDetails != null) || (n is ScrollUpdateNotification && n.dragDetails != null)) {
      _userScrollAt = DateTime.now().millisecondsSinceEpoch;
    }
    return false;
  }

  String _statusOf(AppState app, m.Word w) => app.tokenStatus(keyOfWord(w));

  void _onWord(int li, int wi) {
    Analytics.track('word_card_opened', {'clip_id': widget.clip.id, 'line_index': li, 'word_index': wi});
    final app = context.read<AppState>();
    Haptics.select();
    setState(() => sel = (li, wi));
    _player.currentState?.pause();
    if (app.settings.autoSave) {
      final w = widget.clip.lines[li].words[wi];
      final k = keyOfWord(w);
      if (!app.isSaved(k)) app.saveWord(wordInputOf(widget.clip, li, wi, widget.content, notes));
    }
    showWordCard(context, clip: widget.clip, line: li, idx: wi, content: widget.content, notes: notes).whenComplete(() {
      if (mounted) setState(() => sel = null);
      Tour.I.emit(TourEvent.cardClosed);
    });
    Tour.I.emit(TourEvent.word);
  }

  void _seekLine(int li) {
    Analytics.track('clip_line_replayed', {'clip_id': widget.clip.id});
    if (li < 0 || li >= widget.clip.lines.length) return;
    _player.currentState?.seek(math.max(widget.clip.start, widget.clip.lines[li].start - 0.1));
  }

  /// The word the welcome tour asks you to tap: a new content word from the current line on.
  (int, int)? _tourWord(AppState app, int from) {
    final c = widget.clip;
    return pickTourWord(
      [for (final l in c.lines) [for (final w in l.words) (p: w.p, d: w.d)]],
      from,
      (li, wi) => _statusOf(app, c.lines[li].words[wi]) == 'new',
    );
  }

  List<WordInput> _unknown(AppState app) {
    final out = <WordInput>[];
    final seen = <String>{};
    final c = widget.clip;
    for (var li = 0; li < c.lines.length; li++) {
      for (var wi = 0; wi < c.lines[li].words.length; wi++) {
        final w = c.lines[li].words[wi];
        if (w.isPunct) continue;
        final k = keyOfWord(w);
        if (seen.contains(k) || _statusOf(app, w) != 'new') continue;
        seen.add(k);
        out.add(wordInputOf(c, li, wi, widget.content, notes));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final clip = widget.clip;
    final video = widget.content.videos[clip.videoId];
    final savedClip = app.savedClips.contains(clip.id);
    final dur = clip.duration;
    final rel = math.min(dur, math.max(0.0, time - clip.start));
    final current = activeLineIndex(clip, time);
    final ll = loopLine != null ? clip.lines[loopLine!] : null;
    final loopRange = ll != null ? (ll.start - 0.1, ll.end + 0.15) : null;
    final unknown = _unknown(app);

    final tourOn = widget.active && widget.tourTargets;
    final tourWord = tourOn ? _tourWord(app, current) : null;
    return Column(
      children: [
        TourAnchor(
          id: 'player',
          enabled: tourOn,
          child: ClipPlayer(key: _player, clip: clip, active: widget.active, warm: widget.warm, rate: rate, onTime: _onTime, onPlayingChange: _onPlaying, onLoop: _markWatched, loopRange: loopRange),
        ),
        SizedBox(
          height: 3,
          child: Stack(
            children: [
              Container(color: T.surface2),
              FractionallySizedBox(
                widthFactor: dur <= 0 ? 0 : (rel / dur).clamp(0, 1),
                child: Container(color: T.primary),
              ),
            ],
          ),
        ),
        TourAnchor(id: 'controls', enabled: tourOn, child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          child: Row(
            children: [
              _IconBtn(icon: playing ? LucideIcons.pause : LucideIcons.play, label: playing ? tr('Pause') : tr('Play'), color: T.foreground, onTap: () => _player.currentState?.toggle()),
              SizedBox(
                width: 78,
                child: Text(
                  '${fmtTime(rel)} / ${fmtTime(dur)}',
                  style: txt(13, w: FontWeight.w700, c: T.muted),
                ),
              ),
              const Spacer(),
              _IconBtn(icon: LucideIcons.rotateCcw, label: tr('Replay line'), onTap: () => _seekLine(math.max(0, current))),
              _IconBtn(
                icon: LucideIcons.repeat1,
                label: tr('Loop line'),
                color: loopLine != null ? T.primary : T.muted,
                onTap: () => setState(() => loopLine = loopLine != null ? null : math.max(0, current)),
              ),
              Semantics(
                button: true,
                label: tr('Playback speed'),
                child: Press(
                  onTap: () => setState(() => rate = speeds[(speeds.indexOf(rate) + 1) % speeds.length]),
                  child: Container(
                    height: 32,
                    constraints: const BoxConstraints(minWidth: 44),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: rate != 1 ? T.primary.withValues(alpha: 0.15) : Colors.transparent, borderRadius: BorderRadius.circular(99)),
                    child: Text(
                      speedLabel(rate),
                      style: txt(13, w: FontWeight.w900, c: rate != 1 ? T.primary : T.muted),
                    ),
                  ),
                ),
              ),
              _IconBtn(
                icon: LucideIcons.bookmark,
                label: savedClip ? tr('Unsave clip') : tr('Save clip'),
                color: savedClip ? T.primary : T.muted,
                onTap: () {
                  app.toggleSavedClip(clip.id);
                  if (!savedClip) Haptics.light();
                  if (!savedClip) toast(tr('Clip saved'), description: tr('Find it in Profile → Saved'), icon: '🔖');
                },
              ),
              // "Aa", like the Display sheet's name.
              Semantics(
                button: true,
                label: tr('Display options'),
                child: Press(
                  onTap: () => showDisplaySheet(context, rate: () => rate, onRate: (r) => setState(() => rate = r)),
                  child: SizedBox(width: 40, height: 40, child: Center(child: Text(tr('Aa'), style: txt(15, w: FontWeight.w900, c: T.muted)))),
                ),
              ),
            ],
          ),
        )),
        Expanded(
          child: NotificationListener<ScrollNotification>(
          onNotification: _onTranscriptScroll,
          child: SingleChildScrollView(
            controller: _scroll,
            // Feed: no drag recognizers here, so the feed's pager owns every vertical swipe.
            physics: widget.inFeed ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
            padding: EdgeInsets.only(bottom: widget.bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          clip.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: txt(14, w: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          tr('JLPT {level}', {'level': clip.level}),
                          style: txt(11, w: FontWeight.w900, c: T.muted),
                        ),
                      ),
                    ],
                  ),
                ),
                if (video != null)
                  GestureDetector(
                    onTap: () => launchUrl(Uri.parse(watchUrl(clip.videoId, clip.start)), mode: LaunchMode.externalApplication),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        tr('{channel} · Watch on YouTube', {'channel': video.channel}),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: txt(12, w: FontWeight.w700, c: T.faint),
                      ),
                    ),
                  ),
                Transcript(
                  clip: clip,
                  tourWord: tourWord,
                  time: time,
                  settings: app.settings,
                  statusOf: (w) => _statusOf(app, w),
                  levelOf: (w) => app.tokenLevel(keyOfWord(w)),
                  selected: sel,
                  onWord: _onWord,
                  onLine: _seekLine,
                  lineKeys: _lineKeys,
                  onLineMenu: (li) => showLineMenu(
                    context,
                    clip: clip,
                    line: li,
                    notes: notes,
                    onReplay: () => _seekLine(li),
                    onLoop: () => setState(() => loopLine = loopLine == li ? null : li),
                    looping: loopLine == li,
                  ),
                ),
                if (unknown.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Press(
                      onTap: () {
                        app.markKnown(unknown);
                        toast(trn(unknown.length, '{n} word marked as known', '{n} words marked as known'), icon: '✅');
                      },
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: T.border, width: 2),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.checkCheck, size: 20, color: T.success),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                trn(unknown.length, 'Mark remaining {n} word as known', 'Mark remaining {n} words as known'),
                                overflow: TextOverflow.ellipsis,
                                style: txt(15, w: FontWeight.w800, c: T.muted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ),
        ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.label, required this.onTap, this.color = T.muted});
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Press(
      onTap: onTap,
      child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 18, color: color)),
    ),
  );
}
