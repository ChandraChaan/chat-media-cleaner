import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/l10n.dart';
import '../../../core/media_labels.dart';
import '../../media/domain/media_file.dart';
import '../../media/domain/media_type.dart';
import 'review_controller.dart';

/// One file in the review grid: a thumbnail (or an icon and the name), its
/// size, and a check mark when selected.
class MediaTile extends StatelessWidget {
  const MediaTile({
    required this.file,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final MediaFile file;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final size = formatBytes(file.size, context.localeName);
    return Semantics(
      selected: selected,
      button: true,
      label: '${file.name}, $size',
      onLongPressHint: l10n.previewHint,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (file.type.hasPicture)
                FileThumbnail(fileRef: file.ref, type: file.type)
              else
                _NameTile(file: file),
              PositionedDirectional(
                start: 4,
                bottom: 4,
                child: _Label(text: size),
              ),
              if (file.type == MediaType.video || file.type == MediaType.gif)
                PositionedDirectional(
                  end: 4,
                  bottom: 4,
                  child: Icon(file.type.icon, size: 18, color: scheme.surface),
                ),
              if (selected)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.primary, width: 4),
                    borderRadius: BorderRadius.circular(8),
                    color: scheme.primary.withValues(alpha: 0.18),
                  ),
                ),
              PositionedDirectional(
                top: 6,
                end: 6,
                child: selected
                    ? CircleAvatar(
                        radius: 12,
                        backgroundColor: scheme.primary,
                        child: Icon(
                          Icons.check,
                          size: 18,
                          color: scheme.onPrimary,
                        ),
                      )
                    : Icon(
                        Icons.circle_outlined,
                        color: scheme.surface,
                        shadows: const [Shadow(blurRadius: 4)],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loads and shows a thumbnail, with the type icon while loading or when
/// there is none.
class FileThumbnail extends ConsumerWidget {
  const FileThumbnail({required this.fileRef, required this.type, super.key});

  final FileRef fileRef;
  final MediaType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumb = ref.watch(thumbnailProvider(fileRef));
    final placeholder = Center(
      child: Icon(
        type.icon,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
    return switch (thumb) {
      AsyncData(:final value?) => Image.memory(
        value,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => placeholder,
      ),
      _ => placeholder,
    };
  }
}

class _NameTile extends StatelessWidget {
  const _NameTile({required this.file});

  final MediaFile file;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(file.type.icon, color: theme.colorScheme.primary),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              file.name,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.inverseSurface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onInverseSurface,
          ),
        ),
      ),
    );
  }
}
