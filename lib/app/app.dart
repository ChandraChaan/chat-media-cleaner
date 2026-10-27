import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../features/access/presentation/access_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/settings/presentation/settings_controller.dart';
import '../l10n/app_localizations.dart';
import 'widgets.dart';

class ChatMediaCleanerApp extends StatelessWidget {
  const ChatMediaCleanerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomeGate(),
    );
  }
}

/// Shows the folder explainer until a folder was chosen, then the home
/// screen.
class HomeGate extends ConsumerWidget {
  const HomeGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    return switch (settings) {
      AsyncData(:final value) when value.sources.isEmpty =>
        const AccessScreen(),
      AsyncData() => const HomeScreen(),
      AsyncError() => Scaffold(
        body: ErrorPanel(
          onRetry: () => ref.invalidate(settingsControllerProvider),
        ),
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}
