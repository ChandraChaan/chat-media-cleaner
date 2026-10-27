@Tags(['tools'])
library;

import 'dart:io';

import 'package:chat_media_cleaner/features/media/domain/media_scanner.dart';
import 'package:chat_media_cleaner/features/media/domain/media_storage.dart';
import 'package:chat_media_cleaner/features/media/domain/media_type.dart';
import 'package:chat_media_cleaner/features/review/presentation/media_tile.dart';
import 'package:chat_media_cleaner/features/trash/domain/trash_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_media_storage.dart';
import '../support/test_app.dart';

/// Renders the README screenshots into docs/screenshots/ with real fonts and
/// a realistic fake media folder:
///   flutter test --run-skipped --tags tools --update-goldens test/tools
void main() {
  setUpAll(_loadFonts);

  testWidgets('01 home', (tester) async {
    final app = _app();
    await app.pump(tester);
    await tester.tap(find.byKey(const Key('scan')));
    await _settleImages(tester);
    await _shot('01_home');
  });

  testWidgets('02 review', (tester) async {
    final app = _app();
    await app.pump(tester);
    await tester.tap(find.byKey(const Key('scan')));
    await tester.pumpAndSettle();
    final group = find.byKey(const Key('group-oldForwards'));
    await tester.scrollUntilVisible(group, 300);
    await tester.tap(group);
    await tester.pumpAndSettle();
    for (final i in [0, 1, 4, 6, 7]) {
      await tester.tap(find.byType(MediaTile).at(i));
    }
    await _settleImages(tester);
    await _shot('02_review');
  });

  testWidgets('03 confirm', (tester) async {
    final app = _app();
    await app.pump(tester);
    await tester.tap(find.byKey(const Key('scan')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('group-largest')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('select-all')));
    await tester.pump();
    await _settleImages(tester);
    await tester.tap(find.byKey(const Key('move-to-trash')));
    await tester.pumpAndSettle();
    await _shot('03_confirm');
  });

  testWidgets('04 trash', (tester) async {
    final app = _app(withTrash: true);
    await app.pump(tester);
    await tester.tap(find.byKey(const Key('open-trash')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('VID-20250610-WA0002.mp4'));
    await tester.tap(find.text('IMG-20250711-WA0009.jpg'));
    await _settleImages(tester);
    await _shot('04_trash');
  });

  testWidgets('05 access', (tester) async {
    final app = _app(sources: false);
    await app.pump(tester);
    await _shot('05_access');
  });
}

Future<void> _shot(String name) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('../../docs/screenshots/$name.png'),
);

/// Real fonts instead of the test font's boxes.
Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT']!;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String file) async =>
      ByteData.sublistView(await File('$dir/$file').readAsBytes());
  final roboto = FontLoader('Roboto')
    ..addFont(read('Roboto-Regular.ttf'))
    ..addFont(read('Roboto-Medium.ttf'))
    ..addFont(read('Roboto-Bold.ttf'));
  await roboto.load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(read('MaterialIcons-Regular.otf'))).load();
}

/// Decodes the thumbnails, which needs real async time.
Future<void> _settleImages(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element);
    }
  });
  await tester.pumpAndSettle();
}

final _photos = [
  for (var i = 1; i <= 16; i++)
    File('test/tools/fixtures/photo_$i.jpg').readAsBytesSync(),
];

/// A fake storage whose pictures have thumbnails.
final class _PictureStorage extends FakeMediaStorage {
  @override
  Future<Uint8List?> thumbnail(
    String treeUri,
    String fileId, {
    int size = 256,
  }) async {
    final name = fileId.substring(fileId.lastIndexOf('/') + 1);
    if (!(name.endsWith('.jpg') || name.endsWith('.mp4'))) return null;
    return _photos[name.hashCode.abs() % _photos.length];
  }
}

TestApp _app({bool sources = true, bool withTrash = false}) {
  final now = DateTime.utc(2026, 10, 27, 12);
  final trash = withTrash
      ? [
          _trashEntry('WhatsApp Video/VID-20250610-WA0002.mp4', 64, now, 1),
          _trashEntry('WhatsApp Images/IMG-20250711-WA0009.jpg', 2, now, 1),
          _trashEntry('WhatsApp Images/IMG-20250712-WA0015.jpg', 3, now, 2),
          _trashEntry(
            'WhatsApp Animated Gifs/VID-20250115-WA0004.mp4',
            1,
            now,
            4,
          ),
          _trashEntry('WhatsApp Video/VID-20250820-WA0011.mp4', 21, now, 5),
        ]
      : <TrashEntry>[];
  final storage = _PictureStorage();
  final app = TestApp(
    sources: sources ? const [waSource] : const [],
    trash: trash,
    now: now,
    storage: storage,
  );
  for (final e in trash) {
    storage.addFile(
      '${MediaScanner.trashFolderName}/${e.id}/${e.name}',
      size: e.size,
    );
  }
  _addMedia(storage);
  return app;
}

TrashEntry _trashEntry(String path, int mbs, DateTime now, int daysAgo) {
  final name = path.substring(path.lastIndexOf('/') + 1);
  final folder = path.substring(0, path.lastIndexOf('/'));
  final id = 'item-$name';
  return TrashEntry(
    id: id,
    sourceId: waTree,
    originalId: '$waMediaId/$path',
    originalParentId: '$waMediaId/$folder',
    relativePath: path,
    name: name,
    size: mbs * mb + 312000,
    modified: DateTime.utc(2025, 6, 10),
    type: MediaClassifier.classify(path),
    trashedAt: now.subtract(Duration(days: daysAgo, hours: 3)),
    item: TrashedItem(
      itemDirId: '$waMediaId/${MediaScanner.trashFolderName}/$id',
      fileId: '$waMediaId/${MediaScanner.trashFolderName}/$id/$name',
    ),
  );
}

void _addMedia(FakeMediaStorage s) {
  void add(String path, double mbs, DateTime date) =>
      s.addFile(path, size: (mbs * mb).round(), modified: date);

  // Big videos, recent and old.
  final videos = {
    'VID-20240912-WA0003.mp4': (412.0, DateTime.utc(2024, 9, 12)),
    'VID-20250301-WA0007.mp4': (9.4, DateTime.utc(2025, 3, 1)),
    'VID-20250522-WA0018.mp4': (286.5, DateTime.utc(2025, 5, 22)),
    'VID-20251103-WA0021.mp4': (148.2, DateTime.utc(2025, 11, 3)),
    'VID-20260115-WA0002.mp4': (96.7, DateTime.utc(2026, 1, 15)),
    'VID-20260420-WA0013.mp4': (64.1, DateTime.utc(2026, 4, 20)),
    'VID-20260817-WA0006.mp4': (38.9, DateTime.utc(2026, 8, 17)),
    'VID-20261002-WA0010.mp4': (12.3, DateTime.utc(2026, 10, 2)),
    'VID-20250119-WA0025.mp4': (6.8, DateTime.utc(2025, 1, 19)),
    'VID-20250705-WA0030.mp4': (4.2, DateTime.utc(2025, 7, 5)),
  };
  for (final MapEntry(key: name, value: (size, date)) in videos.entries) {
    add('WhatsApp Video/$name', size, date);
  }
  add(
    'WhatsApp Video/Sent/VID-20260601-WA0001.mp4',
    54.2,
    DateTime.utc(2026, 6, 1),
  );
  add(
    'WhatsApp Video/Sent/VID-20251224-WA0004.mp4',
    31.6,
    DateTime.utc(2025, 12, 24),
  );

  // Photos: lots of forwards.
  for (var i = 0; i < 140; i++) {
    final date = DateTime.utc(2024, 11, 1).add(Duration(days: i * 5));
    final stamp =
        '${date.year}${'${date.month}'.padLeft(2, '0')}${'${date.day}'.padLeft(2, '0')}';
    add(
      'WhatsApp Images/IMG-$stamp-WA${'${i % 50}'.padLeft(4, '0')}.jpg',
      0.08 + (i * 37 % 23) / 10,
      date,
    );
  }
  add(
    'WhatsApp Images/IMG-20250214-WA0031.jpg',
    1.9,
    DateTime.utc(2025, 2, 14),
  );
  add(
    'WhatsApp Images/IMG-20250118-WA0012.jpg',
    0.6,
    DateTime.utc(2025, 1, 18),
  );
  add('WhatsApp Images/IMG-20250402-WA0044.jpg', 2.3, DateTime.utc(2025, 4, 2));
  for (var i = 0; i < 25; i++) {
    add(
      'WhatsApp Images/Sent/IMG-20260${(i % 9) + 1}0${(i % 9) + 1}-WA00$i.jpg',
      1.2 + i % 4,
      DateTime.utc(2026, (i % 9) + 1),
    );
  }
  for (var i = 0; i < 30; i++) {
    add(
      'WhatsApp Animated Gifs/VID-2025${'${(i % 12) + 1}'.padLeft(2, '0')}10-WA00$i.mp4',
      0.4 + (i % 5) / 10,
      DateTime.utc(2025, (i % 12) + 1, 10),
    );
  }
  for (var i = 0; i < 60; i++) {
    add(
      'WhatsApp Voice Notes/2026${'${(i % 40) + 1}'.padLeft(2, '0')}/PTT-WA00$i.opus',
      0.05 + (i % 7) / 20,
      DateTime.utc(2026, 1, 1).add(Duration(days: i * 4)),
    );
  }
  for (var i = 0; i < 18; i++) {
    add(
      'WhatsApp Documents/Document $i.pdf',
      0.3 + i % 6,
      DateTime.utc(2025, (i % 12) + 1, 3),
    );
  }
  for (var i = 0; i < 90; i++) {
    add('WhatsApp Stickers/STK-WA00$i.webp', 0.03, DateTime.utc(2025, 8, 1));
  }
  for (var i = 0; i < 24; i++) {
    add(
      '.Statuses/${i.toRadixString(16).padLeft(8, 'a')}.jpg',
      0.2 + i % 3,
      DateTime.utc(2026, 10, 25),
    );
  }
  add('WhatsApp Audio/AUD-20250630-WA0001.mp3', 7.4, DateTime.utc(2025, 6, 30));

  // The same clip forwarded in several groups, and a few repeated memes.
  for (final (i, day) in [3, 9, 14, 21].indexed) {
    s.addFile(
      'WhatsApp Video/VID-202605${'$day'.padLeft(2, '0')}-WA00${40 + i}.mp4',
      size: 23400000,
      modified: DateTime.utc(2026, 5, day),
      content: 'forwarded clip',
    );
  }
  for (var i = 0; i < 12; i++) {
    s.addFile(
      'WhatsApp Images/IMG-20260${(i % 6) + 1}15-WA01$i.jpg',
      size: 180000 + (i % 3) * 1000,
      modified: DateTime.utc(2026, (i % 6) + 1, 15),
      content: 'meme ${i % 3}',
    );
  }
}
