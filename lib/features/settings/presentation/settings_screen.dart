import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets.dart';
import '../../../core/l10n.dart';
import '../../../core/media_labels.dart';
import '../../access/presentation/access_screen.dart';
import '../../media/domain/media_source.dart';
import '../../trash/presentation/trash_controller.dart';
import '../domain/app_settings.dart';
import 'settings_controller.dart';

/// App version shown in About; keep in step with pubspec.yaml.
const appVersion = '1.0.0';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: switch (settings) {
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            SectionTitle(l10n.settingsTrash),
            _ChoiceTile<int>(
              key: const Key('trash-days'),
              title: l10n.trashDaysSetting,
              value: value.trashDays,
              choices: AppSettings.trashDayChoices,
              label: l10n.days,
              onChanged: (days) async {
                await controller.setTrashDays(days);
                await ref
                    .read(trashControllerProvider.notifier)
                    .deleteExpired();
              },
            ),
            SectionTitle(l10n.settingsGroups),
            _ChoiceTile<int>(
              key: const Key('old-months'),
              title: l10n.oldMonthsSetting,
              value: value.oldAfterMonths,
              choices: AppSettings.oldAfterMonthChoices,
              label: l10n.months,
              onChanged: controller.setOldAfterMonths,
            ),
            SectionTitle(l10n.settingsFolders),
            for (final source in value.sources)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_outlined),
                title: Text(source.app.label(l10n)),
                subtitle: Text(SourceLocator.pathOf(source.rootId)),
                trailing: IconButton(
                  tooltip: l10n.removeAccess,
                  icon: const Icon(Icons.link_off),
                  onPressed: () => _remove(context, ref, source),
                ),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.add),
              title: Text(l10n.addFolder),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AccessScreen(pushed: true),
                ),
              ),
            ),
            SectionTitle(l10n.settingsAbout),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_outline),
              title: Text(l10n.privacyTitle),
              subtitle: Text(l10n.privacyBody),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.notAffiliatedTitle),
              subtitle: Text(l10n.notAffiliated),
            ),
            AboutListTile(
              icon: const Icon(Icons.description_outlined),
              applicationName: l10n.appTitle,
              applicationVersion: appVersion,
              applicationLegalese: l10n.legalese,
              child: Text(l10n.aboutAndLicenses),
            ),
          ],
        ),
        AsyncError() => ErrorPanel(
          onRetry: () => ref.invalidate(settingsControllerProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    MediaSource source,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeAccessTitle(source.app.label(l10n))),
        content: Text(l10n.removeAccessBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.removeAccess),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(trashControllerProvider.notifier).deleteForSource(source.id);
    await ref.read(settingsControllerProvider.notifier).removeSource(source);
  }
}

/// A list tile with a drop-down of number choices, for example days.
class _ChoiceTile<T extends Object> extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.value,
    required this.choices,
    required this.label,
    required this.onChanged,
    super.key,
  });

  final String title;
  final T value;
  final List<T> choices;
  final String Function(T value) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      trailing: DropdownButton<T>(
        value: value,
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
        items: [
          for (final c in choices)
            DropdownMenuItem(value: c, child: Text(label(c))),
        ],
      ),
    );
  }
}
