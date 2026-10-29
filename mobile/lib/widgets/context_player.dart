import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../data/models.dart' as m;
import '../theme/tokens.dart';
import 'common.dart';
import 'ui.dart';
import '../i18n/i18n.dart';

/// Plays just one line of the original clip (the "original audio" on a flashcard) through
/// the official YouTube player, visible at ≥200px tall — mirrors ContextPlayer.tsx.
class ContextPlayer extends StatefulWidget {
  final m.Clip clip;
  final int line;
  final bool autoplay;
  final int replayKey;
  const ContextPlayer({super.key, required this.clip, required this.line, required this.autoplay, this.replayKey = 0});
  @override
  State<ContextPlayer> createState() => _ContextPlayerState();
}

class _ContextPlayerState extends State<ContextPlayer> {
  YoutubePlayerController? _c;
  StreamSubscription<YoutubePlayerValue>? _vs;
  StreamSubscription<YoutubeVideoState>? _ts;
  bool ready = false, started = false, playing = false, failed = false;

  m.Line? get _l => widget.clip.lines.isEmpty ? null : widget.clip.lines[widget.line.clamp(0, widget.clip.lines.length - 1)];
  double get from => math.max(widget.clip.start, (_l?.start ?? widget.clip.start) - 0.15);
  double get to => math.min(widget.clip.end + 0.3, (_l?.end ?? widget.clip.end) + 0.25);

  @override
  void initState() {
    super.initState();
    _create();
  }

  @override
  void didUpdateWidget(covariant ContextPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clip.id != widget.clip.id || oldWidget.line != widget.line) {
      _destroy();
      setState(() {
        ready = false;
        started = false;
        playing = false;
        failed = false;
      });
      _create();
    } else if (oldWidget.replayKey != widget.replayKey && widget.autoplay) {
      _play();
    }
  }

  @override
  void dispose() {
    _destroy();
    super.dispose();
  }

  void _create() {
    final c = YoutubePlayerController.fromVideoId(
      videoId: widget.clip.videoId,
      autoPlay: false,
      startSeconds: from,
      params: const YoutubePlayerParams(showControls: false, enableKeyboard: false, showFullscreenButton: false, playsInline: true, showVideoAnnotations: false, enableCaption: false, strictRelatedVideos: true, privacyEnhancedMode: true, videoStateUpdateInterval: 80),
    );
    _c = c;
    _vs = c.stream.listen((v) {
      if (!mounted) return;
      if (v.error != YoutubeError.none) {
        setState(() => failed = true);
        return;
      }
      final st = v.playerState;
      final isReady = st == PlayerState.cued || st == PlayerState.paused || st == PlayerState.playing || st == PlayerState.buffering;
      if (isReady && !ready) {
        setState(() => ready = true);
        if (widget.autoplay) _play();
      }
      final p = st == PlayerState.playing;
      if (p != playing) setState(() => playing = p);
      // Hide YouTube's own captions here too (enableCaption=false is ignored when the viewer
      // or channel has captions on) — the card already shows the sentence and translation.
      if (st == PlayerState.playing || st == PlayerState.buffering) _hideYouTubeCaptions();
    });
    _ts = c.videoStateStream.listen((s) {
      if (playing && s.position.inMilliseconds / 1000 >= to) _c?.pauseVideo();
    });
    // Some devices never report "cued" before the first play; treat the player as ready shortly after load.
    Timer(const Duration(seconds: 3), () {
      if (mounted && !ready && !failed) {
        setState(() => ready = true);
        if (widget.autoplay) _play();
      }
    });
  }

  void _hideYouTubeCaptions() {
    final c = _c;
    if (c == null) return;
    unawaited(c.webViewController
        .runJavaScript("try{player.unloadModule('captions');player.unloadModule('cc');player.setOption('captions','track',{});}catch(e){}")
        .catchError((_) {}));
  }

  void _destroy() {
    _vs?.cancel();
    _ts?.cancel();
    final c = _c;
    _c = null;
    if (c != null) unawaited(c.close());
  }

  void _play() {
    final c = _c;
    if (c == null || !ready) return;
    setState(() => started = true);
    c.seekTo(seconds: from, allowSeekAhead: true);
    c.playVideo();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 200),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: T.stage,
            child: Stack(fit: StackFit.expand, children: [
              if (c != null) YoutubePlayer(controller: c, backgroundColor: T.stage, autoFullScreen: false, enableFullScreenOnVerticalDrag: false, gestureRecognizers: const {}),
              if (!started)
                Semantics(
                  button: true,
                  label: tr('Play the original line'),
                  child: GestureDetector(
                    onTap: _play,
                    child: Stack(fit: StackFit.expand, children: [
                      ClipThumb(widget.clip.thumb),
                      Center(
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(color: T.stage.withValues(alpha: 0.75), shape: BoxShape.circle),
                          child: ready ? const Icon(LucideIcons.play, size: 24) : const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 3, color: T.foreground)),
                        ),
                      ),
                    ]),
                  ),
                ),
              if (started && !playing && !failed)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Semantics(
                    button: true,
                    label: tr('Replay the original line'),
                    child: Press(
                      onTap: _play,
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: T.stage.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(99)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(LucideIcons.volume2, size: 16), const SizedBox(width: 6), Text(tr('Replay'), style: txt(13, w: FontWeight.w800))]),
                      ),
                    ),
                  ),
                ),
              if (failed)
                Container(
                  color: T.stage.withValues(alpha: 0.85),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(tr("The original clip isn't available right now."), textAlign: TextAlign.center, style: txt(14, w: FontWeight.w700)),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
