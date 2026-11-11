import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../media/domain/media_file.dart';
import '../domain/file_names.dart';
import 'browse_controller.dart';

/// Asks for a new name for [file] and renames it. Returns the renamed
/// file, or null when the user backed out.
Future<MediaFile?> showRenameDialog(BuildContext context, MediaFile file) =>
    showDialog<MediaFile>(
      context: context,
      builder: (_) => _RenameDialog(file: file),
    );

class _RenameDialog extends ConsumerStatefulWidget {
  const _RenameDialog({required this.file});

  final MediaFile file;

  @override
  ConsumerState<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends ConsumerState<_RenameDialog> {
  late final TextEditingController _name;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final name = widget.file.name;
    // The part before the extension is selected, ready to type over.
    _name = TextEditingController(text: name)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: FileNames.stemLength(name),
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
    final result = await ref
        .read(fileOpsProvider)
        .rename(widget.file, _name.text);
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
      title: Text(l10n.renameTitle),
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
              labelText: l10n.renameLabel,
              errorText: _error,
              errorMaxLines: 3,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.renameWarning,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
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
          child: Text(l10n.actionRename),
        ),
      ],
    );
  }
}
