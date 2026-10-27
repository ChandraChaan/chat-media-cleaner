import 'package:chat_media_cleaner/app/app.dart';
import 'package:chat_media_cleaner/app/providers.dart';
import 'package:chat_media_cleaner/features/media/domain/media_source.dart';
import 'package:chat_media_cleaner/features/settings/domain/app_settings.dart';
import 'package:chat_media_cleaner/features/trash/domain/trash_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_media_storage.dart';
import 'memory_stores.dart';

/// Everything a widget test needs, wired together with fakes.
final class TestApp {
  TestApp({
    List<MediaSource> sources = const [waSource],
    List<TrashEntry> trash = const [],
    DateTime? now,
    int trashDays = 7,
    FakeMediaStorage? storage,
  }) : storage = storage ?? FakeMediaStorage(),
       settings = MemorySettingsStore(
         AppSettings(sources: sources, trashDays: trashDays),
       ),
       trashStore = MemoryTrashIndexStore(trash),
       now = now ?? DateTime.utc(2026, 10, 27, 12) {
    for (final source in sources) {
      this.storage.grant(source.treeUri, source.rootId);
    }
  }

  final FakeMediaStorage storage;
  final MemorySettingsStore settings;
  final MemoryTrashIndexStore trashStore;
  DateTime now;

  Widget build() => ProviderScope(
    overrides: [
      mediaStorageProvider.overrideWithValue(storage),
      mediaViewerProvider.overrideWithValue(storage),
      folderAccessProvider.overrideWithValue(storage),
      settingsStoreProvider.overrideWithValue(settings),
      trashIndexStoreProvider.overrideWithValue(trashStore),
      clockProvider.overrideWithValue(() => now),
    ],
    child: const ChatMediaCleanerApp(),
  );

  /// Pumps the app on a phone-sized screen (Pixel 7: 412 x 915 dp).
  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
  }
}

const mb = 1000 * 1000;

/// A small, realistic WhatsApp media folder.
void addSampleMedia(FakeMediaStorage storage) {
  storage
    ..addFile(
      'WhatsApp Video/VID-20250101-WA0001.mp4',
      size: 48 * mb,
      modified: DateTime.utc(2025, 1, 1),
    )
    ..addFile(
      'WhatsApp Video/VID-20260901-WA0007.mp4',
      size: 12 * mb,
      modified: DateTime.utc(2026, 9, 1),
    )
    ..addFile(
      'WhatsApp Images/IMG-20240305-WA0003.jpg',
      size: 2 * mb,
      modified: DateTime.utc(2024, 3, 5),
    )
    ..addFile(
      'WhatsApp Images/Sent/IMG-20260110-WA0010.jpg',
      size: 3 * mb,
      modified: DateTime.utc(2026, 1, 10),
    )
    ..addFile(
      'WhatsApp Voice Notes/202610/PTT-20261020-WA0002.opus',
      size: 90000,
      modified: DateTime.utc(2026, 10, 20),
    )
    ..addFile(
      'WhatsApp Documents/Rent agreement.pdf',
      size: 400000,
      modified: DateTime.utc(2026, 4, 2),
    );
}
