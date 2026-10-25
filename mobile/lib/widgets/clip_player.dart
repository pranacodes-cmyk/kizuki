import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../data/models.dart' as m;
import '../logic/logic.dart' show clipWindowAvailable;
import '../theme/tokens.dart';
import '../services/analytics.dart';
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
/// Created for the active feed item and, cued but never playing, for the next one (`warm`), so a
/// swipe starts at once; other items show the thumbnail. Loops clip.start → clip.end (or a
/// single line). Mirrors ClipPlayer.tsx.
class ClipPlayer extends StatefulWidget {
  final m.Clip clip;
  final bool active;
  /// Next clip in the feed: load the player and cue the clip (no playback) ahead of the swipe.
  final bool warm;
  final double rate;
  final ValueChanged<double> onTime;
  final ValueChanged<bool> onPlayingChange;
  final VoidCallback onLoop;
  final (double, double)? loopRange;
  const ClipPlayer({super.key, required this.clip, required this.active, this.warm = false, required this.rate, required this.onTime, required this.onPlayingChange, required this.onLoop, this.loopRange});
  @override
  State<ClipPlayer> createState() => ClipPlayerState();
}

class ClipPlayerState extends State<ClipPlayer> {
  YoutubePlayerController? _c;
  StreamSubscription<YoutubePlayerValue>? _valueSub;
  StreamSubscription<YoutubeVideoState>? _timeSub;
  PlayerState _state = PlayerState.unStarted;
  bool _ready = false;
  /// pause() asked before the player could take commands: pause as soon as it starts.
  bool _wantPause = false;
  /// The player has finished loading or cueing the clip and can be told to play.
  bool _loaded = false;
  /// Still not playing a while after becoming active: offer Try again / Watch on YouTube.
  bool _slow = false;
  Timer? _slowTimer;
  String? _error;
  double _time = 0;
  late PlaybackLoopGuard _loop;
  late PlaybackStartGuard _startup;

  @override
  void initState() {
    super.initState();
    _time = widget.clip.start;
    if (widget.active || widget.warm) _create();
  }

  bool get _wanted => widget.active || widget.warm;

  @override
  void didUpdateWidget(covariant ClipPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clip.id != widget.clip.id) {
      _destroy();
      if (_wanted) _create();
    } else if (oldWidget.active != widget.active || oldWidget.warm != widget.warm) {
      if (!_wanted) {
        _destroy();
      } else if (_c == null) {
        _create();
      } else if (widget.active && !oldWidget.active) {
        _start(); // the warmed-up next clip just became the one on screen
      } else if (!widget.active && oldWidget.active) {
        _park(); // swiped back past it: keep it loaded, paused at its start
      }
    }
    if (oldWidget.rate != widget.rate) {
      if (widget.active) Analytics.track('clip_speed_changed', {'speed': widget.rate});
      if (_ready) _c?.setPlaybackRate(widget.rate);
    }
  }

  @override
  void dispose() {
    _destroy(notify: false);
    _slowTimer?.cancel();
    super.dispose();
  }

  void _watchSlow() {
    _slowTimer?.cancel();
    _slow = false;
    if (!widget.active) return;
    _slowTimer = Timer(const Duration(seconds: 9), () {
      if (mounted && widget.active && !_ready && _error == null) { Analytics.track('clip_loading_slow', {'clip_id': widget.clip.id}); setState(() => _slow = true); }
    });
  }

  void _create() {
    final clip = widget.clip;
    _error = null;
    _ready = false;
    _loaded = false;
    _wantPause = false;
    _time = clip.start;
    _loop = PlaybackLoopGuard(clip.start);
    _startup = PlaybackStartGuard();
    final c = YoutubePlayerController(
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
    _valueSub = c.stream.listen((v) { if (identical(_c, c)) _onValue(v); });
    _timeSub = c.videoStateStream.listen((v) { if (identical(_c, c)) _onPosition(v); });
    _watchSlow();
    unawaited(_initialize(c, clip));
  }

  Future<void> _initialize(YoutubePlayerController c, m.Clip clip) async {
    try {
      // Both wait for the IFrame ready signal. The active clip loads and plays; the next clip
      // is only cued (no playback, no sound) so its player is ready when the learner swipes.
      if (widget.active) {
        await c.loadVideoById(videoId: clip.videoId, startSeconds: clip.start, endSeconds: clip.end + 1);
      } else {
        await c.cueVideoById(videoId: clip.videoId, startSeconds: clip.start, endSeconds: clip.end + 1);
      }
      if (!mounted || !identical(_c, c)) return;
      _loaded = true;
      // loadVideoById already starts at startSeconds. Seeking again here interrupts
      // its first decoded frame and causes a second buffering/black-screen cycle.
      if (widget.active) {
        await c.setPlaybackRate(widget.rate);
        if (_wantPause) {
          await c.pauseVideo();
        } else {
          await c.playVideo(); // autoplay may be held until the ready command finishes
        }
      }
    } catch (_) {
      if (mounted && identical(_c, c)) {
        widget.onPlayingChange(false);
        setState(() => _error = "This clip couldn't load. Check your connection.");
      }
    }
  }

  /// Position the loaded video explicitly (matching web onReady instead of trusting
  /// startSeconds) and play it.
  Future<void> _play(YoutubePlayerController c, m.Clip clip) async {
    _loop.beginSeek(clip.start);
    await c.seekTo(seconds: clip.start, allowSeekAhead: true);
    if (!mounted || !identical(_c, c) || !widget.active) return;
    await c.setPlaybackRate(widget.rate);
    if (_wantPause) return;
    await c.playVideo();
  }

  /// A warmed-up clip became active: start it now (or as soon as its cue finishes).
  void _start() {
    final c = _c;
    if (c == null) return;
    _loop = PlaybackLoopGuard(widget.clip.start);
    _startup = PlaybackStartGuard();
    // A pause queued during an earlier activation never blocks this new start.
    _wantPause = false;
    _watchSlow();
    if (_loaded) unawaited(_play(c, widget.clip).catchError((_) {}));
  }

  /// No longer on screen but still the next clip: pause and keep it loaded.
  void _park() {
    _slowTimer?.cancel();
    _slow = false;
    if (_ready) _c?.pauseVideo();
    widget.onPlayingChange(false);
  }

  void _destroy({bool notify = true}) {
    _valueSub?.cancel();
    _timeSub?.cancel();
    _valueSub = null;
    _timeSub = null;
    final c = _c;
    _c = null;
    if (c != null) unawaited(c.close());
    _slowTimer?.cancel();
    _slow = false;
    _ready = false;
    _loaded = false;
    _wantPause = false;
    _state = PlayerState.unStarted;
    if (notify) widget.onPlayingChange(false);
  }

  void _onValue(YoutubePlayerValue v) {
    if (!mounted) return;
    final duration = v.metaData.duration.inMilliseconds / 1000;
    if (!clipWindowAvailable(widget.clip.start, widget.clip.end, duration)) {
      _c?.pauseVideo();
      widget.onPlayingChange(false);
      if (_error == null && widget.active) Analytics.track('clip_failed', {'category': 'invalid_window', 'clip_id': widget.clip.id});
      setState(() => _error = 'This clip is no longer available. Choose another clip.');
      return;
    }
    if (v.error != YoutubeError.none) {
      if (_error == null && widget.active) Analytics.track('clip_failed', {'category': v.error.name, 'clip_id': widget.clip.id});
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
        if (st == PlayerState.playing) _slow = false;
      });
      // The next clip only waits, cued; it never plays or reports playback.
      if (!widget.active) {
        if (st == PlayerState.playing || st == PlayerState.buffering) _c?.pauseVideo();
        return;
      }
      if (!wasReady && _ready) _c?.setPlaybackRate(widget.rate);
      if (_wantPause && (st == PlayerState.playing || st == PlayerState.buffering)) {
        _wantPause = false;
        _c?.pauseVideo();
      }
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
    if (!mounted || _error != null || !widget.active) return;
    final t = s.position.inMilliseconds / 1000;
    _time = t;
    final c = widget.clip;
    final lr = widget.loopRange;
    final end = lr?.$2 ?? c.end;
    final start = lr?.$1 ?? c.start;
    // A stale zero event is not proof of playback. Correct once only after
    // YouTube demonstrably advances outside this clip's time window.
    if (_startup.shouldCorrect(t, c.start, playing: _state == PlayerState.playing)) {
      _seekTo(c.start);
      widget.onTime(c.start);
      return;
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
  void play() {
    _wantPause = false;
    _c?.playVideo();
  }

  /// Safe before the player is ready (e.g. the tour pausing the first clip): it then pauses
  /// the moment playback starts instead of calling into a player that can't take commands yet.
  void pause() {
    if (!_ready) {
      _wantPause = true;
      return;
    }
    _c?.pauseVideo();
  }

  void toggle() => _state == PlayerState.playing ? pause() : play();
  void seek(double t) {
    // Replay / tapping a line on a ready player is an explicit play: it cancels a queued
    // pause. Before ready it does not run, so a queued pause stays.
    if (_ready) _wantPause = false;
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
    // Never cover a mounted official player with our poster. Its own loading/play
    // UI stays visible, rather than flashing a poster and then revealing buffering.
    final showThumb = c == null;
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
                  play();
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
                  // Slow network: say so and offer a fresh start instead of an endless spinner.
                  if (widget.active && _slow && !_ready)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 12,
                      child: Center(
                        child: Press(
                          onTap: _retry,
                          child: Container(
                            key: const ValueKey('player-slow'),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(color: T.stage.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(99)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(LucideIcons.rotateCw, size: 15),
                              const SizedBox(width: 8),
                              Text('Slow connection · Tap to retry', style: txt(13, w: FontWeight.w800)),
                            ]),
                          ),
                        ),
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
