import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../access/presentation/storage_access_controller.dart';
import '../../browse/presentation/browse_home.dart';
import 'home_screen.dart';

/// The two halves of the app behind a bottom bar: cleaning up, and
/// browsing files.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _tab = 0;

  /// All-files access can be given or taken away in system settings while
  /// the app is in the background; check again when it comes back.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () =>
        ref.read(allFilesAccessControllerProvider.notifier).refresh(),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Back from the Files tab goes to the first tab before leaving the app.
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tab = 0);
      },
      child: Scaffold(
        body: _tab == 0 ? const HomeScreen() : const BrowseHome(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (tab) => setState(() => _tab = tab),
          destinations: [
            NavigationDestination(
              key: const Key('tab-clean'),
              icon: const Icon(Icons.cleaning_services_outlined),
              selectedIcon: const Icon(Icons.cleaning_services),
              label: l10n.tabClean,
            ),
            NavigationDestination(
              key: const Key('tab-files'),
              icon: const Icon(Icons.folder_outlined),
              selectedIcon: const Icon(Icons.folder),
              label: l10n.tabFiles,
            ),
          ],
        ),
      ),
    );
  }
}
