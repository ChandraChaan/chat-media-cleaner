import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../app/providers.dart';
import '../../../core/format.dart';
import '../../../core/l10n.dart';
import '../../../l10n/app_localizations.dart';
import '../../browse/presentation/browse_controller.dart';
import '../../media/domain/media_file.dart';
import '../../media/domain/media_storage.dart';
import 'sleep_timer.dart';

/// Repeat, mute and speed carry over from one file to the next while the
/// app runs.
final class PlaybackPrefs {
  const PlaybackPrefs({this.loop = false, this.muted = false, this.speed = 1});

  final bool loop;
  final bool muted;
  final double speed;

  PlaybackPrefs copyWith({bool? loop, bool? muted, double? speed}) =>
      PlaybackPrefs(
        loop: loop ?? this.loop,
        muted: muted ?? this.muted,
        speed: speed ?? this.speed,
      );
}

final playbackPrefsProvider =
    NotifierProvider<PlaybackPrefsController, PlaybackPrefs>(
      PlaybackPrefsController.new,
    );

final class PlaybackPrefsController extends Notifier<PlaybackPrefs> {
  @override
  PlaybackPrefs build() => const PlaybackPrefs();

  void setLoop({required bool loop}) => state = state.copyWith(loop: loop);
  void setMuted({required bool muted}) => state = state.copyWith(muted: muted);
  void setSpeed(double speed) => state = state.copyWith(speed: speed);
}

const playbackSpeeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0];
const skipStep = Duration(seconds: 10);

/// How long the video controls stay up while a video plays untouched.
const controlsTimeout = Duration(seconds: 3);

/// How far a swipe across the whole width of the video moves playback.
const scrubPerWidth = Duration(seconds: 90);

/// The speed while a finger is held on the video.
const heldSpeed = 2.0;

/// How a video fills the screen.
enum VideoFit {
  /// All of the picture, with bars where the shapes differ.
  fit,

  /// The whole screen, cutting off what does not fit.
  crop,

  /// The whole screen, changing the picture's shape.
  stretch;

  BoxFit get boxFit => switch (this) {
    VideoFit.fit => BoxFit.contain,
    VideoFit.crop => BoxFit.cover,
    VideoFit.stretch => BoxFit.fill,
  };

  VideoFit get next => values[(index + 1) % values.length];

  String label(AppLocalizations l10n) => switch (this) {
    VideoFit.fit => l10n.playerFitFit,
    VideoFit.crop => l10n.playerFitCrop,
    VideoFit.stretch => l10n.playerFitStretch,
  };
}

String speedLabel(double speed) =>
    '${speed == speed.roundToDouble() ? speed.toStringAsFixed(0) : speed}×';

/// Whether playback stopped at the end of the file.
bool playbackEnded(VideoPlayerValue v) =>
    !v.isPlaying &&
    !v.isLooping &&
    v.duration > Duration.zero &&
    v.position >= v.duration - const Duration(milliseconds: 300);

/// Plays, pauses, or starts again from the beginning after the end.
Future<void> togglePlayback(VideoPlayerController controller) async {
  final value = controller.value;
  if (playbackEnded(value)) {
    await controller.seekTo(Duration.zero);
    await controller.play();
  } else if (value.isPlaying) {
    await controller.pause();
  } else {
    await controller.play();
  }
}

/// Jumps [skipStep] back or forward, staying inside the file.
Future<void> skipPlayback(
  VideoPlayerController controller, {
  required bool forward,
}) async {
  final value = controller.value;
  var target = value.position + (forward ? skipStep : -skipStep);
  if (target < Duration.zero) target = Duration.zero;
  if (target > value.duration) target = value.duration;
  await controller.seekTo(target);
}

/// A scrub bar with the position on its left and the length on its right.
/// Playback pauses while the thumb is dragged.
class PlayerScrubber extends StatefulWidget {
  const PlayerScrubber({required this.controller, this.onScrubbing, super.key});

  final VideoPlayerController controller;

  /// Called with true when a drag starts and false when it ends.
  final ValueChanged<bool>? onScrubbing;

  @override
  State<PlayerScrubber> createState() => _PlayerScrubberState();
}

class _PlayerScrubberState extends State<PlayerScrubber> {
  Duration? _scrubTo;
  bool _wasPlaying = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, v, _) {
        final total = v.duration;
        final position = _scrubTo ?? (v.position > total ? total : v.position);
        final max = total.inMilliseconds <= 0
            ? 1.0
            : total.inMilliseconds.toDouble();
        return Row(
          children: [
            const SizedBox(width: 8),
            Text(formatDuration(position), style: style),
            Expanded(
              child: Slider(
                key: const Key('player-scrubber'),
                value: position.inMilliseconds.clamp(0, max).toDouble(),
                max: max,
                semanticFormatterCallback: (ms) =>
                    formatDuration(Duration(milliseconds: ms.round())),
                onChangeStart: (ms) {
                  _wasPlaying = v.isPlaying;
                  setState(() => _scrubTo = Duration(milliseconds: ms.round()));
                  widget.onScrubbing?.call(true);
                  unawaited(widget.controller.pause());
                },
                onChanged: (ms) {
                  final to = Duration(milliseconds: ms.round());
                  setState(() => _scrubTo = to);
                  unawaited(widget.controller.seekTo(to));
                },
                onChangeEnd: (ms) async {
                  await widget.controller.seekTo(
                    Duration(milliseconds: ms.round()),
                  );
                  if (!mounted) return;
                  setState(() => _scrubTo = null);
                  if (_wasPlaying) await widget.controller.play();
                  widget.onScrubbing?.call(false);
                },
              ),
            ),
            Text(formatDuration(total), style: style),
            const SizedBox(width: 8),
          ],
        );
      },
    );
  }
}

/// Shows the current speed and opens the list of speeds.
class SpeedMenu extends ConsumerWidget {
  const SpeedMenu({
    required this.controller,
    this.onOpened,
    this.onClosed,
    super.key,
  });

  final VideoPlayerController controller;
  final VoidCallback? onOpened;
  final VoidCallback? onClosed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final speed = ref.watch(playbackPrefsProvider.select((p) => p.speed));
    return PopupMenuButton<double>(
      tooltip: l10n.playerSpeed,
      initialValue: speed,
      onOpened: onOpened,
      onCanceled: onClosed,
      onSelected: (s) async {
        ref.read(playbackPrefsProvider.notifier).setSpeed(s);
        await controller.setPlaybackSpeed(s);
        onClosed?.call();
      },
      itemBuilder: (_) => [
        for (final s in playbackSpeeds)
          CheckedPopupMenuItem(
            value: s,
            checked: s == speed,
            child: Text(s == 1 ? l10n.playerSpeedNormal : speedLabel(s)),
          ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Center(
          widthFactor: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              speedLabel(speed),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _Drag { none, brightness, volume, scrub }

enum _More { repeat, sleep, frame }

typedef _Indicator = ({IconData? icon, String text});

/// Playback controls drawn over a video.
///
/// Gestures: tap shows or hides the controls, double-tap the left or right
/// half skips 10 seconds, swipe up or down on the left half for brightness
/// and on the right half for volume, swipe sideways to scrub, and hold for
/// double speed. Buttons: previous and next file, lock, mute, speed,
/// picture size, full screen, and a menu with repeat, a sleep timer and
/// saving the current frame as a photo.
class VideoControls extends ConsumerStatefulWidget {
  const VideoControls({
    required this.controller,
    required this.file,
    required this.visible,
    required this.onVisibleChanged,
    required this.fullscreen,
    required this.onToggleFullscreen,
    required this.fit,
    required this.onFitChanged,
    this.onPrevious,
    this.onNext,
    this.resumedFrom,
    this.bottomInset = 0,
    super.key,
  });

  final VideoPlayerController controller;
  final MediaFile file;
  final bool visible;
  final ValueChanged<bool> onVisibleChanged;
  final bool fullscreen;
  final VoidCallback onToggleFullscreen;
  final VideoFit fit;
  final ValueChanged<VideoFit> onFitChanged;

  /// Go to the file before or after this one; null when there is none.
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// Where playback carried on from, shown once when the video opens.
  final Duration? resumedFrom;

  /// Space kept free below the controls (the system navigation bar).
  final double bottomInset;

  @override
  ConsumerState<VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends ConsumerState<VideoControls> {
  /// A swipe has to travel this far before it counts as one.
  static const _dragSlop = 8.0;

  /// Swiping this share of the height goes from none to full.
  static const _levelTravel = 0.6;

  VideoPlayerController get _c => widget.controller;

  late final ScreenControl _screen;

  bool _locked = false;
  bool _unlockVisible = false;
  bool _scrubbing = false;
  bool _menuOpen = false;
  bool _lastPlaying = false;
  bool _boosted = false;
  double _speedBefore = 1;

  Size _size = Size.zero;
  _Drag _drag = _Drag.none;
  Offset _dragOrigin = Offset.zero;
  Offset _dragTotal = Offset.zero;
  double? _startBrightness;
  ({int current, int max})? _startVolume;
  int? _lastVolume;
  Duration _scrubStart = Duration.zero;
  Duration? _scrubTarget;

  double _doubleTapX = 0;
  ({bool forward, int taps})? _skipFlash;
  _Indicator? _indicator;
  Timer? _flashTimer;
  Timer? _hideTimer;
  Timer? _indicatorTimer;
  Timer? _unlockTimer;

  @override
  void initState() {
    super.initState();
    _screen = ref.read(screenControlProvider);
    _lastPlaying = _c.value.isPlaying;
    _c.addListener(_changed);
    _scheduleHide();
    if (widget.resumedFrom case final from?) {
      // The words need the localisations, which are not there yet.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _indicate(
          context.l10n.resumedFrom(formatDuration(from)),
          icon: Icons.history,
          hideAfter: const Duration(milliseconds: 1800),
        );
      });
    }
  }

  @override
  void didUpdateWidget(VideoControls old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      _c.addListener(_changed);
    }
    if (widget.visible != old.visible) _scheduleHide();
  }

  @override
  void dispose() {
    _c.removeListener(_changed);
    _flashTimer?.cancel();
    _hideTimer?.cancel();
    _indicatorTimer?.cancel();
    _unlockTimer?.cancel();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    final playing = _c.value.isPlaying;
    if (playing != _lastPlaying) {
      _lastPlaying = playing;
      _scheduleHide();
    }
    setState(() {});
  }

  /// Hides the controls a few seconds after the last touch while playing.
  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!widget.visible || !_c.value.isPlaying || _scrubbing || _menuOpen) {
      return;
    }
    _hideTimer = Timer(controlsTimeout, () {
      if (mounted && _c.value.isPlaying && !_scrubbing && !_menuOpen) {
        widget.onVisibleChanged(false);
      }
    });
  }

  /// Shows a short note in the middle of the video; it stays until the
  /// next one when [hideAfter] is null.
  void _indicate(
    String text, {
    IconData? icon,
    Duration? hideAfter = const Duration(milliseconds: 800),
  }) {
    _indicatorTimer?.cancel();
    setState(() => _indicator = (icon: icon, text: text));
    if (hideAfter != null) {
      _indicatorTimer = Timer(hideAfter, () {
        if (mounted) setState(() => _indicator = null);
      });
    }
  }

  void _clearIndicator() {
    _indicatorTimer?.cancel();
    if (_indicator != null) setState(() => _indicator = null);
  }

  // ---- taps ----

  void _onTap() {
    if (!_locked) {
      widget.onVisibleChanged(!widget.visible);
      return;
    }
    // Locked: a tap only brings up the way out.
    setState(() => _unlockVisible = true);
    _unlockTimer?.cancel();
    _unlockTimer = Timer(controlsTimeout, () {
      if (mounted) setState(() => _unlockVisible = false);
    });
  }

  Future<void> _onDoubleTap() async {
    if (_locked) return;
    final forward = _doubleTapX > _size.width / 2;
    final previous = _skipFlash;
    setState(
      () => _skipFlash = (
        forward: forward,
        taps: previous != null && previous.forward == forward
            ? previous.taps + 1
            : 1,
      ),
    );
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _skipFlash = null);
    });
    await skipPlayback(_c, forward: forward);
  }

  // ---- hold for double speed ----

  Future<void> _onHoldStart() async {
    if (_locked || !_c.value.isPlaying) return;
    _speedBefore = _c.value.playbackSpeed;
    _boosted = true;
    _indicate(speedLabel(heldSpeed), icon: Icons.fast_forward, hideAfter: null);
    await _c.setPlaybackSpeed(heldSpeed);
  }

  Future<void> _onHoldEnd() async {
    if (!_boosted) return;
    _boosted = false;
    _clearIndicator();
    await _c.setPlaybackSpeed(_speedBefore);
  }

  // ---- swipes ----

  void _onDragStart(DragStartDetails details) {
    _drag = _Drag.none;
    _dragOrigin = details.localPosition;
    _dragTotal = Offset.zero;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_locked || _boosted) return;
    _dragTotal += details.delta;
    if (_drag == _Drag.none) {
      if (_dragTotal.dx.abs() < _dragSlop && _dragTotal.dy.abs() < _dragSlop) {
        return;
      }
      _beginDrag(
        _dragTotal.dx.abs() > _dragTotal.dy.abs()
            ? _Drag.scrub
            : _dragOrigin.dx < _size.width / 2
            ? _Drag.brightness
            : _Drag.volume,
      );
    }
    final l10n = context.l10n;
    // Up is more, and the full range takes a good part of the height.
    final level = -_dragTotal.dy / (_size.height * _levelTravel);
    switch (_drag) {
      case _Drag.none:
        break;
      case _Drag.brightness:
        final start = _startBrightness;
        if (start == null) return;
        final value = (start + level).clamp(0.02, 1.0);
        unawaited(_screen.setBrightness(value).catchError(_logDeviceError));
        _indicate(
          l10n.percent((value * 100).round()),
          icon: Icons.brightness_6,
          hideAfter: null,
        );
      case _Drag.volume:
        final start = _startVolume;
        if (start == null) return;
        final value = (start.current + level * start.max).round().clamp(
          0,
          start.max,
        );
        if (value != _lastVolume) {
          _lastVolume = value;
          unawaited(_screen.setVolume(value).catchError(_logDeviceError));
        }
        _indicate(
          l10n.percent((value * 100 / start.max).round()),
          icon: value == 0 ? Icons.volume_off : Icons.volume_up,
          hideAfter: null,
        );
      case _Drag.scrub:
        final total = _c.value.duration;
        if (total <= Duration.zero) return;
        final delta = scrubPerWidth * (_dragTotal.dx / _size.width);
        var target = _scrubStart + delta;
        if (target < Duration.zero) target = Duration.zero;
        if (target > total) target = total;
        _scrubTarget = target;
        final moved = target - _scrubStart;
        _indicate(
          '${moved.isNegative ? '−' : '+'}${formatDuration(moved.abs())}'
          '   ${formatDuration(target)} / ${formatDuration(total)}',
          icon: moved.isNegative ? Icons.fast_rewind : Icons.fast_forward,
          hideAfter: null,
        );
    }
  }

  void _beginDrag(_Drag drag) {
    _drag = drag;
    _hideTimer?.cancel();
    switch (drag) {
      case _Drag.none:
        break;
      case _Drag.brightness:
        _startBrightness = null;
        unawaited(
          _screen
              .brightness()
              // Following the system: start from the middle.
              .then<void>((value) => _startBrightness = value ?? 0.5)
              .catchError(_logDeviceError),
        );
      case _Drag.volume:
        _startVolume = null;
        _lastVolume = null;
        unawaited(
          _screen
              .volume()
              .then<void>(
                (value) => _startVolume = value.max > 0 ? value : null,
              )
              .catchError(_logDeviceError),
        );
      case _Drag.scrub:
        _scrubStart = _c.value.position;
        _scrubTarget = null;
    }
  }

  Future<void> _onDragEnd() async {
    final drag = _drag;
    _drag = _Drag.none;
    if (drag == _Drag.none) return;
    final target = _scrubTarget;
    _scrubTarget = null;
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _indicator = null);
    });
    _scheduleHide();
    if (drag == _Drag.scrub && target != null) await _c.seekTo(target);
  }

  void _logDeviceError(Object error, StackTrace stack) {
    developer.log('Screen or sound', error: error, stackTrace: stack);
  }

  // ---- buttons ----

  void _setLocked(bool locked) {
    _unlockTimer?.cancel();
    setState(() {
      _locked = locked;
      _unlockVisible = false;
    });
    if (locked) {
      widget.onVisibleChanged(false);
      _indicate(
        context.l10n.playerLocked,
        icon: Icons.lock,
        hideAfter: const Duration(milliseconds: 1500),
      );
    } else {
      widget.onVisibleChanged(true);
    }
  }

  Future<void> _toggleMute() async {
    _scheduleHide();
    final muted = !ref.read(playbackPrefsProvider).muted;
    ref.read(playbackPrefsProvider.notifier).setMuted(muted: muted);
    await _c.setVolume(muted ? 0 : 1);
  }

  Future<void> _toggleLoop() async {
    final loop = !_c.value.isLooping;
    ref.read(playbackPrefsProvider.notifier).setLoop(loop: loop);
    await _c.setLooping(loop);
  }

  void _cycleFit() {
    _scheduleHide();
    final fit = widget.fit.next;
    widget.onFitChanged(fit);
    _indicate(fit.label(context.l10n), icon: Icons.aspect_ratio);
  }

  Future<void> _saveFrame() async {
    final l10n = context.l10n;
    final name = await ref
        .read(fileOpsProvider)
        .saveFrame(widget.file, _c.value.position);
    if (!mounted) return;
    _indicate(
      name == null ? l10n.frameSaveFailed : l10n.frameSaved(name),
      icon: Icons.photo_camera_outlined,
      hideAfter: const Duration(milliseconds: 1800),
    );
  }

  Future<void> _pickSleepTimer() async {
    final l10n = context.l10n;
    final current = ref.read(sleepTimerProvider).minutes ?? 0;
    _menuOpen = true;
    _hideTimer?.cancel();
    // 0 stands for "off"; null means the dialog was dismissed.
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.playerSleepTimer),
        children: [
          for (final choice in [0, ...sleepTimerChoices])
            SimpleDialogOption(
              key: Key('sleep-$choice'),
              onPressed: () => Navigator.of(context).pop(choice),
              child: Row(
                children: [
                  Icon(
                    choice == current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    semanticLabel: choice == current ? l10n.selected : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      choice == 0 ? l10n.sleepOff : l10n.sleepMinutes(choice),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    if (!mounted) return;
    _menuOpen = false;
    _scheduleHide();
    if (minutes == null) return;
    ref.read(sleepTimerProvider.notifier).set(minutes == 0 ? null : minutes);
    _indicate(
      minutes == 0 ? l10n.sleepTimerOff : l10n.sleepIn(minutes),
      icon: Icons.bedtime_outlined,
      hideAfter: const Duration(milliseconds: 1500),
    );
  }

  void _onMore(_More item) {
    _menuOpen = false;
    _scheduleHide();
    switch (item) {
      case _More.repeat:
        unawaited(_toggleLoop());
      case _More.sleep:
        unawaited(_pickSleepTimer());
      case _More.frame:
        unawaited(_saveFrame());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final v = _c.value;
    final visible = widget.visible && !_locked;
    final muted = v.volume == 0;
    final sleepMinutes = ref.watch(sleepTimerProvider.select((s) => s.minutes));
    return LayoutBuilder(
      builder: (context, box) {
        _size = box.biggest;
        return Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              label: l10n.viewerToggleControls,
              button: true,
              child: GestureDetector(
                key: const Key('video-gestures'),
                behavior: HitTestBehavior.opaque,
                onTap: _onTap,
                onDoubleTapDown: (d) => _doubleTapX = d.localPosition.dx,
                onDoubleTap: _onDoubleTap,
                onLongPressStart: (_) => _onHoldStart(),
                onLongPressEnd: (_) => _onHoldEnd(),
                onLongPressCancel: _onHoldEnd,
                onPanStart: _onDragStart,
                onPanUpdate: _onDragUpdate,
                onPanEnd: (_) => _onDragEnd(),
                onPanCancel: _onDragEnd,
              ),
            ),
            if (_skipFlash case final flash?)
              Align(
                alignment: flash.forward
                    ? const Alignment(0.7, 0)
                    : const Alignment(-0.7, 0),
                child: IgnorePointer(
                  child: _Pill(
                    icon: flash.forward
                        ? Icons.fast_forward
                        : Icons.fast_rewind,
                    text: l10n.playerSkipped(flash.taps * skipStep.inSeconds),
                  ),
                ),
              ),
            if (_indicator case final indicator?)
              Align(
                alignment: const Alignment(0, -0.5),
                child: IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _Pill(
                      key: const Key('player-indicator'),
                      icon: indicator.icon,
                      text: indicator.text,
                    ),
                  ),
                ),
              ),
            if (!_locked)
              Center(
                child: _CentreButtons(
                  controller: _c,
                  visible: visible,
                  onPrevious: widget.onPrevious,
                  onNext: widget.onNext,
                ),
              ),
            if (_locked && _unlockVisible)
              Center(
                child: Material(
                  color: scheme.scrim.withValues(alpha: 0.5),
                  shape: const CircleBorder(),
                  child: IconButton(
                    key: const Key('player-unlock'),
                    tooltip: l10n.playerUnlock,
                    iconSize: 36,
                    color: scheme.onSurface,
                    padding: const EdgeInsets.all(12),
                    icon: const Icon(Icons.lock),
                    onPressed: () => _setLocked(false),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: !visible,
                child: ExcludeSemantics(
                  excluding: !visible,
                  child: AnimatedOpacity(
                    opacity: visible ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            scheme.scrim.withValues(alpha: 0),
                            scheme.scrim.withValues(alpha: 0.75),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          8,
                          24,
                          8,
                          widget.bottomInset,
                        ),
                        child: IconTheme.merge(
                          data: IconThemeData(color: scheme.onSurface),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PlayerScrubber(
                                controller: _c,
                                onScrubbing: (scrubbing) {
                                  _scrubbing = scrubbing;
                                  _scheduleHide();
                                },
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    key: const Key('player-lock'),
                                    tooltip: l10n.playerLock,
                                    icon: const Icon(Icons.lock_open),
                                    onPressed: () => _setLocked(true),
                                  ),
                                  IconButton(
                                    key: const Key('player-mute'),
                                    tooltip: muted
                                        ? l10n.playerUnmute
                                        : l10n.playerMute,
                                    icon: Icon(
                                      muted
                                          ? Icons.volume_off
                                          : Icons.volume_up,
                                    ),
                                    onPressed: _toggleMute,
                                  ),
                                  SpeedMenu(
                                    controller: _c,
                                    onOpened: () {
                                      _menuOpen = true;
                                      _hideTimer?.cancel();
                                    },
                                    onClosed: () {
                                      _menuOpen = false;
                                      _scheduleHide();
                                    },
                                  ),
                                  IconButton(
                                    key: const Key('player-fit'),
                                    tooltip: l10n.playerAspect(
                                      widget.fit.label(l10n),
                                    ),
                                    icon: const Icon(Icons.aspect_ratio),
                                    onPressed: _cycleFit,
                                  ),
                                  IconButton(
                                    key: const Key('player-fullscreen'),
                                    tooltip: widget.fullscreen
                                        ? l10n.playerExitFullscreen
                                        : l10n.playerFullscreen,
                                    icon: Icon(
                                      widget.fullscreen
                                          ? Icons.fullscreen_exit
                                          : Icons.fullscreen,
                                    ),
                                    onPressed: () {
                                      _scheduleHide();
                                      widget.onToggleFullscreen();
                                    },
                                  ),
                                  PopupMenuButton<_More>(
                                    key: const Key('player-more'),
                                    tooltip: l10n.actionMore,
                                    onOpened: () {
                                      _menuOpen = true;
                                      _hideTimer?.cancel();
                                    },
                                    onCanceled: () {
                                      _menuOpen = false;
                                      _scheduleHide();
                                    },
                                    onSelected: _onMore,
                                    itemBuilder: (_) => [
                                      CheckedPopupMenuItem(
                                        value: _More.repeat,
                                        checked: v.isLooping,
                                        child: Text(l10n.playerRepeat),
                                      ),
                                      PopupMenuItem(
                                        value: _More.sleep,
                                        child: Text(
                                          sleepMinutes == null
                                              ? l10n.playerSleepTimer
                                              : l10n.playerSleepTimerSet(
                                                  sleepMinutes,
                                                ),
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: _More.frame,
                                        child: Text(l10n.playerSaveFrame),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Previous file, play or pause, next file, in the middle of a video.
class _CentreButtons extends StatelessWidget {
  const _CentreButtons({
    required this.controller,
    required this.visible,
    required this.onPrevious,
    required this.onNext,
  });

  final VideoPlayerController controller;
  final bool visible;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final v = controller.value;
    if (v.isBuffering && v.isPlaying) {
      return const IgnorePointer(
        child: SizedBox.square(
          dimension: 56,
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (!visible) return const SizedBox.shrink();
    final (icon, tip) = playbackEnded(v)
        ? (Icons.replay, l10n.playerReplay)
        : v.isPlaying
        ? (Icons.pause, l10n.playerPause)
        : (Icons.play_arrow, l10n.playerPlay);
    Widget round({
      required Key key,
      required String tooltip,
      required IconData icon,
      required VoidCallback? onPressed,
      double size = 32,
    }) => Material(
      color: scheme.scrim.withValues(alpha: 0.5),
      shape: const CircleBorder(),
      child: IconButton(
        key: key,
        tooltip: tooltip,
        iconSize: size,
        color: scheme.onSurface,
        disabledColor: scheme.onSurface.withValues(alpha: 0.3),
        padding: const EdgeInsets.all(12),
        icon: Icon(icon),
        onPressed: onPressed,
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        round(
          key: const Key('player-previous'),
          tooltip: l10n.playerPrevious,
          icon: Icons.skip_previous,
          onPressed: onPrevious,
        ),
        const SizedBox(width: 20),
        round(
          key: const Key('player-play'),
          tooltip: tip,
          icon: icon,
          size: 48,
          onPressed: () => togglePlayback(controller),
        ),
        const SizedBox(width: 20),
        round(
          key: const Key('player-next'),
          tooltip: l10n.playerNext,
          icon: Icons.skip_next,
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, super.key});

  final IconData? icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.scrim.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: theme.colorScheme.onSurface),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
