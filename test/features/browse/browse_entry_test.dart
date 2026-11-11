import 'package:chat_media_cleaner/features/browse/domain/browse_entry.dart';
import 'package:chat_media_cleaner/features/media/domain/media_file.dart';
import 'package:chat_media_cleaner/features/media/domain/media_scanner.dart';
import 'package:chat_media_cleaner/features/media/domain/media_storage.dart';
import 'package:chat_media_cleaner/features/media/domain/media_type.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_media_storage.dart';

StorageEntry _file(String name, {int size = 10, int day = 1, String? mime}) =>
    StorageEntry(
      id: 'id/$name',
      name: name,
      isDirectory: false,
      size: size,
      modifiedMillis: DateTime.utc(2026, 1, day).millisecondsSinceEpoch,
      mimeType: mime,
    );

StorageEntry _dir(String name, {int day = 1}) => StorageEntry(
  id: 'id/$name',
  name: name,
  isDirectory: true,
  modifiedMillis: DateTime.utc(2026, 1, day).millisecondsSinceEpoch,
);

MediaFile _media(String path, int size, {String sourceId = waTree}) =>
    MediaFile(
      id: 'id/$path',
      sourceId: sourceId,
      parentId: 'parent',
      name: path.split('/').last,
      relativePath: path,
      size: size,
      modified: DateTime.utc(2026),
      type: MediaType.image,
    );

void main() {
  final root = BrowseLocation.root(waSource);

  group('FolderListing.fromEntries', () {
    test('splits folders from files and fills in where files are', () {
      final images = root.child(
        BrowseFolder(
          id: '$waMediaId/WhatsApp Images',
          name: 'WhatsApp Images',
          modified: DateTime.utc(2026),
        ),
      );
      final listing = FolderListing.fromEntries(images, [
        _dir('Sent'),
        _file('IMG-1.jpg', size: 2000, mime: 'image/jpeg'),
      ]);

      expect(listing.folders.single.name, 'Sent');
      final file = listing.files.single;
      expect(file.relativePath, 'WhatsApp Images/IMG-1.jpg');
      expect(file.parentId, '$waMediaId/WhatsApp Images');
      expect(file.sourceId, waTree);
      expect(file.type, MediaType.image);
      expect(file.size, 2000);
      expect(file.isSent, isFalse);
      expect(file.modified, DateTime.utc(2026));
    });

    test('marks files in a Sent folder', () {
      const sent = BrowseLocation(
        source: waSource,
        dirId: 'sent',
        path: ['WhatsApp Images', 'Sent'],
      );
      final listing = FolderListing.fromEntries(sent, [_file('IMG-2.jpg')]);
      expect(listing.files.single.isSent, isTrue);
      expect(
        listing.files.single.relativePath,
        'WhatsApp Images/Sent/IMG-2.jpg',
      );
    });

    test('hides the trash folder at the root and housekeeping files', () {
      final listing = FolderListing.fromEntries(root, [
        _dir(MediaScanner.trashFolderName),
        _dir('WhatsApp Video'),
        _file('.nomedia'),
        _file('.trashed-123-IMG.jpg'),
        _file('note.txt', mime: 'text/plain'),
      ]);
      expect(listing.folders.map((f) => f.name), ['WhatsApp Video']);
      expect(listing.files.map((f) => f.name), ['note.txt']);
    });

    test('keeps a folder that merely shares the trash name deeper down', () {
      const deeper = BrowseLocation(
        source: waSource,
        dirId: 'x',
        path: ['WhatsApp Documents'],
      );
      final listing = FolderListing.fromEntries(deeper, [
        _dir(MediaScanner.trashFolderName),
      ]);
      expect(listing.folders, hasLength(1));
    });
  });

  group('BrowseOrder.apply', () {
    final listing = FolderListing.fromEntries(root, [
      _dir('beta', day: 3),
      _dir('Alpha', day: 5),
      _file('b.jpg', size: 300, day: 2),
      _file('A.jpg', size: 100, day: 9),
      _file('c.jpg', size: 200, day: 4),
    ]);
    List<String> files(BrowseSort sort, [String query = '']) => [
      for (final f in BrowseOrder.apply(
        listing,
        sort: sort,
        query: query,
      ).files)
        f.name,
    ];
    List<String> folders(BrowseSort sort, [String query = '']) => [
      for (final f in BrowseOrder.apply(
        listing,
        sort: sort,
        query: query,
      ).folders)
        f.name,
    ];

    test('by name ignores case', () {
      expect(files(BrowseSort.name), ['A.jpg', 'b.jpg', 'c.jpg']);
      expect(folders(BrowseSort.name), ['Alpha', 'beta']);
    });

    test('by date', () {
      expect(files(BrowseSort.newest), ['A.jpg', 'c.jpg', 'b.jpg']);
      expect(files(BrowseSort.oldest), ['b.jpg', 'c.jpg', 'A.jpg']);
      expect(folders(BrowseSort.newest), ['Alpha', 'beta']);
      expect(folders(BrowseSort.oldest), ['beta', 'Alpha']);
    });

    test('by size; folders stay in name order', () {
      expect(files(BrowseSort.largest), ['b.jpg', 'c.jpg', 'A.jpg']);
      expect(files(BrowseSort.smallest), ['A.jpg', 'c.jpg', 'b.jpg']);
      expect(folders(BrowseSort.largest), ['Alpha', 'beta']);
    });

    test('equal sizes fall back to the name, so the order is stable', () {
      final same = FolderListing.fromEntries(root, [
        _file('z.jpg', size: 5),
        _file('a.jpg', size: 5),
      ]);
      expect(
        BrowseOrder.apply(
          same,
          sort: BrowseSort.largest,
        ).files.map((f) => f.name),
        ['a.jpg', 'z.jpg'],
      );
    });

    test('search matches part of a name, any case, files and folders', () {
      expect(files(BrowseSort.name, 'A.J'), ['A.jpg']);
      expect(folders(BrowseSort.name, ' ALP '), ['Alpha']);
      expect(files(BrowseSort.name, 'zzz'), isEmpty);
      expect(
        BrowseOrder.apply(listing, sort: BrowseSort.name, query: 'zzz').isEmpty,
        isTrue,
      );
    });
  });

  group('FolderStats.of', () {
    test('counts every file in each folder above it', () {
      final stats = FolderStats.of([
        _media('WhatsApp Images/a.jpg', 100),
        _media('WhatsApp Images/Sent/b.jpg', 40),
        _media('WhatsApp Video/c.mp4', 1000),
        _media('loose.txt', 1),
      ]);
      FolderStats at(String path) => stats[FolderStats.keyOf(waTree, path)]!;

      expect(at('').count, 4);
      expect(at('').bytes, 1141);
      expect(at('WhatsApp Images').count, 2);
      expect(at('WhatsApp Images').bytes, 140);
      expect(at('WhatsApp Images/Sent').bytes, 40);
      expect(at('WhatsApp Video').count, 1);
    });

    test('keeps sources apart', () {
      final stats = FolderStats.of([
        _media('WhatsApp Images/a.jpg', 100),
        _media('WhatsApp Images/b.jpg', 7, sourceId: wabTree),
      ]);
      expect(stats[FolderStats.keyOf(waTree, 'WhatsApp Images')]!.bytes, 100);
      expect(stats[FolderStats.keyOf(wabTree, 'WhatsApp Images')]!.bytes, 7);
    });

    test('is empty without files', () {
      expect(FolderStats.of(const []), isEmpty);
    });
  });

  test('locations are equal by source and folder, whatever the path', () {
    const a = BrowseLocation(source: waSource, dirId: 'x', path: ['A']);
    const b = BrowseLocation(source: waSource, dirId: 'x', path: ['A']);
    const c = BrowseLocation(source: waSource, dirId: 'y', path: ['A']);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
    expect(root.isRoot, isTrue);
    expect(a.relativePath, 'A');
  });
}
