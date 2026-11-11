import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/l10n.dart';
import '../../../core/theme.dart';
import '../../media/domain/media_file.dart';
import '../../media/domain/media_storage.dart';
import '../../review/presentation/move_to_trash_flow.dart';
import '../../review/presentation/review_controller.dart';
import '../domain/view_kind.dart';
import 'file_actions.dart';
import 'viewer_pages.dart';

/// Opens [files] in the viewer, starting at [index]. With a
/// [selectionTarget] the viewer also offers to select the file for the
/// review screen it was opened from.
Future<void> openViewer(
  BuildContext context, {
  required List<MediaFile> files,
  required int index,
  ReviewTarget? selectionTarget,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => ViewerScreen(
      files: files,
      initialIndex: index,
      selectionTarget: selectionTarget,
    ),
  ),
);

enum _ViewerMenu { details, openWith }

/// Shows files one at a time, full screen: swipe sideways for the next
/// one (on a video, use its previous and next buttons). Photos and videos, voice notes and audio, PDFs and text open right
/// here; anything else is offered to another app.
class ViewerScreen extends ConsumerStatefulWidget {
  const ViewerScreen({
    required this.files,
    required this.initialIndex,
    this.selectionTarget,
    super.key,
  });

  final List<MediaFile> files;
  final int initialIndex;
  final ReviewTarget? selectionTarget;

  @override
  ConsumerState<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends ConsumerState<ViewerScreen> {
  late final List<MediaFile> _files = [...widget.files];
  late int _index = widget.initialIndex.clamp(0, _files.length - 1);
  late final PageController _pages = PageController(initialPage: _index);

  /// Whether the top bar and video controls are showing.
  bool _chrome = true;
  bool _zoomed = false;
  bool _fullscreen = false;
  late final ScreenControl _screen;

  @override
  void initState() {
    super.initState();
    _screen = ref.read(screenControlProvider);
  }

  @override
  void dispose() {
    _pages.dispose();
    if (_fullscreen) _applySystemUi(fullscreen: false, landscape: false);
    // A brightness set by swiping on a video ends with the viewer.
    unawaited(
      _screen.setBrightness(null).catchError((Object e, StackTrace stack) {
        developer.log('Brightness not reset', error: e, stackTrace: stack);
      }),
    );
    super.dispose();
  }

  /// Moves one file back or forward; videos use buttons for this, because
  /// swiping sideways on a video scrubs through it.
  void _step(int by) {
    unawaited(
      _pages.animateToPage(
        _index + by,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      ),
    );
  }

  static ViewKind _kindOf(MediaFile file) =>
      ViewKinds.of(name: file.name, mimeType: file.mimeType);

  void _applySystemUi({required bool fullscreen, required bool landscape}) {
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      ),
    );
    unawaited(
      SystemChrome.setPreferredOrientations(
        fullscreen && landscape
            ? const [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
            : const [],
      ),
    );
  }

  void _setFullscreen(bool fullscreen, {bool landscape = false}) {
    if (fullscreen == _fullscreen) return;
    setState(() => _fullscreen = fullscreen);
    _applySystemUi(fullscreen: fullscreen, landscape: landscape);
  }

  void _onPageChanged(int index) {
    setState(() {
      _index = index;
      _zoomed = false;
      _chrome = true;
    });
    if (_fullscreen && _kindOf(_files[index]) != ViewKind.video) {
      _setFullscreen(false);
    }
  }

  Future<void> _delete() async {
    final file = _files[_index];
    final moved = await moveToTrashFlow(context, ref, [file]);
    if (!mounted || !moved.contains(file.key)) return;
    if (_files.length == 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _files.removeAt(_index);
      if (_index >= _files.length) _index = _files.length - 1;
      _zoomed = false;
      _chrome = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final file = _files[_index];
    final kind = _kindOf(file);
    final immersive = kind == ViewKind.image || kind == ViewKind.video;
    final barVisible = _chrome || !immersive;
    final topInset = MediaQuery.viewPaddingOf(context).top + kToolbarHeight;
    // Media is shown on black whatever the app's theme is, so everything
    // drawn over it uses the dark colours.
    return Theme(
      data: AppTheme.dark(),
      child: Builder(
        builder: (context) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: PopScope(
            canPop: !_fullscreen,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _setFullscreen(false);
            },
            child: Scaffold(
              backgroundColor: Theme.of(context).colorScheme.scrim,
              body: Stack(
                children: [
                  PageView.builder(
                    key: const Key('viewer-pages'),
                    controller: _pages,
                    // A sideways swipe belongs to a zoomed picture (it
                    // moves around in it) and to a video (it scrubs).
                    physics: _zoomed || kind == ViewKind.video
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    itemCount: _files.length,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, i) =>
                        _buildPage(_files[i], i == _index, topInset),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _TopBar(
                      visible: barVisible,
                      file: file,
                      index: _index,
                      total: _files.length,
                      selectionTarget: widget.selectionTarget,
                      onDelete: _delete,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPage(MediaFile file, bool active, double topInset) {
    final key = ValueKey(file.key);
    void onZoomChanged(bool zoomed) {
      if (active && zoomed != _zoomed) setState(() => _zoomed = zoomed);
    }

    return switch (_kindOf(file)) {
      ViewKind.image => ImagePage(
        key: key,
        file: file,
        active: active,
        onTap: () => setState(() => _chrome = !_chrome),
        onZoomChanged: onZoomChanged,
      ),
      ViewKind.video => VideoPage(
        key: key,
        file: file,
        active: active,
        controlsVisible: _chrome,
        onControlsVisibleChanged: (visible) {
          if (active) setState(() => _chrome = visible);
        },
        fullscreen: _fullscreen,
        onToggleFullscreen: (wide) =>
            _setFullscreen(!_fullscreen, landscape: wide),
        topInset: topInset,
        onPrevious: _index > 0 ? () => _step(-1) : null,
        onNext: _index < _files.length - 1 ? () => _step(1) : null,
      ),
      ViewKind.audio => AudioPage(
        key: key,
        file: file,
        active: active,
        topInset: topInset,
      ),
      ViewKind.pdf => PdfPage(
        key: key,
        file: file,
        topInset: topInset,
        onZoomChanged: onZoomChanged,
      ),
      ViewKind.text => TextPage(key: key, file: file, topInset: topInset),
      ViewKind.other => ViewerFallback(
        key: key,
        file: file,
        topInset: topInset,
        message: context.l10n.viewerNoPreview,
      ),
    };
  }
}

/// The file's name and position, and what can be done with it.
class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.visible,
    required this.file,
    required this.index,
    required this.total,
    required this.selectionTarget,
    required this.onDelete,
  });

  final bool visible;
  final MediaFile file;
  final int index;
  final int total;
  final ReviewTarget? selectionTarget;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final target = selectionTarget;
    final selected =
        target != null &&
        ref.watch(
          selectionProvider(target).select((s) => s.contains(file.key)),
        );
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: Material(
            color: scheme.scrim.withValues(alpha: 0.65),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: kToolbarHeight,
                child: IconTheme.merge(
                  data: IconThemeData(color: scheme.onSurface),
                  child: Row(
                    children: [
                      const BackButton(),
                      Expanded(
                        // Like an app bar, the title only grows a little
                        // with the system text size so it stays one bar.
                        child: MediaQuery.withClampedTextScaling(
                          maxScaleFactor: 1.3,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                file.name,
                                key: const Key('viewer-title'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: scheme.onSurface,
                                ),
                              ),
                              if (total > 1)
                                Text(
                                  l10n.viewerPosition(index + 1, total),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (target != null)
                        IconButton(
                          key: const Key('preview-select'),
                          tooltip: selected ? l10n.selected : l10n.select,
                          isSelected: selected,
                          selectedIcon: const Icon(Icons.check_circle),
                          icon: const Icon(Icons.circle_outlined),
                          onPressed: () => ref
                              .read(selectionProvider(target).notifier)
                              .toggle(file),
                        ),
                      IconButton(
                        key: const Key('viewer-share'),
                        tooltip: l10n.actionShare,
                        icon: const Icon(Icons.share_outlined),
                        onPressed: () => shareFiles(context, ref, [file]),
                      ),
                      IconButton(
                        key: const Key('viewer-delete'),
                        tooltip: l10n.moveToTrash,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: onDelete,
                      ),
                      PopupMenuButton<_ViewerMenu>(
                        key: const Key('viewer-more'),
                        tooltip: l10n.actionMore,
                        onSelected: (item) => switch (item) {
                          _ViewerMenu.details => showFileDetails(context, file),
                          _ViewerMenu.openWith => openWith(context, ref, file),
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: _ViewerMenu.details,
                            child: Text(l10n.actionDetails),
                          ),
                          PopupMenuItem(
                            value: _ViewerMenu.openWith,
                            child: Text(l10n.openWith),
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
    );
  }
}
