import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../trash/presentation/trash_controller.dart';
import '../../trash/presentation/trash_screen.dart';

/// Opens the trash; shows how many files are in it.
class TrashButton extends ConsumerWidget {
  const TrashButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      trashControllerProvider.select((t) => t.value?.length ?? 0),
    );
    return IconButton(
      key: const Key('open-trash'),
      tooltip: context.l10n.trashTooltip(count),
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const TrashScreen())),
      // The tooltip already says how many files; the badge would
      // otherwise be read out instead of the button's name.
      icon: ExcludeSemantics(
        child: Badge.count(
          count: count,
          isLabelVisible: count > 0,
          child: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }
}

class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.l10n.settingsTitle,
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
      icon: const Icon(Icons.settings_outlined),
    );
  }
}
