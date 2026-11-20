import 'package:chat_media_cleaner/features/browse/domain/browse_entry.dart';
import 'package:chat_media_cleaner/features/browse/domain/file_clipboard.dart';
import 'package:chat_media_cleaner/features/browse/domain/file_search.dart';
import 'package:chat_media_cleaner/features/media/domain/cancel_token.dart';
import 'package:chat_media_cleaner/features/media/domain/media_file.dart';
import 'package:chat_media_cleaner/features/media/domain/media_source.dart';
import 'package:chat_media_cleaner/features/media/domain/media_storage.dart';
import 'package:chat_media_cleaner/features/media/domain/media_type.dart';
import 'package:chat_media_cleaner/features/places/domain/places.dart';
import 'package:chat_media_cleaner/features/storage/domain/file_category.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_media_storage.dart';

const _volume = '/storage/emulated/0';

MediaFile _item(
  String path, {
  bool folder = false,
  String sourceId = 'file:///storage/emulated/0',
}) => MediaFile(
  id: '$_volume/$path',
  sourceId: sourceId,
  parentId:
      '$_volume/${path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : ''}',
  name: path.split('/').last,
  relativePath: path,
  size: folder ? 0 : 10,
  modified: DateTime.utc(2026),
  type: MediaType.other,
  mimeType: folder ? MediaFile.folderMimeType : null,
);

StorageEntry _file(String name, {String? mime}) => StorageEntry(
  id: 'id/$name',
  name: name,
  isDirectory: false,
  size: 10,
  mimeType: mime,
);

StorageEntry _dir(String name) =>
    StorageEntry(id: 'id/$name', name: name, isDirectory: true);

void main() {
  group('FileCategories', () {
    test('goes by the extension, whatever the case', () {
      expect(FileCategories.of('IMG.JPG'), FileCategory.images);
      expect(FileCategories.of('clip.mkv'), FileCategory.videos);
      expect(FileCategories.of('PTT-1.opus'), FileCategory.audio);
      expect(FileCategories.of('Rent.pdf'), FileCategory.documents);
      expect(FileCategories.of('backup.tar.gz'), FileCategory.archives);
      expect(FileCategories.of('app-release.apk'), FileCategory.apps);
      expect(FileCategories.of('notes'), FileCategory.other);
    });

    test('falls back to the MIME type', () {
      expect(
        FileCategories.of('photo', mimeType: 'image/heic'),
        FileCategory.images,
      );
      expect(
        FileCategories.of(
          'x',
          mimeType: 'application/vnd.android.package-archive',
        ),
        FileCategory.apps,
      );
    });

    test('knows which archives it can unpack', () {
      expect(FileCategories.isZip('a.ZIP'), isTrue);
      expect(FileCategories.isZip('a.rar'), isFalse);
    });
  });

  group('BrowseOrder.apply', () {
    final location = BrowseLocation.root(
      MediaSource(
        treeUri: fileTreeUri(_volume),
        rootId: _volume,
        app: ChatApp.other,
      ),
    );
    final listing = FolderListing.fromEntries(location, [
      _dir('DCIM'),
      _dir('.thumbnails'),
      _file('.hidden.txt', mime: 'text/plain'),
      _file('a.jpg', mime: 'image/jpeg'),
      _file('b.pdf', mime: 'application/pdf'),
    ]);

    test('hides names starting with a dot unless asked', () {
      final shown = BrowseOrder.apply(
        listing,
        sort: BrowseSort.name,
        showHidden: false,
      );
      expect(shown.folders.map((f) => f.name), ['DCIM']);
      expect(shown.files.map((f) => f.name), ['a.jpg', 'b.pdf']);
      final all = BrowseOrder.apply(listing, sort: BrowseSort.name);
      expect(all.folders, hasLength(2));
      expect(all.files, hasLength(3));
    });

    test('filters files by kind and keeps folders to walk into', () {
      final shown = BrowseOrder.apply(
        listing,
        sort: BrowseSort.name,
        category: FileCategory.documents,
        showHidden: false,
      );
      expect(shown.folders.map((f) => f.name), ['DCIM']);
      expect(shown.files.map((f) => f.name), ['b.pdf']);
    });

    test('a folder becomes an item that remembers where it is', () {
      final item = listing.folders.first.asItem(location);
      expect(item.isFolder, isTrue);
      expect(item.parentId, _volume);
      expect(item.relativePath, item.name);
      expect(item.sourceId, fileTreeUri(_volume));
    });
  });

  group('FileClipboard', () {
    test('refuses to put a folder inside itself or below it', () {
      final clipboard = FileClipboard(
        mode: ClipboardMode.move,
        items: [_item('DCIM', folder: true), _item('a.jpg')],
      );
      final src = fileTreeUri(_volume);
      expect(clipboard.wouldNestInto(src, '$_volume/DCIM'), isTrue);
      expect(clipboard.wouldNestInto(src, '$_volume/DCIM/Camera'), isTrue);
      expect(clipboard.wouldNestInto(src, '$_volume/DCIM2'), isFalse);
      expect(clipboard.wouldNestInto(src, _volume), isFalse);
      // Another source is another tree.
      expect(clipboard.wouldNestInto('other', '$_volume/DCIM'), isFalse);
    });
  });

  group('Places', () {
    final a = _item('a.jpg');
    final b = _item('b.jpg');
    final dir = _item('Docs', folder: true);

    test('stars and unstars files and folders', () {
      var places = Places.empty.toggleFavourite(a).toggleFavourite(dir);
      expect(places.isFavourite(a), isTrue);
      expect(places.isFavourite(dir), isTrue);
      places = places.toggleFavourite(a);
      expect(places.isFavourite(a), isFalse);
      expect(places.favourites, [dir]);
    });

    test('keeps one recent entry per file, newest first, up to a limit', () {
      var places = Places.empty
          .opened(a, DateTime.utc(2026, 1, 1))
          .opened(b, DateTime.utc(2026, 1, 2))
          .opened(a, DateTime.utc(2026, 1, 3));
      expect(places.recent.map((r) => r.file), [a, b]);
      for (var i = 0; i < Places.maxRecent + 5; i++) {
        places = places.opened(_item('f$i.jpg'), DateTime.utc(2026, 2, 1));
      }
      expect(places.recent, hasLength(Places.maxRecent));
    });

    test('forgets trashed items and follows renamed ones', () {
      final places = Places.empty
          .toggleFavourite(a)
          .opened(b, DateTime.utc(2026));
      expect(places.without({a.key, b.key}), isA<Places>());
      expect(places.without({a.key}).favourites, isEmpty);
      final renamed = b.copyWith(id: '$_volume/c.jpg', name: 'c.jpg');
      expect(places.replace(b.key, renamed).recent.single.file, renamed);
    });
  });

  group('FileSearch', () {
    late FakeMediaStorage storage;
    final source = MediaSource(
      treeUri: fileTreeUri(_volume),
      rootId: _volume,
      app: ChatApp.other,
    );

    setUp(() {
      storage = FakeMediaStorage()
        ..allFilesGranted = true
        ..addVolume(_volume)
        ..addFile('Download/Invoice March.pdf', rootId: _volume)
        ..addFile('Documents/Tax/invoice-2025.pdf', rootId: _volume)
        ..addFile('Documents/notes.txt', rootId: _volume)
        ..addFile('.secret/invoice.txt', rootId: _volume)
        ..addDir('Invoices', rootId: _volume);
    });

    test(
      'finds files and folders in every sub-folder, folders first',
      () async {
        final found = await FileSearch(
          storage,
        ).run(BrowseLocation.root(source), 'INVOICE');
        expect(found.map((f) => f.relativePath), [
          'Invoices',
          'Download/Invoice March.pdf',
          'Documents/Tax/invoice-2025.pdf',
        ]);
        expect(found.first.isFolder, isTrue);
        expect(found.last.parentId, '$_volume/Documents/Tax');
      },
    );

    test('looks into hidden folders only when asked', () async {
      final found = await FileSearch(
        storage,
      ).run(BrowseLocation.root(source), 'invoice', showHidden: true);
      expect(found.map((f) => f.name), contains('invoice.txt'));
    });

    test('an empty search finds nothing and a cancelled one stops', () async {
      final search = FileSearch(storage);
      expect(await search.run(BrowseLocation.root(source), '  '), isEmpty);
      final cancel = CancelToken()..cancel();
      await expectLater(
        search.run(BrowseLocation.root(source), 'x', cancel: cancel),
        throwsA(isA<ScanCancelled>()),
      );
    });
  });

  group('SourceLocator.findOnVolume', () {
    test('finds WhatsApp and WhatsApp Business as file-tree sources', () async {
      final storage = FakeMediaStorage()
        ..allFilesGranted = true
        ..addVolume(_volume)
        ..addDir('Android/media/com.whatsapp/WhatsApp/Media', rootId: _volume)
        ..addDir('WhatsApp Business/Media', rootId: _volume);
      final found = await SourceLocator.findOnVolume(storage, _volume);
      expect(found.map((s) => s.app), [
        ChatApp.whatsapp,
        ChatApp.whatsappBusiness,
      ]);
      expect(
        found.first.rootId,
        '$_volume/Android/media/com.whatsapp/WhatsApp/Media',
      );
      expect(found.first.treeUri, fileTreeUri(found.first.rootId));
      expect(found.first.isFileSystem, isTrue);
      expect(found.last.rootId, '$_volume/WhatsApp Business/Media');
    });

    test('finds nothing without access', () async {
      final storage = FakeMediaStorage()..addVolume(_volume);
      expect(await SourceLocator.findOnVolume(storage, _volume), isEmpty);
    });
  });

  test('a volume source shows the volume name and survives JSON', () {
    const volume = StorageVolume(
      path: '/storage/1234-ABCD',
      label: 'SD card',
      isPrimary: false,
      isRemovable: true,
      totalBytes: 100,
      freeBytes: 25,
    );
    final source = MediaSource.volume(volume);
    expect(source.displayName, 'SD card');
    expect(volume.usedBytes, 75);
    expect(volume.usedFraction, 0.75);
    expect(MediaSource.fromJson(source.toJson()), source);
    expect(
      SourceLocator.pathOf('/storage/1234-ABCD/a:b'),
      '/storage/1234-ABCD/a:b',
    );
  });
}
