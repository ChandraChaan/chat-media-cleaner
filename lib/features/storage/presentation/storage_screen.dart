import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../../../core/l10n.dart';
import '../../../core/media_labels.dart';
import '../../access/presentation/storage_access_controller.dart';
import '../../media/domain/media_scanner.dart';
import '../../media/domain/media_storage.dart';
import '../domain/file_category.dart';
import '../domain/storage_report.dart';
import 'file_list_screen.dart';
import 'storage_scan_controller.dart';

void openStorageScreen(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const StorageScreen()));

/// Where space goes: each volume's use, space by kind of file, the largest
/// files and duplicate copies.
class StorageScreen extends ConsumerWidget {
  const StorageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final volumes = ref.watch(storageVolumesProvider).value ?? const [];
    final report = ref.watch(storageReportProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.storageTitle),
        actions: [
          if (report != null)
            IconButton(
              key: const Key('storage-rescan'),
              tooltip: l10n.rescan,
              icon: const Icon(Icons.refresh),
              onPressed: ref.read(storageScanControllerProvider.notifier).start,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            for (final volume in volumes) VolumeUsageCard(volume: volume),
            if (report == null)
              const StorageScanCard()
            else
              _ReportView(report: report),
          ],
        ),
      ),
    );
  }
}

/// A storage volume's name and how full it is.
class VolumeUsageCard extends StatelessWidget {
  const VolumeUsageCard({required this.volume, this.onTap, super.key});

  final StorageVolume volume;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final theme = Theme.of(context);
    final used = l10n.volumeUsage(
      formatBytes(volume.usedBytes, locale),
      formatBytes(volume.totalBytes, locale),
    );
    return Card.outlined(
      child: InkWell(
        key: ValueKey('volume-${volume.path}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    volume.isRemovable
                        ? Icons.sd_card_outlined
                        : Icons.smartphone,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      volume.label.isEmpty
                          ? l10n.internalStorage
                          : volume.label,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (onTap != null) const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              Semantics(
                label: used,
                child: ExcludeSemantics(
                  child: LinearProgressIndicator(
                    value: volume.usedFraction,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ExcludeSemantics(
                child: Text(
                  '$used · ${l10n.volumeFree(formatBytes(volume.freeBytes, locale))}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Starts a storage scan, or shows how far it has got.
class StorageScanCard extends ConsumerWidget {
  const StorageScanCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final theme = Theme.of(context);
    final state = ref.watch(storageScanControllerProvider);
    final controller = ref.read(storageScanControllerProvider.notifier);
    final allFiles = ref.watch(volumeSourcesProvider).isNotEmpty;
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (state) {
          StorageScanRunning(:final progress) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                progress.phase == ScanPhase.hashing
                    ? l10n.scanHashing(progress.hashed, progress.toHash)
                    : l10n.storageScanning,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress.fraction),
              const SizedBox(height: 8),
              Text(
                l10n.scanFound(
                  progress.filesFound,
                  formatCount(progress.filesFound, locale),
                  formatBytes(progress.bytesFound, locale),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: controller.cancel,
                  child: Text(l10n.actionCancel),
                ),
              ),
            ],
          ),
          StorageScanFailed() => ErrorPanel(
            message: l10n.scanFailed,
            onRetry: controller.start,
          ),
          _ => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.storageScanTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                allFiles
                    ? l10n.storageScanBodyAll
                    : l10n.storageScanBodyFolders,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('storage-scan'),
                onPressed: controller.start,
                icon: const Icon(Icons.search),
                label: Text(l10n.scanNow),
              ),
            ],
          ),
        },
      ),
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({required this.report});

  final StorageReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final total = report.totalBytes;
    final categories = [
      ...FileCategory.values,
    ]..sort((a, b) => report.usage[b]!.bytes.compareTo(report.usage[a]!.bytes));
    final duplicates = report.duplicateCopies;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(l10n.storageByType(formatBytes(total, locale))),
        Card.outlined(
          child: Column(
            children: [
              for (final category in categories)
                _CategoryRow(
                  category: category,
                  usage: report.usage[category]!,
                  total: total,
                ),
            ],
          ),
        ),
        SectionTitle(l10n.storageCleanUp),
        Card.outlined(
          child: Column(
            children: [
              ListTile(
                key: const Key('open-large-files'),
                leading: const Icon(Icons.straighten),
                title: Text(l10n.largeFilesTitle),
                subtitle: Text(
                  l10n.listSummary(
                    report.largest.length,
                    formatCount(report.largest.length, locale),
                    formatBytes(
                      report.largest.fold(0, (sum, f) => sum + f.size),
                      locale,
                    ),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openFileList(context, const LargeFiles()),
              ),
              ListTile(
                key: const Key('open-duplicates'),
                leading: const Icon(Icons.content_copy),
                title: Text(l10n.duplicateFilesTitle),
                subtitle: Text(
                  l10n.duplicatesSummary(
                    duplicates.length,
                    formatCount(duplicates.length, locale),
                    formatBytes(report.duplicateBytes, locale),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openFileList(context, const DuplicateFiles()),
              ),
            ],
          ),
        ),
        if (report.skippedFolders > 0)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              l10n.storageSkipped,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.usage,
    required this.total,
  });

  final FileCategory category;
  final CategoryUsage usage;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final share = total <= 0 ? 0.0 : usage.bytes / total;
    return ListTile(
      key: Key('category-${category.name}'),
      leading: Icon(category.icon),
      title: Text(category.label(l10n)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.listSummary(
              usage.count,
              formatCount(usage.count, locale),
              formatBytes(usage.bytes, locale),
            ),
          ),
          const SizedBox(height: 6),
          ExcludeSemantics(
            child: LinearProgressIndicator(
              value: share,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => openFileList(context, CategoryFiles(category)),
    );
  }
}
