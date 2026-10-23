import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../data/models.dart' as m;
import '../theme/tokens.dart';
import 'common.dart';
import 'ui.dart';
import 'playback_loop.dart';

/// Learner-facing message for a YouTube player error — same copy as playerErrorMessage() in youtube.ts.
String playerErrorMessage(YoutubeError e) => switch (e) {
      YoutubeError.notEmbeddable || YoutubeError.sameAsNotEmbeddable => "The owner doesn't allow this video to play here.",
      YoutubeError.videoNotFound => 'This video was removed from YouTube.',
      _ => "This clip couldn't load. Check your connection.",
    };

String watchUrl(String videoId, double t) => 'https://www.youtube.com/watch?v=$videoId&t=${t.floor()}s';

/// One clip of a YouTube video through the official IFrame player (youtube_player_iframe).
/// Created only for the active feed item; inactive items show the thumbnail. Loops
/// clip.start → clip.end (or a single line). Mirrors ClipPlayer.tsx.
class ClipPlayer extends StatefulWidget {
  final m.Clip clip;
  final bool active;
  final double rate;
  final ValueChanged<double> onTime;
  final ValueChanged<bool> onPlayingChange;
  final VoidCallback onLoop;
  final (double, double)? loopRange;
  const ClipPlayer({super.key, required this.clip, required this.active, required this.rate, required this.onTime, required this.onPlayingChange, required this.onLoop, this.loopRange});
  @override
  State<ClipPlayer> createState() => ClipPlayerState();
}

class ClipPlayerState extends State<ClipPlayer> {
  YoutubePlayerController? _c;
  StreamSubscription<YoutubePlayerValue>? _valueSub;
  StreamSubscription<YoutubeVideoState>? _timeSub;
  PlayerState _state = PlayerState.unStarted;
  bool _ready = false;
  bool _tapped = false;
  String? _error;
  double _time = 0;
  late PlaybackLoopGuard _loop;
  bool _startupCorrectionIssued = false;

  @override
  void initState() {
    super.initState();
    _time = widget.clip.start;
    if (widget.active) _create();
  }

  @override
  void didUpdateWidget(covariant ClipPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active || oldWidget.clip.id != widget.clip.id) {
      _destroy();
      if (widget.active) _create();
    }
    if (oldWidget.rate != widget.rate && _ready) _c?.setPlaybackRate(widget.rate);
  }

  @override
  void dispose() {
    _destroy(notify: false);
    super.dispose();
  }

  void _create() {
    final clip = widget.clip;
    _error = null;
    _ready = false;
    _tapped = false;
    _time = clip.start;
    _loop = PlaybackLoopGuard(clip.start);
    _startupCorrectionIssued = false;
    final c = YoutubePlayerController.fromVideoId(
      videoId: clip.videoId,
      autoPlay: true,
      startSeconds: clip.start,
      endSeconds: clip.end + 1,
      params: const YoutubePlayerParams(
        showControls: false,
        enableKeyboard: false,
        showFullscreenButton: false,
        playsInline: true,
        showVideoAnnotations: false,
        enableCaption: false,
        strictRelatedVideos: true,
        privacyEnhancedMode: true,
        videoStateUpdateInterval: 100,
      ),
    );
    _c = c;
    _valueSub = c.stream.listen(_onValue);
    _timeSub = c.videoStateStream.listen(_onPosition);
  }

  void _destroy({bool notify = true}) {
    _valueSub?.cancel();
    _timeSub?.cancel();
    _valueSub = null;
    _timeSub = null;
    final c = _c;
    _c = null;
    if (c != null) unawaited(c.close());
    _ready = false;
    _state = PlayerState.unStarted;
    if (notify) widget.onPlayingChange(false);
  }

  void _onValue(YoutubePlayerValue v) {
    if (!mounted) return;
    if (v.error != YoutubeError.none) {
      setState(() => _error = playerErrorMessage(v.error));
      return;
    }
    final st = v.playerState;
    if (st != _state) {
      // Not in the shipped build (the emulator test, a profile build, reads it).
      if (!kReleaseMode) debugPrint('KIZUKI_PLAYER ${widget.clip.id} ${st.name} at ${_time.toStringAsFixed(1)}s');
      final wasReady = _ready;
      setState(() {
        _state = st;
        if (st == PlayerState.playing || st == PlayerState.paused || st == PlayerState.buffering) _ready = true;
      });
      if (!wasReady && _ready) _c?.setPlaybackRate(widget.rate);
      // Hide YouTube's own captions: our transcript is the subtitle. enableCaption=false
      // is ignored when the viewer/channel has captions on, so unload the module.
      if (st == PlayerState.playing || st == PlayerState.buffering) _hideYouTubeCaptions();
      widget.onPlayingChange(st == PlayerState.playing);
      final range = widget.loopRange;
      final start = range?.$1 ?? widget.clip.start;
      final end = range?.$2 ?? widget.clip.end;
      if (st == PlayerState.ended && _loop.shouldLoop(_time, start, end, playing: false, ended: true)) {
        _seekTo(start);
        _c?.playVideo();
        if (range == null) widget.onLoop();
      }
    }
  }

  void _hideYouTubeCaptions() {
    final c = _c;
    if (c == null) return;
    unawaited(c.webViewController
        .runJavaScript("try{player.unloadModule('captions');player.unloadModule('cc');player.setOption('captions','track',{});}catch(e){}")
        .catchError((_) {}));
  }

  void _onPosition(YoutubeVideoState s) {
    if (!mounted) return;
    final t = s.position.inMilliseconds / 1000;
    _time = t;
    final c = widget.clip;
    final lr = widget.loopRange;
    final end = lr?.$2 ?? c.end;
    final start = lr?.$1 ?? c.start;
    // Some players ignore startSeconds. Correct once after play, never every tick.
    if (_state == PlayerState.playing && !_startupCorrectionIssued) {
      _startupCorrectionIssued = true;
      if (t < c.start - 1.5) {
        _seekTo(c.start);
        widget.onTime(c.start);
        return;
      }
    }
    if (_loop.shouldLoop(t, start, end, playing: _state == PlayerState.playing)) {
      _seekTo(start);
      if (lr == null) widget.onLoop();
      widget.onTime(start);
      return;
    }
    // Startup reports zero/early keyframes; let YouTube settle without seeking again.
    widget.onTime(t.clamp(c.start, c.end));
  }

  Future<void> _seekTo(double t) async {
    _loop.beginSeek(t);
    await _c?.seekTo(seconds: t, allowSeekAhead: true);
  }

  // ---- handle used by ClipView ----
  void play() => _c?.playVideo();
  void pause() => _c?.pauseVideo();
  void toggle() => _state == PlayerState.playing ? pause() : play();
  void seek(double t) {
    _seekTo(t);
    _c?.playVideo();
  }

  double get time => _time;

  void _retry() {
    setState(() {
      _destroy();
      _create();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final showThumb = !widget.active || c == null || (!_tapped && (!_ready || _state == PlayerState.unStarted || _state == PlayerState.cued));
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: T.stage,
        child: Stack(fit: StackFit.expand, children: [
          if (c != null)
            YoutubePlayer(
              key: ValueKey('yt-${widget.clip.id}'),
              controller: c,
              aspectRatio: 16 / 9,
              backgroundColor: T.stage,
              autoFullScreen: false,
              enableFullScreenOnVerticalDrag: false,
              // Empty set: vertical swipes go to the feed, taps still reach YouTube's player.
              gestureRecognizers: const {},
            ),
          if (showThumb && _error == null)
            Semantics(
              button: true,
              label: 'Play clip',
              child: GestureDetector(
                onTap: () {
                  setState(() => _tapped = true);
                  _c?.playVideo();
                },
                child: Stack(fit: StackFit.expand, children: [
                  ClipThumb(widget.clip.thumb),
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: T.stage.withValues(alpha: 0.7), shape: BoxShape.circle),
                      child: widget.active && !_ready
                          ? const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 3, color: T.foreground))
                          : const Icon(LucideIcons.play, size: 28, color: T.foreground),
                    ),
                  ),
                ]),
              ),
            ),
          if (_error != null)
            Container(
              color: T.stage.withValues(alpha: 0.9),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(_error!, textAlign: TextAlign.center, style: txt(15, w: FontWeight.w700)),
                const SizedBox(height: 12),
                Press(
                  onTap: _retry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(99)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(LucideIcons.rotateCw, size: 16), const SizedBox(width: 8), Text('Try again', style: txt(14, w: FontWeight.w800))]),
                  ),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}
