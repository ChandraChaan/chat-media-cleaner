import 'package:chat_media_cleaner/features/media/domain/media_file.dart';
import 'package:chat_media_cleaner/features/media/domain/media_scanner.dart';
import 'package:chat_media_cleaner/features/media/domain/media_storage.dart';
import 'package:chat_media_cleaner/features/trash/domain/trash_entry.dart';
import 'package:chat_media_cleaner/features/trash/domain/trash_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_media_storage.dart';
import '../../support/memory_stores.dart';

void main() {
  late FakeMediaStorage storage;
  late MemoryTrashIndexStore store;
  late DateTime now;
  late TrashRepository repo;
  late List<MediaFile> files;

  TrashRepository newRepo() =>
      TrashRepository(storage: storage, store: store, clock: () => now);

  setUp(() async {
    now = DateTime.utc(2026, 10, 1, 9);
    storage = FakeMediaStorage()
      ..grant(waTree, waMediaId)
      ..addFile('WhatsApp Images/IMG-1.jpg', size: 100)
      ..addFile('WhatsApp Images/Sent/IMG-1.jpg', size: 200)
      ..addFile('WhatsApp Video/VID-1.mp4', size: 5000);
    store = MemoryTrashIndexStore();
    repo = newRepo();
    files = (await MediaScanner(storage).scan([waSource])).files
      ..sort((a, b) => a.relativePath.compareTo(b.relativePath));
  });

  Map<String, MediaFile> byName() => {for (final f in files) f.relativePath: f};

  group('moveToTrash', () {
    test('moves files into the trash and records them', () async {
      final result = await repo.moveToTrash(files, {waTree: waSource});

      expect(result.done.map((e) => e.originalKey), files.map((f) => f.key));
      expect(result.failed, isEmpty);
      expect(result.bytes, 5300);
      expect(
        storage
            .filesBelow(waMediaId)
            .where((id) => !id.contains(MediaScanner.trashFolderName)),
        isEmpty,
      );
      expect(storage.trashedFiles(), hasLength(3));
      expect(storage.exists('$waMediaId/WhatsApp Images/IMG-1.jpg'), isFalse);

      final entries = await repo.entries();
      expect(entries, hasLength(3));
      expect(entries.map((e) => e.trashedAt).toSet(), {now});
      expect(store.saved.last, hasLength(3));
    });

    test('keeps files with the same name apart', () async {
      final sameName = files.where((f) => f.name == 'IMG-1.jpg').toList();
      final result = await repo.moveToTrash(sameName, {waTree: waSource});
      expect(result.done, hasLength(2));
      final entries = await repo.entries();
      expect(entries.map((e) => e.item.itemDirId).toSet(), hasLength(2));
    });

    test('remembers where each file came from', () async {
      final video = byName()['WhatsApp Video/VID-1.mp4']!;
      await repo.moveToTrash([video], {waTree: waSource});
      final entry = (await repo.entries()).single;
      expect(entry.relativePath, 'WhatsApp Video/VID-1.mp4');
      expect(entry.originalParentId, '$waMediaId/WhatsApp Video');
      expect(entry.size, 5000);
      expect(entry.type, video.type);
      expect(entry.modified, video.modified);
      expect(entry.sourceId, waTree);
      expect(storage.exists(entry.item.fileId), isTrue);
      expect(entry.item.fileId, startsWith(entry.item.itemDirId));
    });

    test('reports failed files and keeps going', () async {
      storage.failMoves.add(files.first.id);
      final progress = <int>[];
      final result = await repo.moveToTrash(files, {
        waTree: waSource,
      }, onProgress: (done, total) => progress.add(done));
      expect(
        result.done.map((e) => e.originalId),
        files.skip(1).map((f) => f.id),
      );
      expect(result.failed.single.$1, files.first);
      expect(result.failed.single.$2, StorageError.failed);
      expect(result.bytes, files.skip(1).fold(0, (s, f) => s + f.size));
      expect(progress, [1, 2, 3]);
      expect(storage.exists(files.first.id), isTrue);
    });

    test('fails files whose folder access is gone', () async {
      final result = await repo.moveToTrash(files, const {});
      expect(result.done, isEmpty);
      expect(result.failed.map((f) => f.$2).toSet(), {
        StorageError.permissionLost,
      });
      expect(storage.trashedFiles(), isEmpty);
    });

    test('saves the index while moving many files', () async {
      for (var i = 0; i < 45; i++) {
        storage.addFile('WhatsApp Stickers/s$i.webp');
      }
      final many = (await MediaScanner(storage).scan([waSource])).files;
      await repo.moveToTrash(many, {waTree: waSource});
      expect(store.saved.map((s) => s.length), [20, 40, 48]);
    });

    test('the index is loaded again by a new repository', () async {
      await repo.moveToTrash(files, {waTree: waSource});
      final reloaded = await newRepo().entries();
      expect(reloaded, await repo.entries());
    });
  });

  group('restore', () {
    test('puts files back where they were', () async {
      await repo.moveToTrash(files, {waTree: waSource});
      final entries = await repo.entries();

      final result = await repo.restore(entries);

      expect(result.failed, isEmpty);
      expect(result.bytes, 5300);
      expect(
        result.done.map((f) => f.relativePath),
        unorderedEquals(files.map((f) => f.relativePath)),
      );
      expect(storage.trashedFiles(), isEmpty);
      for (final f in files) {
        expect(storage.exists(f.id), isTrue, reason: f.relativePath);
      }
      expect(await repo.entries(), isEmpty);
      expect(store.saved.last, isEmpty);
    });

    test('restored files keep their metadata', () async {
      final video = byName()['WhatsApp Video/VID-1.mp4']!;
      await repo.moveToTrash([video], {waTree: waSource});
      final restored = (await repo.restore(await repo.entries())).done.single;
      expect(restored, video);
    });

    test('gives a numbered name when the name was taken meanwhile', () async {
      final image = byName()['WhatsApp Images/IMG-1.jpg']!;
      await repo.moveToTrash([image], {waTree: waSource});
      storage.addFile('WhatsApp Images/IMG-1.jpg', size: 7);

      final restored = (await repo.restore(await repo.entries())).done.single;

      expect(restored.name, 'IMG-1 (1).jpg');
      expect(restored.relativePath, 'WhatsApp Images/IMG-1 (1).jpg');
      expect(restored.size, 100);
      expect(storage.exists(restored.id), isTrue);
      expect(storage.exists(image.id), isTrue);
    });

    test('keeps an entry when its folder is gone', () async {
      final video = byName()['WhatsApp Video/VID-1.mp4']!;
      await repo.moveToTrash([video], {waTree: waSource});
      storage.delete('$waMediaId/WhatsApp Video');

      final result = await repo.restore(await repo.entries());

      expect(result.done, isEmpty);
      expect(result.failed.single.$2, StorageError.targetMissing);
      expect(await repo.entries(), hasLength(1));
      expect(storage.trashedFiles(), hasLength(1));
    });

    test('drops an entry whose trashed file disappeared', () async {
      await repo.moveToTrash([files.first], {waTree: waSource});
      final entry = (await repo.entries()).single;
      storage.delete(entry.item.itemDirId);

      final result = await repo.restore([entry]);

      expect(result.failed.single.$2, StorageError.notFound);
      expect(await repo.entries(), isEmpty);
    });

    test('keeps an entry when access was taken away', () async {
      await repo.moveToTrash([files.first], {waTree: waSource});
      storage.revoke(waTree);
      final result = await repo.restore(await repo.entries());
      expect(result.failed.single.$2, StorageError.permissionLost);
      expect(await repo.entries(), hasLength(1));
    });
  });

  group('deleting for good', () {
    test('deleteForever frees the space', () async {
      await repo.moveToTrash(files, {waTree: waSource});
      final entries = await repo.entries();
      final video = entries.firstWhere((e) => e.name == 'VID-1.mp4');

      final result = await repo.deleteForever([video]);

      expect(result.done, [video]);
      expect(result.bytes, 5000);
      expect(storage.exists(video.item.itemDirId), isFalse);
      expect(await repo.entries(), hasLength(2));
    });

    test('deleteAll empties the trash', () async {
      await repo.moveToTrash(files, {waTree: waSource});
      final result = await repo.deleteAll();
      expect(result.bytes, 5300);
      expect(storage.trashedFiles(), isEmpty);
      expect(storage.filesBelow(waMediaId), [
        '$waMediaId/${MediaScanner.trashFolderName}/.nomedia',
      ]);
      expect(await repo.entries(), isEmpty);
    });

    test('an item already gone is forgotten without counting it', () async {
      await repo.moveToTrash([files.first], {waTree: waSource});
      final entry = (await repo.entries()).single;
      storage.delete(entry.item.itemDirId);

      final result = await repo.deleteForever([entry]);

      expect(result.done, [entry]);
      expect(result.bytes, 0);
      expect(await repo.entries(), isEmpty);
    });

    test('keeps entries it could not delete', () async {
      await repo.moveToTrash([files.first], {waTree: waSource});
      storage.revoke(waTree);
      final result = await repo.deleteAll();
      expect(result.failed.single.$2, StorageError.permissionLost);
      expect(await repo.entries(), hasLength(1));
    });

    test('deleteExpired removes only entries past the retention', () async {
      await repo.moveToTrash([files[0]], {waTree: waSource});
      now = now.add(const Duration(days: 3));
      await repo.moveToTrash([files[1], files[2]], {waTree: waSource});

      now = DateTime.utc(2026, 10, 8, 8, 59);
      var result = await repo.deleteExpired(const Duration(days: 7));
      expect(result.done, isEmpty);

      now = DateTime.utc(2026, 10, 8, 9);
      result = await repo.deleteExpired(const Duration(days: 7));
      expect(result.done.single.relativePath, files[0].relativePath);
      expect(await repo.entries(), hasLength(2));

      now = DateTime.utc(2026, 10, 30);
      result = await repo.deleteExpired(const Duration(days: 7));
      expect(result.done, hasLength(2));
      expect(await repo.entries(), isEmpty);
    });

    test('deleteExpired with nothing expired does not save', () async {
      final result = await repo.deleteExpired(const Duration(days: 7));
      expect(result.done, isEmpty);
      expect(store.saved, isEmpty);
    });
  });

  test('entries are newest first', () async {
    await repo.moveToTrash([files[0]], {waTree: waSource});
    now = now.add(const Duration(hours: 1));
    await repo.moveToTrash([files[1]], {waTree: waSource});
    final entries = await repo.entries();
    expect(entries.map((e) => e.relativePath), [
      files[1].relativePath,
      files[0].relativePath,
    ]);
  });

  test('generated ids are unique within the same instant', () async {
    await repo.moveToTrash(files, {waTree: waSource});
    final ids = (await repo.entries()).map((e) => e.id).toSet();
    expect(ids, hasLength(3));
  });

  group('TrashEntry', () {
    test('survives a JSON round trip', () async {
      await repo.moveToTrash(files, {waTree: waSource});
      for (final entry in await repo.entries()) {
        final copy = TrashEntry.fromJson(entry.toJson());
        expect(copy, entry);
        expect(copy.toJson(), entry.toJson());
      }
    });

    test('expires after the retention period', () {
      final entry = TrashEntry.fromJson({
        'id': 'a',
        'sourceId': waTree,
        'originalId': 'p/a.jpg',
        'originalParentId': 'p',
        'relativePath': 'WhatsApp Images/a.jpg',
        'name': 'a.jpg',
        'size': 1,
        'modified': 0,
        'type': 'image',
        'trashedAt': DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
        'itemDirId': 'd',
        'fileId': 'f',
      });
      const week = Duration(days: 7);
      expect(entry.expiresAt(week), DateTime.utc(2026, 1, 8));
      expect(entry.isExpired(DateTime.utc(2026, 1, 7, 23), week), isFalse);
      expect(entry.isExpired(DateTime.utc(2026, 1, 8), week), isTrue);
      expect(entry.isSent, isFalse);
      expect(entry.mimeType, isNull);
    });
  });
}
