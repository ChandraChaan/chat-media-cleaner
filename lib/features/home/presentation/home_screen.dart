import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../../../core/l10n.dart';
import '../../../core/media_labels.dart';
import '../../../core/theme.dart';
import '../../access/presentation/access_screen.dart';
import '../../media/domain/media_report.dart';
import '../../media/domain/media_scanner.dart';
import '../../media/domain/media_type.dart';
import '../../review/presentation/review_controller.dart';
import '../../review/presentation/review_screen.dart';
import '../../settings/domain/app_settings.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../trash/presentation/trash_controller.dart';
import '../../trash/presentation/trash_screen.dart';
import 'scan_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scan = ref.watch(scanControllerProvider);
    final trashCount = ref.watch(
      trashControllerProvider.select((t) => t.value?.length ?? 0),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            key: const Key('open-trash'),
            tooltip: l10n.trashTooltip(trashCount),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TrashScreen()),
            ),
            // The tooltip already says how many files; the badge would
            // otherwise be read out instead of the button's name.
            icon: ExcludeSemantics(
              child: Badge.count(
                count: trashCount,
                isLabelVisible: trashCount > 0,
                child: const Icon(Icons.delete_outline),
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.settingsTitle,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const _SourcesRow(),
            const SizedBox(height: 12),
            switch (scan) {
              ScanIdle() => const _ScanPrompt(),
              ScanRunning(:final progress) => _ScanProgressCard(progress),
              ScanFailed(:final reason) => _ScanFailedCard(reason),
              ScanReady() => const _Results(),
            },
            const _TrashCard(),
            const _FreedLine(),
          ],
        ),
      ),
    );
  }
}

class _SourcesRow extends ConsumerWidget {
  const _SourcesRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sources = ref.watch(
      settingsControllerProvider.select((s) => s.value?.sources ?? const []),
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final source in sources)
          Chip(
            avatar: const Icon(Icons.folder_outlined, size: 18),
            label: Text(source.app.label(l10n)),
          ),
        ActionChip(
          avatar: const Icon(Icons.add, size: 18),
          label: Text(l10n.addFolder),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AccessScreen(pushed: true),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanPrompt extends ConsumerWidget {
  const _ScanPrompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.scanPromptTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(l10n.scanPromptBody, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('scan'),
              onPressed: () =>
                  ref.read(scanControllerProvider.notifier).start(),
              icon: const Icon(Icons.search),
              label: Text(l10n.scanNow),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanProgressCard extends ConsumerWidget {
  const _ScanProgressCard(this.progress);

  final ScanProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = context.localeName;
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              progress.phase == ScanPhase.hashing
                  ? l10n.scanHashing(progress.hashed, progress.toHash)
                  : l10n.scanListing,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress.fraction),
            const SizedBox(height: 12),
            Text(
              l10n.scanFound(
                progress.filesFound,
                formatCount(progress.filesFound, locale),
                formatBytes(progress.bytesFound, locale),
              ),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () =>
                    ref.read(scanControllerProvider.notifier).cancel(),
                child: Text(l10n.actionCancel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanFailedCard extends ConsumerWidget {
  const _ScanFailedCard(this.reason);

  final ScanFailure reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final noAccess = reason == ScanFailure.noAccess;
    return Card.filled(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              noAccess ? l10n.scanNoAccess : l10n.scanFailed,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () =>
                      ref.read(scanControllerProvider.notifier).start(),
                  child: Text(l10n.actionRetry),
                ),
                if (noAccess)
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AccessScreen(pushed: true),
                      ),
                    ),
                    child: Text(l10n.chooseFolderAgain),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(mediaReportProvider);
    final scan = ref.watch(scanControllerProvider);
    final months = ref.watch(
      settingsControllerProvider.select(
        (s) => s.value?.oldAfterMonths ?? AppSettings.defaultOldAfterMonths,
      ),
    );
    if (report == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final partial =
        scan is ScanReady &&
        (scan.skippedFolders > 0 || scan.unavailable.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryCard(report),
        if (partial)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.scanPartial,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        SectionTitle(l10n.cleanUpTitle),
        for (final group in SmartGroup.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _GroupCard(
              group: group,
              files: report.group(group),
              description: group.description(l10n, oldAfterMonths: months),
            ),
          ),
        SectionTitle(l10n.byTypeTitle),
        _TypeList(report),
      ],
    );
  }
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard(this.report);

  final MediaReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = context.localeName;
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatBytes(report.totalBytes, locale),
                        key: const Key('total-size'),
                        style: theme.textTheme.displaySmall,
                      ),
                      Text(
                        l10n.totalFiles(
                          report.totalCount,
                          formatCount(report.totalCount, locale),
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.rescan,
                  onPressed: () =>
                      ref.read(scanControllerProvider.notifier).start(),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (report.totalBytes > 0) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: _StorageBar(report),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// Every media type with its size, largest first.
class _TypeList extends StatelessWidget {
  const _TypeList(this.report);

  final MediaReport report;

  @override
  Widget build(BuildContext context) {
    final types = report.byType.entries.toList()
      ..sort((a, b) => b.value.bytes.compareTo(a.value.bytes));
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 16, top: 4, bottom: 4),
        child: Column(
          children: [
            for (final MapEntry(key: type, value: group) in types)
              _TypeRow(type: type, group: group),
          ],
        ),
      ),
    );
  }
}

/// One bar split by type. The rows below name every type, so the colours
/// are never the only way to tell them apart.
class _StorageBar extends StatelessWidget {
  const _StorageBar(this.report);

  final MediaReport report;

  @override
  Widget build(BuildContext context) {
    final colors = MediaTypeColors.of(context);
    final total = report.totalBytes;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 12,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final MapEntry(key: type, value: group)
                  in report.byType.entries)
                if (group.bytes > 0)
                  Expanded(
                    flex: (group.bytes * 1000 / total).ceil(),
                    child: ColoredBox(color: colors.colorOf(type)),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.type, required this.group});

  final MediaType type;
  final FileGroup group;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.only(end: 12),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: MediaTypeColors.of(context).colorOf(type),
        child: Icon(
          type.icon,
          size: 18,
          color: Theme.of(context).colorScheme.surface,
        ),
      ),
      title: Text(type.label(l10n)),
      subtitle: Text(
        l10n.fileCount(group.count, formatCount(group.count, locale)),
      ),
      trailing: Text(
        formatBytes(group.bytes, locale),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      onTap: () => openReview(context, TypeReview(type)),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.files,
    required this.description,
  });

  final SmartGroup group;
  final FileGroup files;
  final String description;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = context.localeName;
    return Card.outlined(
      child: ListTile(
        key: Key('group-${group.name}'),
        enabled: !files.isEmpty,
        leading: Icon(group.icon, color: theme.colorScheme.primary),
        title: Text(group.title(l10n)),
        subtitle: Text(description),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              files.isEmpty
                  ? l10n.groupEmpty
                  : formatBytes(files.bytes, locale),
              style: theme.textTheme.titleSmall,
            ),
            if (!files.isEmpty)
              Text(
                l10n.fileCount(files.count, formatCount(files.count, locale)),
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
        onTap: () => openReview(context, GroupReview(group)),
      ),
    );
  }
}

class _TrashCard extends ConsumerWidget {
  const _TrashCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(trashControllerProvider).value ?? const [];
    if (entries.isEmpty) return const SizedBox.shrink();
    final days = ref.watch(
      settingsControllerProvider.select(
        (s) => s.value?.trashDays ?? AppSettings.defaultTrashDays,
      ),
    );
    final l10n = context.l10n;
    final locale = context.localeName;
    final bytes = entries.fold(0, (sum, e) => sum + e.size);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card.outlined(
        child: ListTile(
          leading: const Icon(Icons.delete_outline),
          title: Text(l10n.trashCardTitle(formatBytes(bytes, locale))),
          subtitle: Text(
            l10n.trashCardBody(
              entries.length,
              formatCount(entries.length, locale),
              days,
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const TrashScreen())),
        ),
      ),
    );
  }
}

class _FreedLine extends ConsumerWidget {
  const _FreedLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final freed = ref.watch(
      settingsControllerProvider.select((s) => s.value?.freedBytes ?? 0),
    );
    if (freed <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        context.l10n.freedSoFar(formatBytes(freed, context.localeName)),
        key: const Key('freed-so-far'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
