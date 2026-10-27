import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets.dart';
import '../../../core/l10n.dart';
import '../../../core/media_labels.dart';
import '../../media/domain/media_source.dart';
import '../../settings/presentation/settings_controller.dart';

/// Explains why the app needs a folder and opens the system folder picker.
///
/// Shown on first start, and pushed from Settings to add another folder
/// ([pushed] is then true and the screen closes after a folder is added).
class AccessScreen extends ConsumerStatefulWidget {
  const AccessScreen({this.pushed = false, super.key});

  final bool pushed;

  @override
  ConsumerState<AccessScreen> createState() => _AccessScreenState();
}

class _AccessScreenState extends ConsumerState<AccessScreen> {
  bool _busy = false;

  Future<void> _choose(ChatApp app) async {
    setState(() => _busy = true);
    final result = await ref
        .read(settingsControllerProvider.notifier)
        .addFolder(app);
    if (!mounted) return;
    setState(() => _busy = false);
    final l10n = context.l10n;
    switch (result) {
      case FolderAdded(:final sources):
        showMessage(
          context,
          l10n.folderAdded(sources.map((s) => s.app.label(l10n)).join(', ')),
        );
        if (widget.pushed) Navigator.of(context).pop();
      case FolderPickCancelled():
        break;
      case FolderNotChatMedia():
        showMessage(context, l10n.folderNotChatMedia);
      case FolderPickFailed():
        showMessage(context, l10n.folderPickFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pushed ? l10n.addFolderTitle : l10n.appTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Center(
              child: CircleAvatar(
                radius: 36,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.folder_open,
                  size: 36,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.accessTitle,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(l10n.accessBody, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 20),
            _Steps(
              steps: [l10n.accessStep1, l10n.accessStep2, l10n.accessStep3],
            ),
            const SizedBox(height: 20),
            _Promise(icon: Icons.folder_outlined, text: l10n.promiseOnlyFolder),
            _Promise(icon: Icons.wifi_off, text: l10n.promiseOffline),
            _Promise(icon: Icons.checklist, text: l10n.promiseReview),
            _Promise(icon: Icons.restore, text: l10n.promiseTrash),
            const SizedBox(height: 20),
            Text(
              l10n.accessLegacyHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.notAffiliated,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      // The two choices stay on screen however far the text is scrolled.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                key: const Key('choose-whatsapp'),
                onPressed: _busy ? null : () => _choose(ChatApp.whatsapp),
                icon: const Icon(Icons.folder_open),
                label: Text(l10n.chooseWhatsAppFolder),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('choose-business'),
                onPressed: _busy
                    ? null
                    : () => _choose(ChatApp.whatsappBusiness),
                icon: const Icon(Icons.storefront_outlined),
                label: Text(l10n.chooseBusinessFolder),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, step) in steps.indexed)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(
                        '${i + 1}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(step, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Promise extends StatelessWidget {
  const _Promise({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
