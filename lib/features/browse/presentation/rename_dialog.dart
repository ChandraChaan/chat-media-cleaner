import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../media/domain/media_file.dart';
import '../domain/browse_entry.dart';
import '../domain/file_names.dart';
import 'browse_controller.dart';

/// Asks for a new name for [file] (a file or a folder) and renames it.
/// Returns the renamed item, or null when the user backed out.
Future<MediaFile?> showRenameDialog(BuildContext context, MediaFile file) {
  final l10n = context.l10n;
  return showDialog<MediaFile>(
    context: context,
    builder: (_) => _NameDialog(
      title: l10n.renameTitle,
      label: file.isFolder ? l10n.nameLabel : l10n.renameLabel,
      initialName: file.name,
      selectStem: !file.isFolder,
      action: l10n.actionRename,
      warning: l10n.renameWarning,
      submit: (ref, name) => ref.read(fileOpsProvider).rename(file, name),
    ),
  );
}

/// Asks for a name and makes a new folder in [location]. Returns it, or
/// null when the user backed out.
Future<MediaFile?> showNewFolderDialog(
  BuildContext context,
  BrowseLocation location,
) {
  final l10n = context.l10n;
  return showDialog<MediaFile>(
    context: context,
    builder: (_) => _NameDialog(
      title: l10n.newFolderTitle,
      label: l10n.nameLabel,
      initialName: l10n.newFolderDefaultName,
      selectStem: false,
      action: l10n.actionCreate,
      submit: (ref, name) =>
          ref.read(fileOpsProvider).createFolder(location, name),
    ),
  );
}

/// Asks for an archive name and packs [items] into it. Returns the
/// archive, or null when the user backed out.
Future<MediaFile?> showCompressDialog(
  BuildContext context,
  BrowseLocation location,
  List<MediaFile> items,
) {
  final l10n = context.l10n;
  final base = items.length == 1
      ? items.single.name.substring(
          0,
          items.single.isFolder
              ? items.single.name.length
              : FileNames.stemLength(items.single.name),
        )
      : l10n.archiveDefaultName;
  return showDialog<MediaFile>(
    context: context,
    builder: (_) => _NameDialog(
      title: l10n.compressTitle(items.length),
      label: l10n.nameLabel,
      initialName: '$base.zip',
      selectStem: true,
      action: l10n.actionCompress,
      submit: (ref, name) =>
          ref.read(fileOpsProvider).compress(location, items, name),
    ),
  );
}

class _NameDialog extends ConsumerStatefulWidget {
  const _NameDialog({
    required this.title,
    required this.label,
    required this.initialName,
    required this.selectStem,
    required this.action,
    required this.submit,
    this.warning,
  });

  final String title;
  final String label;
  final String initialName;

  /// Selects the name without its extension, ready to type over; otherwise
  /// all of it.
  final bool selectStem;
  final String action;
  final String? warning;
  final Future<RenameResult> Function(WidgetRef ref, String name) submit;

  @override
  ConsumerState<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends ConsumerState<_NameDialog> {
  late final TextEditingController _name;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final name = widget.initialName;
    _name = TextEditingController(text: name)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.selectStem
            ? FileNames.stemLength(name)
            : name.length,
      );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await widget.submit(ref, _name.text);
    if (!mounted) return;
    final l10n = context.l10n;
    switch (result) {
      case Renamed(:final file):
        Navigator.of(context).pop(file);
      case RenameRejected(:final problem):
        setState(() {
          _busy = false;
          _error = switch (problem) {
            NameProblem.empty => l10n.renameEmpty,
            NameProblem.badCharacter => l10n.renameBadCharacter,
            NameProblem.reserved => l10n.renameReserved,
            NameProblem.tooLong => l10n.renameTooLong,
          };
        });
      case RenameNameTaken():
        setState(() {
          _busy = false;
          _error = l10n.renameTaken;
        });
      case RenameFailed():
        setState(() {
          _busy = false;
          _error = l10n.renameFailed;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('rename-field'),
            controller: _name,
            autofocus: true,
            enabled: !_busy,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              labelText: widget.label,
              errorText: _error,
              errorMaxLines: 3,
              border: const OutlineInputBorder(),
            ),
          ),
          if (widget.warning case final warning?) ...[
            const SizedBox(height: 12),
            Text(
              warning,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const Key('rename-save'),
          onPressed: _busy ? null : _save,
          child: Text(widget.action),
        ),
      ],
    );
  }
}
