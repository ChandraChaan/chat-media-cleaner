import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../app/providers.dart';
import '../../media/domain/media_file.dart';
import '../../media/domain/media_storage.dart';
import '../domain/playback_positions.dart';
import 'player_controls.dart';
import 'sleep_timer.dart';

/// A player that has not opened a file after this long is given up on,
/// rather than showing a spinner for ever.
const playerOpenTimeout = Duration(seconds: 20);

/// Builds the player's screen. [resumedFrom] is where playback carried on
/// from, when it did not start at the beginning.
typedef PlayerBuilder =
    Widget Function(
      BuildContext context,
      VideoPlayerController controller,
      Duration? resumedFrom,
    );

/// Opens [file] in a player and hands the ready controller to [builder].
///
/// Plays while [active] (the page is the one on screen) and the app is in
/// front, and pauses otherwise. Shows [loading] until the player is ready
/// and [failed] when the phone cannot play the file.
class MediaPlayerHost extends ConsumerStatefulWidget {
  const MediaPlayerHost({
    required this.file,
    required this.active,
    required this.builder,
    required this.loading,
    required this.failed,
    this.keepScreenOn = false,
    this.silentLoop = false,
    this.resume = false,
    super.key,
  });

  final MediaFile file;
  final bool active;
  final PlayerBuilder builder;
  final Widget loading;
  final Widget failed;

  /// Keeps the screen awake while playing; for videos, not for sound.
  final bool keepScreenOn;

  /// Plays without sound and repeats, as chat apps play GIFs.
  final bool silentLoop;

  /// Carries on from where the file was stopped last time, and remembers
  /// where it is stopped this time.
  final bool resume;

  @override
  ConsumerState<MediaPlayerHost> createState() => _MediaPlayerHostState();
}

class _MediaPlayerHostState extends ConsumerState<MediaPlayerHost>
    with WidgetsBindingObserver {
  late final MediaViewer _viewer;
  late final ScreenControl _screen;
  late final PlaybackPositions _positions;
  VideoPlayerController? _controller;
  Duration? _resumedFrom;
  bool _failed = false;
  bool _awake = false;
  bool _wasPlaying = false;

  @override
  void initState() {
    super.initState();
    _viewer = ref.read(mediaViewerProvider);
    _screen = ref.read(screenControlProvider);
    _positions = ref.read(playbackPositionsProvider);
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(
      sleepTimerProvider.select((s) => s.fired),
      (_, _) => unawaited(_controller?.pause()),
    );
    unawaited(_load());
  }

  Future<void> _load() async {
    VideoPlayerController? controller;
    Duration? resumedFrom;
    try {
      final uri = await _viewer.contentUri(
        widget.file.sourceId,
        widget.file.id,
      );
      controller = VideoPlayerController.contentUri(Uri.parse(uri));
      await controller.initialize().timeout(playerOpenTimeout);
      if (!mounted) {
        unawaited(controller.dispose());
        return;
      }
      final prefs = ref.read(playbackPrefsProvider);
      if (widget.silentLoop) {
        await controller.setLooping(true);
        await controller.setVolume(0);
      } else {
        await controller.setLooping(prefs.loop);
        await controller.setVolume(prefs.muted ? 0 : 1);
        if (prefs.speed != 1) await controller.setPlaybackSpeed(prefs.speed);
      }
      if (widget.resume) {
        resumedFrom = await _positions.resumeAt(
          widget.file.key,
          duration: controller.value.duration,
        );
        if (resumedFrom != null) await controller.seekTo(resumedFrom);
      }
    } on Object catch (e, stack) {
      // An unsupported codec, a damaged file, or one that was deleted.
      developer.log('Player failed to open', error: e, stackTrace: stack);
      // Not awaited: disposing waits for the player to finish opening,
      // which is exactly what may never happen.
      unawaited(controller?.dispose());
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (!mounted) {
      unawaited(controller.dispose());
      return;
    }
    controller.addListener(_onChanged);
    setState(() {
      _controller = controller;
      _resumedFrom = resumedFrom;
    });
    if (widget.active) await controller.play();
  }

  void _onChanged() {
    final playing = _controller?.value.isPlaying ?? false;
    if (playing == _wasPlaying) return;
    _wasPlaying = playing;
    if (!playing) _remember();
    if (widget.keepScreenOn && playing != _awake) _setAwake(playing);
  }

  /// Notes where the file is now, to carry on from next time.
  void _remember() {
    final value = _controller?.value;
    if (!widget.resume || value == null) return;
    unawaited(
      _positions
          .remember(
            widget.file.key,
            position: value.position,
            duration: value.duration,
          )
          .catchError((Object e, StackTrace stack) {
            developer.log('Position not saved', error: e, stackTrace: stack);
          }),
    );
  }

  void _setAwake(bool awake) {
    _awake = awake;
    unawaited(
      _screen.keepScreenOn(on: awake).catchError((Object e, StackTrace stack) {
        developer.log('Keep screen on failed', error: e, stackTrace: stack);
      }),
    );
  }

  @override
  void didUpdateWidget(MediaPlayerHost old) {
    super.didUpdateWidget(old);
    if (old.active == widget.active) return;
    final controller = _controller;
    if (controller == null) return;
    unawaited(widget.active ? controller.play() : controller.pause());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_controller?.pause());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _remember();
    _controller?.removeListener(_onChanged);
    unawaited(_controller?.dispose());
    if (_awake) _setAwake(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.failed;
    final controller = _controller;
    if (controller == null) return widget.loading;
    return widget.builder(context, controller, _resumedFrom);
  }
}
