import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/l10n.dart';
import '../../../core/media_labels.dart';
import '../../access/presentation/access_screen.dart';
import '../../home/presentation/home_actions.dart';
import '../../media/domain/media_source.dart';
import '../../settings/presentation/settings_controller.dart';
import '../domain/browse_entry.dart';
import 'browse_controller.dart';
import 'folder_screen.dart';

/// The Files tab: the folders the user chose, each opening a file browser.
class BrowseHome extends ConsumerWidget {
  const BrowseHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sources = ref.watch(
      settingsControllerProvider.select((s) => s.value?.sources ?? const []),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.filesTitle),
        actions: const [TrashButton(), SettingsButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              l10n.filesIntro,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (final source in sources)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SourceCard(source: source),
              ),
            ListTile(
              key: const Key('files-add-folder'),
              leading: const Icon(Icons.add),
              title: Text(l10n.addFolder),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AccessScreen(pushed: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceCard extends ConsumerWidget {
  const _SourceCard({required this.source});

  final MediaSource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final stats = ref.watch(
      folderStatsProvider.select((s) => s[FolderStats.keyOf(source.id, '')]),
    );
    final path = SourceLocator.pathOf(source.rootId).replaceAll('/', ' › ');
    return Card.outlined(
      child: ListTile(
        key: ValueKey('source-${source.id}'),
        leading: Icon(
          Icons.folder,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(source.label(l10n)),
        subtitle: Text(
          [
            if (path.isNotEmpty) path,
            if (stats != null)
              l10n.folderStats(
                stats.count,
                formatCount(stats.count, locale),
                formatBytes(stats.bytes, locale),
              ),
          ].join('\n'),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => openFolder(context, BrowseLocation.root(source)),
      ),
    );
  }
}
