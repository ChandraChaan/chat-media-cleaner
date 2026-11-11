import 'package:flutter/material.dart';

import '../../../core/l10n.dart';
import '../../browse/presentation/browse_home.dart';
import 'home_screen.dart';

/// The two halves of the app behind a bottom bar: cleaning up, and
/// browsing files.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

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
