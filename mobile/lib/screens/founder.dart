import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../data/onboarding.dart';
import '../services/founder_video.dart';
import '../services/onboarding_settings.dart';
import '../services/trial_preload.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';

/// The short welcome message before the trial (a presenter from the Kizuki team, with
/// captions) — mirrors src/routes/founder.tsx. The video ships inside the app, so it plays
/// offline. If it can't play, the animated fox "speaks" the same captions instead.
class FounderScreen extends StatefulWidget {
  const FounderScreen({super.key});
  @override
  State<FounderScreen> createState() => _FounderScreenState();
}

class _FounderScreenState extends State<FounderScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  VideoPlayerController? _video;
  bool _videoFailed = false;
  bool muted = false;

  // Fallback (no video): a timer drives the captions.
  double t = 0;
  bool playing = true;
  Timer? _timer;
  late final AnimationController _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkVideo();
  }

  Future<void> _checkVideo() async {
    // Everything at once: the video never waits on the settings round-trip for its first
    // frame. If the server says the slide is off, we leave and dispose right away.
    FounderVideo.prefetch();
    TrialPreload.start(context);
    unawaited(_initVideo());
    await OnboardingSettings.refresh();
    if (!mounted) return;
    if (!OnboardingSettings.enabled) {
      _leaving = true;
      context.go('/trial');
    }
  }

  /// Controller still initializing, so leaving can release it too.
  VideoPlayerController? _starting;
  Future<void>? _init;
  bool _leaving = false;

  Future<void> _initVideo() => _init = _startVideo();

  Future<void> _startVideo() async {
    // A downloaded server video wins when present; the bundled clip is the instant default.
    final f = await FounderVideo.readyFile();
    final c = f != null
        ? VideoPlayerController.file(f, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true))
        : VideoPlayerController.asset(founderVideoAsset, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
    _starting = c;
    try {
      await c.initialize().timeout(const Duration(seconds: 6));
      _starting = null;
      if (!mounted || _leaving) {
        await c.dispose();
        return;
      }
      c.addListener(_onVideo);
      await c.play();
      // Swap the poster for the player only once real frames are flowing; otherwise the
      // empty texture flashes black between the poster and the first decoded frame.
      final wait = Stopwatch()..start();
      while (c.value.position <= Duration.zero && wait.elapsed < const Duration(milliseconds: 900)) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      if (!mounted || _leaving) {
        await c.dispose();
        return;
      }
      _wave.stop();
      _float.stop();
      setState(() => _video = c);
    } catch (_) {
      _starting = null;
      await c.dispose().catchError((_) {});
      if (!mounted || _leaving) return;
      setState(() => _videoFailed = true);
      _startFallback();
    }
  }

  void _startFallback() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (playing && t < founderSeconds) setState(() => t = (t + 0.1).clamp(0, founderSeconds.toDouble()));
    });
  }

  void _onVideo() {
    final v = _video;
    if (v == null || !mounted) return;
    final s = v.value.position.inMilliseconds / 1000;
    if ((s - t).abs() >= 0.05 || playing != v.value.isPlaying) {
      setState(() {
        t = s;
        playing = v.value.isPlaying;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _video?.removeListener(_onVideo);
    _video?.dispose();
    _wave.dispose();
    _float.dispose();
    super.dispose();
  }

  bool get _ended {
    final v = _video;
    if (v == null) return t >= founderSeconds;
    final d = v.value.duration;
    return d > Duration.zero && v.value.position >= d - const Duration(milliseconds: 200);
  }

  void _pause() {
    if (_video != null) {
      _video!.pause();
    } else if (playing) {
      _toggleFallback();
    }
  }

  void _toggle() {
    final v = _video;
    if (v == null) return _toggleFallback();
    if (_ended) {
      v.seekTo(Duration.zero);
      v.play();
    } else if (v.value.isPlaying) {
      v.pause();
    } else {
      v.play();
    }
  }

  void _toggleFallback() {
    setState(() {
      if (t >= founderSeconds) t = 0;
      playing = !playing;
    });
    if (playing) {
      _wave.repeat(reverse: true);
      _float.repeat(reverse: true);
    } else {
      _wave.stop();
      _float.stop();
    }
  }

  void _toggleMute() {
    setState(() => muted = !muted);
    _video?.setVolume(muted ? 0 : 1);
  }

  /// The native video decoder is fully released before the trial creates its YouTube
  /// player, so two video surfaces never overlap on low-memory phones.
  Future<void> _continue() async {
    if (_leaving) return;
    _leaving = true;
    _timer?.cancel();
    final v = _video;
    if (v != null) {
      v.removeListener(_onVideo);
      setState(() => _video = null); // poster replaces the player before it is released
      await v.pause().catchError((_) {});
      await v.dispose().catchError((_) {});
    }
    // Still initializing: it disposes itself on completion (_leaving), wait for that.
    if (_starting != null) await _init?.catchError((_) {});
    if (!mounted) return;
    context.go('/trial');
  }

  @override
  Widget build(BuildContext context) {
    final v = _video;
    final total = v != null && v.value.duration > Duration.zero ? v.value.duration.inMilliseconds / 1000 : founderSeconds.toDouble();
    final line = founderLines.lastWhere((l) => l.t <= t, orElse: () => founderLines.first);
    final left = (total - t).ceil().clamp(0, total.ceil());
    final ended = _ended;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            const SizedBox(height: 16),
            Text.rich(
              TextSpan(children: [const TextSpan(text: 'A quick '), TextSpan(text: 'hello', style: txt(24, w: FontWeight.w900, c: T.primary)), const TextSpan(text: ' before you start')]),
              textAlign: TextAlign.center,
              style: txt(24, w: FontWeight.w900),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180, maxHeight: 320),
                child: Semantics(
                button: true,
                label: ended ? 'Play again' : (playing ? 'Pause' : 'Play'),
                child: GestureDetector(
                  onTap: _toggle,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(fit: StackFit.expand, children: [
                      if (v != null)
                        ColoredBox(
                          color: T.stage,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            clipBehavior: Clip.hardEdge,
                            child: SizedBox(width: v.value.size.width, height: v.value.size.height, child: VideoPlayer(v)),
                          ),
                        )
                      else if (_videoFailed)
                        _FoxSpeaker(playing: playing, wave: _wave, float: _float)
                      else
                        Image.asset(founderPosterAsset, fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: T.surface)),
                      // Play/pause state, top right.
                      Positioned(
                        right: 16,
                        top: 16,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: T.stage.withValues(alpha: playing ? 0.4 : 0.7), shape: BoxShape.circle),
                          child: Icon(playing ? LucideIcons.pause : LucideIcons.play, size: 20),
                        ),
                      ),
                      // Sound on/off, top left (video only).
                      if (v != null)
                        Positioned(
                          left: 16,
                          top: 16,
                          child: Semantics(
                            button: true,
                            label: muted ? 'Turn sound on' : 'Mute',
                            child: GestureDetector(
                              onTap: _toggleMute,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(color: T.stage.withValues(alpha: 0.5), shape: BoxShape.circle),
                                child: Icon(muted ? LucideIcons.volumeX : LucideIcons.volume2, size: 20),
                              ),
                            ),
                          ),
                        ),
                      if (ended)
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(color: T.stage.withValues(alpha: 0.6), shape: BoxShape.circle),
                            child: const Icon(LucideIcons.rotateCcw, size: 32),
                          ),
                        ),
                      // Captions.
                      if (_videoFailed) Positioned(
                        left: 16,
                        right: 16,
                        bottom: 24,
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Container(
                              key: ValueKey(line.t),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(color: T.stage.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(12)),
                              child: Text(line.text, textAlign: TextAlign.center, style: txt(16, w: FontWeight.w800, h: 1.3)),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ))),
            ),
            const SizedBox(height: 16),
            Text('Ten minutes a day. Then it just clicks.', textAlign: TextAlign.center, style: txt(17, w: FontWeight.w900)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              for (final item in [(LucideIcons.headphones, 'Real voices'), (LucideIcons.bookOpen, 'Words in context'), (LucideIcons.repeat, 'Lasting recall')])
                Expanded(child: Column(children: [Icon(item.$1, size: 20, color: T.primary), const SizedBox(height: 6), Text(item.$2, textAlign: TextAlign.center, style: txt(12, c: T.foreground.withValues(alpha: 0.7)))])),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 8),
              child: Row(children: [
                Ring(value: (1 - t / total).clamp(0.0, 1.0), color: T.primary, size: 56, stroke: 5, child: Text('$left', style: txt(15, w: FontWeight.w900))),
                const SizedBox(width: 16),
                Expanded(child: Button3D(label: 'Continue', onPressed: _continue)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Fallback when the video can't play: the fox with a talking waveform.
class _FoxSpeaker extends StatelessWidget {
  final bool playing;
  final Animation<double> wave, float;
  const _FoxSpeaker({required this.playing, required this.wave, required this.float});
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -0.3), radius: 0.9, colors: [T.primaryDim, T.surface])),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedBuilder(
              animation: float,
              builder: (_, child) => Transform.translate(offset: Offset(0, -6 * Curves.easeInOut.transform(float.value)), child: child),
              child: const Mascot(MascotPose.wave, size: 176),
            ),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: wave,
              builder: (_, _) => SizedBox(
                height: 32,
                child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (var i = 0; i < 14; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 6,
                      height: playing ? 6 + (10 + (i * 7) % 22) * ((wave.value + i * 0.13) % 1) : 6,
                      decoration: BoxDecoration(color: T.primary, borderRadius: BorderRadius.circular(99)),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      );
}
