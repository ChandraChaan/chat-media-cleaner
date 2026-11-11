import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../app/providers.dart';
import '../../../core/l10n.dart';
import '../../../core/media_labels.dart';
import '../../media/domain/media_file.dart';
import '../../media/domain/media_storage.dart';
import '../../media/domain/media_type.dart';
import '../../review/presentation/review_controller.dart';
import '../domain/view_kind.dart';
import 'file_actions.dart';
import 'media_player_host.dart';
import 'player_controls.dart';
import 'viewer_controller.dart';

/// A photo, sticker or animated image: pinch or double-tap to zoom.
class ImagePage extends ConsumerStatefulWidget {
  const ImagePage({
    required this.file,
    required this.active,
    required this.onTap,
    required this.onZoomChanged,
    super.key,
  });

  final MediaFile file;
  final bool active;
  final VoidCallback onTap;

  /// Called when the picture becomes zoomed in or back to normal, so the
  /// viewer can stop swiping to the next file meanwhile.
  final ValueChanged<bool> onZoomChanged;

  @override
  ConsumerState<ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends ConsumerState<ImagePage> {
  static const _doubleTapScale = 2.5;

  final _transform = TransformationController();
  Offset _doubleTapAt = Offset.zero;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
  }

  @override
  void didUpdateWidget(ImagePage old) {
    super.didUpdateWidget(old);
    if (old.active && !widget.active) _transform.value = Matrix4.identity();
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _onTransform() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed == _zoomed) return;
    _zoomed = zoomed;
    widget.onZoomChanged(zoomed);
  }

  void _onDoubleTap() {
    if (_zoomed) {
      _transform.value = Matrix4.identity();
      return;
    }
    const s = _doubleTapScale;
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        -_doubleTapAt.dx * (s - 1),
        -_doubleTapAt.dy * (s - 1),
        0,
        1,
      )
      ..scaleByDouble(s, s, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    final bytes = ref.watch(previewBytesProvider(file.ref));
    // Decoded no larger than twice the screen: enough to zoom into, and a
    // 50-megapixel photo does not use up the phone's memory.
    final decodeWidth =
        (MediaQuery.sizeOf(context).shortestSide *
                MediaQuery.devicePixelRatioOf(context) *
                2)
            .round()
            .clamp(1080, 4096);
    return GestureDetector(
      key: const Key('image-gestures'),
      onTap: widget.onTap,
      onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
      onDoubleTap: _onDoubleTap,
      child: InteractiveViewer(
        transformationController: _transform,
        maxScale: 6,
        child: SizedBox.expand(
          child: switch (bytes) {
            AsyncData(:final value) => Image.memory(
              value,
              cacheWidth: decodeWidth,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              semanticLabel: file.name,
              errorBuilder: (_, _, _) => Poster(file: file),
            ),
            // Too large to load whole, or unreadable: a smaller picture
            // still shows what it is.
            AsyncError() => Poster(file: file),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }
}

/// A reduced picture of a file, or its type icon when there is none.
class Poster extends ConsumerWidget {
  const Poster({required this.file, super.key});

  final MediaFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poster = ref.watch(posterProvider(file.ref));
    final icon = Center(
      child: Icon(
        ViewKinds.of(name: file.name, mimeType: file.mimeType).icon,
        size: 96,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
    return switch (poster) {
      AsyncData(:final value?) => Image.memory(
        value,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => icon,
      ),
      _ => icon,
    };
  }
}

/// A video with the full set of player gestures and controls.
class VideoPage extends StatefulWidget {
  const VideoPage({
    required this.file,
    required this.active,
    required this.controlsVisible,
    required this.onControlsVisibleChanged,
    required this.fullscreen,
    required this.onToggleFullscreen,
    required this.topInset,
    this.onPrevious,
    this.onNext,
    super.key,
  });

  final MediaFile file;
  final bool active;
  final bool controlsVisible;
  final ValueChanged<bool> onControlsVisibleChanged;
  final bool fullscreen;

  /// Called with whether the video is wider than it is tall.
  final ValueChanged<bool> onToggleFullscreen;
  final double topInset;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  VideoFit _fit = VideoFit.fit;

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    // WhatsApp stores GIFs as short silent videos.
    final gif = file.type == MediaType.gif;
    return MediaPlayerHost(
      file: file,
      active: widget.active,
      keepScreenOn: true,
      silentLoop: gif,
      resume: !gif,
      loading: Stack(
        fit: StackFit.expand,
        children: [
          Poster(file: file),
          const Center(child: CircularProgressIndicator()),
        ],
      ),
      failed: ViewerFallback(
        file: file,
        topInset: widget.topInset,
        message: context.l10n.viewerCantPlay,
      ),
      builder: (context, controller, resumedFrom) {
        final size = controller.value.size.isEmpty
            ? const Size(16, 9)
            : controller.value.size;
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: FittedBox(
                fit: _fit.boxFit,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
            VideoControls(
              controller: controller,
              file: file,
              visible: widget.controlsVisible,
              onVisibleChanged: widget.onControlsVisibleChanged,
              fullscreen: widget.fullscreen,
              onToggleFullscreen: () =>
                  widget.onToggleFullscreen(size.aspectRatio > 1),
              fit: _fit,
              onFitChanged: (fit) => setState(() => _fit = fit),
              onPrevious: widget.onPrevious,
              onNext: widget.onNext,
              resumedFrom: resumedFrom,
              bottomInset: MediaQuery.viewPaddingOf(context).bottom,
            ),
          ],
        );
      },
    );
  }
}

/// A voice note or other sound, with a scrub bar and speed.
class AudioPage extends StatelessWidget {
  const AudioPage({
    required this.file,
    required this.active,
    required this.topInset,
    super.key,
  });

  final MediaFile file;
  final bool active;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return MediaPlayerHost(
      file: file,
      active: active,
      loading: const Center(child: CircularProgressIndicator()),
      failed: ViewerFallback(
        file: file,
        topInset: topInset,
        message: context.l10n.viewerCantPlay,
      ),
      builder: (context, controller, _) =>
          _AudioPlayer(file: file, controller: controller, topInset: topInset),
    );
  }
}

class _AudioPlayer extends StatelessWidget {
  const _AudioPlayer({
    required this.file,
    required this.controller,
    required this.topInset,
  });

  final MediaFile file;
  final VideoPlayerController controller;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      top: false,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, topInset + 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 56,
                backgroundColor: scheme.primaryContainer,
                child: Icon(
                  file.type == MediaType.voiceNote
                      ? Icons.mic
                      : Icons.music_note,
                  size: 56,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                file.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              PlayerScrubber(controller: controller),
              const SizedBox(height: 8),
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller,
                builder: (context, v, _) {
                  final (icon, tip) = playbackEnded(v)
                      ? (Icons.replay, l10n.playerReplay)
                      : v.isPlaying
                      ? (Icons.pause, l10n.playerPause)
                      : (Icons.play_arrow, l10n.playerPlay);
                  return Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      IconButton(
                        tooltip: l10n.playerBack(skipStep.inSeconds),
                        color: scheme.onSurface,
                        icon: const Icon(Icons.replay_10),
                        onPressed: () =>
                            skipPlayback(controller, forward: false),
                      ),
                      IconButton.filled(
                        key: const Key('player-play'),
                        tooltip: tip,
                        iconSize: 40,
                        padding: const EdgeInsets.all(12),
                        icon: Icon(icon),
                        onPressed: () => togglePlayback(controller),
                      ),
                      IconButton(
                        tooltip: l10n.playerForward(skipStep.inSeconds),
                        color: scheme.onSurface,
                        icon: const Icon(Icons.forward_10),
                        onPressed: () =>
                            skipPlayback(controller, forward: true),
                      ),
                      SpeedMenu(controller: controller),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A PDF as a column of pages: scroll to read, pinch or double-tap to zoom.
class PdfPage extends ConsumerStatefulWidget {
  const PdfPage({
    required this.file,
    required this.topInset,
    required this.onZoomChanged,
    super.key,
  });

  final MediaFile file;
  final double topInset;
  final ValueChanged<bool> onZoomChanged;

  @override
  ConsumerState<PdfPage> createState() => _PdfPageState();
}

class _PdfPageState extends ConsumerState<PdfPage> {
  static const _doubleTapScale = 2.0;

  late final MediaViewer _viewer;
  final _transform = TransformationController();
  final _scroll = ScrollController();
  Offset _doubleTapAt = Offset.zero;
  bool _zoomed = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _viewer = ref.read(mediaViewerProvider);
    _transform.addListener(_onTransform);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _transform.dispose();
    _scroll.dispose();
    unawaited(
      _viewer.closePdf().catchError((Object e, StackTrace stack) {
        developer.log('Closing the PDF failed', error: e, stackTrace: stack);
      }),
    );
    super.dispose();
  }

  void _onTransform() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed == _zoomed) return;
    setState(() => _zoomed = zoomed);
    widget.onZoomChanged(zoomed);
  }

  void _onScroll() {
    final max = _scroll.position.maxScrollExtent;
    final progress = max <= 0 ? 0.0 : (_scroll.offset / max).clamp(0.0, 1.0);
    if ((progress - _progress).abs() > 0.001) {
      setState(() => _progress = progress);
    }
  }

  void _onDoubleTap() {
    if (_zoomed) {
      _transform.value = Matrix4.identity();
      return;
    }
    const s = _doubleTapScale;
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        -_doubleTapAt.dx * (s - 1),
        -_doubleTapAt.dy * (s - 1),
        0,
        1,
      )
      ..scaleByDouble(s, s, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final file = widget.file;
    final count = ref.watch(pdfPageCountProvider(file.ref));
    return switch (count) {
      AsyncData(:final value) when value > 0 => LayoutBuilder(
        builder: (context, box) {
          // Sharper than the screen, so a zoomed page stays readable.
          final width =
              (box.maxWidth * MediaQuery.devicePixelRatioOf(context) * 1.5)
                  .round()
                  .clamp(720, 2048);
          final current = (_progress * (value - 1)).round() + 1;
          return Stack(
            children: [
              GestureDetector(
                onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
                onDoubleTap: _onDoubleTap,
                child: InteractiveViewer(
                  transformationController: _transform,
                  panEnabled: _zoomed,
                  maxScale: 5,
                  child: ListView.builder(
                    key: const Key('pdf-pages'),
                    controller: _scroll,
                    // While zoomed in, one finger moves around the page
                    // instead of scrolling to the next one.
                    physics: _zoomed
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    padding: EdgeInsets.only(
                      top: widget.topInset + 8,
                      bottom: MediaQuery.viewPaddingOf(context).bottom + 56,
                    ),
                    itemCount: value,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PdfPageImage(
                        page: (file: file.ref, index: index, width: width),
                        label: l10n.pdfPage(index + 1, value),
                      ),
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                bottom: MediaQuery.viewPaddingOf(context).bottom + 12,
                start: 0,
                end: 0,
                child: IgnorePointer(
                  child: Center(
                    child: _Badge(text: l10n.pdfPage(current, value)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      AsyncData() => ViewerFallback(
        file: file,
        topInset: widget.topInset,
        message: l10n.viewerCantShow,
      ),
      AsyncError(:final error) => ViewerFallback(
        file: file,
        topInset: widget.topInset,
        message: error is StorageException && error.error == StorageError.locked
            ? l10n.viewerPdfLocked
            : l10n.viewerCantShow,
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _PdfPageImage extends ConsumerWidget {
  const _PdfPageImage({required this.page, required this.label});

  final PdfPageRef page;
  final String label;

  /// The shape of an A4 page, used until the real one is known.
  static const _defaultAspect = 1 / 1.414;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final image = ref.watch(pdfPageProvider(page));
    return switch (image) {
      AsyncData(:final value) => AspectRatio(
        aspectRatio: value.width / value.height,
        child: Image.memory(
          value.bytes,
          fit: BoxFit.fill,
          gaplessPlayback: true,
          semanticLabel: label,
        ),
      ),
      AsyncError() => AspectRatio(
        aspectRatio: _defaultAspect,
        child: ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: scheme.onSurfaceVariant,
              semanticLabel: label,
            ),
          ),
        ),
      ),
      _ => AspectRatio(
        aspectRatio: _defaultAspect,
        child: ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: const Center(child: CircularProgressIndicator()),
        ),
      ),
    };
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.inverseSurface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          text,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onInverseSurface,
          ),
        ),
      ),
    );
  }
}

/// The beginning of a text file, selectable.
class TextPage extends ConsumerWidget {
  const TextPage({required this.file, required this.topInset, super.key});

  final MediaFile file;
  final double topInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final text = ref.watch(textPreviewProvider(file.ref));
    return switch (text) {
      AsyncData(:final value) => ColoredBox(
        color: theme.colorScheme.surface,
        child: Scrollbar(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              topInset + 12,
              16,
              MediaQuery.viewPaddingOf(context).bottom + 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectableText(
                  value,
                  key: const Key('text-content'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (file.size > textPreviewBytes) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.viewerTextTruncated,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      AsyncError() => ViewerFallback(
        file: file,
        topInset: topInset,
        message: l10n.viewerCantShow,
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

/// Shown for files the app cannot draw or play: what the file is, why
/// there is nothing to see, and a way to open it in another app.
class ViewerFallback extends ConsumerWidget {
  const ViewerFallback({
    required this.file,
    required this.topInset,
    required this.message,
    super.key,
  });

  final MediaFile file;
  final double topInset;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      top: false,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(32, topInset + 16, 32, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(file.type.icon, size: 72, color: scheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                file.name,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                key: const Key('fallback-open-with'),
                onPressed: () => openWith(context, ref, file),
                icon: const Icon(Icons.open_in_new),
                label: Text(l10n.openWith),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
