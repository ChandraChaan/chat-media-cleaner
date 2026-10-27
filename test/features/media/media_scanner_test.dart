import 'package:chat_media_cleaner/features/media/domain/cancel_token.dart';
import 'package:chat_media_cleaner/features/media/domain/media_scanner.dart';
import 'package:chat_media_cleaner/features/media/domain/media_type.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_media_storage.dart';

void main() {
  late FakeMediaStorage storage;
  late MediaScanner scanner;

  setUp(() {
    storage = FakeMediaStorage()
      ..grant(waTree, waMediaId)
      ..addFile(
        'WhatsApp Images/IMG-1.jpg',
        size: 2000,
        modified: DateTime.utc(2024, 3, 1, 10),
      )
      ..addFile('WhatsApp Images/Sent/IMG-2.jpg', size: 3000)
      ..addFile('WhatsApp Images/.nomedia', size: 0)
      ..addFile('WhatsApp Video/VID-1.mp4', size: 50000)
      ..addFile('WhatsApp Voice Notes/202410/PTT-1.opus', size: 400)
      ..addFile('WhatsApp Voice Notes/202411/PTT-2.opus', size: 500)
      ..addFile('.Statuses/abc.jpg', size: 700)
      ..addFile('${MediaScanner.trashFolderName}/x/IMG-old.jpg', size: 9999)
      ..addDir('WhatsApp Documents');
    scanner = MediaScanner(storage);
  });

  test('lists every media file below the Media folder', () async {
    final outcome = await scanner.scan([waSource]);
    expect(
      outcome.files.map((f) => f.relativePath),
      unorderedEquals([
        'WhatsApp Images/IMG-1.jpg',
        'WhatsApp Images/Sent/IMG-2.jpg',
        'WhatsApp Video/VID-1.mp4',
        'WhatsApp Voice Notes/202410/PTT-1.opus',
        'WhatsApp Voice Notes/202411/PTT-2.opus',
        '.Statuses/abc.jpg',
      ]),
    );
    expect(outcome.skippedFolders, 0);
    expect(outcome.unavailableSources, isEmpty);
  });

  test('skips the trash folder and .nomedia files', () async {
    final outcome = await scanner.scan([waSource]);
    expect(
      outcome.files.where(
        (f) =>
            f.name == '.nomedia' ||
            f.relativePath.startsWith(MediaScanner.trashFolderName),
      ),
      isEmpty,
    );
  });

  test('fills in type, sent flag, size, date and ids', () async {
    final outcome = await scanner.scan([waSource]);
    final image = outcome.files.firstWhere((f) => f.name == 'IMG-1.jpg');
    expect(image.type, MediaType.image);
    expect(image.isSent, isFalse);
    expect(image.size, 2000);
    expect(image.modified, DateTime.utc(2024, 3, 1, 10));
    expect(image.modified.isUtc, isTrue);
    expect(image.id, '$waMediaId/WhatsApp Images/IMG-1.jpg');
    expect(image.parentId, '$waMediaId/WhatsApp Images');
    expect(image.sourceId, waTree);
    expect(image.mimeType, 'image/jpeg');
    expect(image.folder, 'WhatsApp Images');

    final sent = outcome.files.firstWhere((f) => f.name == 'IMG-2.jpg');
    expect(sent.isSent, isTrue);
    expect(sent.type, MediaType.image);

    expect(
      outcome.files.firstWhere((f) => f.name == 'PTT-1.opus').type,
      MediaType.voiceNote,
    );
    expect(
      outcome.files.firstWhere((f) => f.name == 'abc.jpg').type,
      MediaType.status,
    );
  });

  test('reports growing progress after each folder', () async {
    final updates = <ScanProgress>[];
    await scanner.scan([waSource], onProgress: updates.add);

    expect(updates, isNotEmpty);
    for (var i = 1; i < updates.length; i++) {
      expect(updates[i].foldersScanned, updates[i - 1].foldersScanned + 1);
      expect(
        updates[i].filesFound,
        greaterThanOrEqualTo(updates[i - 1].filesFound),
      );
    }
    expect(updates.last.filesFound, 6);
    expect(updates.last.bytesFound, 2000 + 3000 + 50000 + 400 + 500 + 700);
    expect(updates.last.phase, ScanPhase.listing);
    expect(updates.last.fraction, isNull);
  });

  test('stops when cancelled', () async {
    final cancel = CancelToken();
    final future = scanner.scan(
      [waSource],
      cancel: cancel,
      onProgress: (p) {
        if (p.foldersScanned == 2) cancel.cancel();
      },
    );
    await expectLater(future, throwsA(isA<ScanCancelled>()));
    expect(storage.listCalls, 2);
  });

  test('a cancelled token stops the scan before it starts', () async {
    final cancel = CancelToken()..cancel();
    await expectLater(
      scanner.scan([waSource], cancel: cancel),
      throwsA(isA<ScanCancelled>()),
    );
    expect(storage.listCalls, 0);
  });

  test('marks a source unavailable when access was taken away', () async {
    storage
      ..grant(wabTree, wabMediaId)
      ..addFile('WhatsApp Business Images/b.jpg', rootId: wabMediaId)
      ..revoke(waTree);
    final outcome = await scanner.scan([waSource, wabSource]);
    expect(outcome.unavailableSources, [waSource]);
    expect(outcome.files.single.name, 'b.jpg');
    expect(outcome.files.single.sourceId, wabTree);
  });

  test('marks a source unavailable when its folder is gone', () async {
    storage.delete(waMediaId);
    final outcome = await scanner.scan([waSource]);
    expect(outcome.unavailableSources, [waSource]);
    expect(outcome.files, isEmpty);
  });

  test('skips unreadable sub-folders and counts them', () async {
    storage.failLists.add('$waMediaId/WhatsApp Video');
    final outcome = await scanner.scan([waSource]);
    expect(outcome.skippedFolders, 1);
    expect(outcome.files.where((f) => f.type == MediaType.video), isEmpty);
    expect(outcome.files, hasLength(5));
  });

  test('only skips the trash folder at the top level', () async {
    storage.addFile(
      'WhatsApp Documents/${MediaScanner.trashFolderName}/kept.pdf',
    );
    final outcome = await scanner.scan([waSource]);
    expect(outcome.files.map((f) => f.name), contains('kept.pdf'));
  });

  test('scans several sources', () async {
    storage
      ..grant(wabTree, wabMediaId)
      ..addFile('WhatsApp Business Video/v.mp4', rootId: wabMediaId);
    final outcome = await scanner.scan([waSource, wabSource]);
    expect(outcome.files, hasLength(7));
    expect(
      outcome.files.where((f) => f.sourceId == wabTree).single.type,
      MediaType.video,
    );
  });

  test('an empty source list finds nothing', () async {
    final outcome = await scanner.scan(const []);
    expect(outcome.files, isEmpty);
  });
}
