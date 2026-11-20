import 'package:chat_media_cleaner/features/media/domain/media_source.dart';
import 'package:chat_media_cleaner/features/media/domain/media_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

const _vol = '/storage/emulated/0';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _menu(WidgetTester tester, String name, String item) async {
  await _tap(tester, find.byKey(ValueKey('menu|$name')));
  await _tap(tester, find.text(item));
}

/// An app with all-files access and a small internal storage.
TestApp _phone() {
  final app = TestApp(sources: const []);
  app.storage
    ..allFilesGranted = true
    ..addVolume(_vol)
    ..addFile('Download/report.pdf', rootId: _vol, size: 2 * mb)
    ..addFile('Download/song.mp3', rootId: _vol, size: 4 * mb)
    ..addFile('DCIM/Camera/IMG_1.jpg', rootId: _vol, size: 3 * mb)
    ..addFile('Movies/trip.mp4', rootId: _vol, size: 40 * mb)
    ..addFile('.thumbnails/t.jpg', rootId: _vol);
  return app;
}

/// Opens the Files tab and internal storage in it.
Future<void> _openStorage(WidgetTester tester) async {
  await _tap(tester, find.byKey(const Key('tab-files')));
  await _tap(tester, find.byKey(const ValueKey('volume-$_vol')));
}

void main() {
  group('all files access', () {
    testWidgets('first start: allowing it finds WhatsApp on its own', (
      tester,
    ) async {
      final app = TestApp(sources: const []);
      app.storage
        ..addVolume(_vol)
        ..addDir('Android/media/com.whatsapp/WhatsApp/Media', rootId: _vol);
      await app.pump(tester);

      await _tap(tester, find.byKey(const Key('choose-all-files')));
      expect(app.storage.accessRequests, 1);
      final sources = app.settings.settings.sources;
      expect(sources.map((s) => s.app), [ChatApp.whatsapp]);
      expect(sources.single.isFileSystem, isTrue);
      // The cleaner is ready without any folder picking.
      expect(find.byKey(const Key('scan')), findsOneWidget);
    });

    testWidgets('declining keeps the folder picker way open', (tester) async {
      final app = TestApp(sources: const []);
      app.storage
        ..grantOnRequest = false
        ..addVolume(_vol);
      await app.pump(tester);

      await _tap(tester, find.byKey(const Key('choose-all-files')));
      expect(
        find.text(
          'All files access is off. You can still work in the folders you '
          'choose.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('choose-whatsapp')), findsOneWidget);
    });

    testWidgets('without it the Files tab offers it and keeps chosen folders', (
      tester,
    ) async {
      final app = TestApp();
      app.storage.addVolume(_vol);
      await app.pump(tester);
      await _tap(tester, find.byKey(const Key('tab-files')));

      expect(find.byKey(const Key('allow-all-files')), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('allow-all-files')));
      expect(find.byKey(const ValueKey('volume-$_vol')), findsOneWidget);
      expect(find.byKey(const Key('allow-all-files')), findsNothing);
    });

    testWidgets('a file-tree chat folder is dropped once access is gone', (
      tester,
    ) async {
      final source = MediaSource(
        treeUri: fileTreeUri('$_vol/WhatsApp/Media'),
        rootId: '$_vol/WhatsApp/Media',
        app: ChatApp.whatsapp,
      );
      final app = TestApp(sources: [source]);
      await app.pump(tester);
      expect(app.settings.settings.sources, isEmpty);
      expect(find.byKey(const Key('choose-all-files')), findsOneWidget);
    });
  });

  group('file manager', () {
    testWidgets('browses all storage, hiding dot files until asked', (
      tester,
    ) async {
      final app = _phone();
      await app.pump(tester);
      expect(find.text('No chat folders yet'), findsOneWidget);
      await _openStorage(tester);

      expect(find.text('Download'), findsOneWidget);
      expect(find.text('DCIM'), findsOneWidget);
      expect(find.text('.thumbnails'), findsNothing);

      await _tap(tester, find.byKey(const Key('folder-menu')));
      await _tap(tester, find.text('Show hidden files'));
      expect(find.text('.thumbnails'), findsOneWidget);

      await _tap(tester, find.text('DCIM'));
      await _tap(tester, find.text('Camera'));
      expect(find.text('IMG_1.jpg'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('crumb-0')));
      expect(find.text('Movies'), findsOneWidget);
    });

    testWidgets('makes a folder and copies a file into it', (tester) async {
      final app = _phone();
      await app.pump(tester);
      await _openStorage(tester);

      await _tap(tester, find.byKey(const Key('new-folder')));
      await tester.enterText(find.byKey(const Key('rename-field')), 'Backup');
      await _tap(tester, find.byKey(const Key('rename-save')));
      expect(app.storage.exists('$_vol/Backup'), isTrue);

      await _tap(tester, find.text('Download'));
      await _menu(tester, 'report.pdf', 'Copy');
      expect(find.byKey(const Key('clipboard-summary')), findsOneWidget);
      await _tap(tester, find.byKey(const Key('crumb-0')));
      await _tap(tester, find.text('Backup'));
      await _tap(tester, find.byKey(const Key('paste-here')));

      expect(find.text('report.pdf'), findsOneWidget);
      expect(app.storage.exists('$_vol/Backup/report.pdf'), isTrue);
      expect(app.storage.exists('$_vol/Download/report.pdf'), isTrue);
      expect(find.byKey(const Key('clipboard-summary')), findsNothing);
    });

    testWidgets('moves a selection, and won\'t move a folder into itself', (
      tester,
    ) async {
      final app = _phone();
      await app.pump(tester);
      await _openStorage(tester);

      await tester.longPress(find.text('Download'));
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const Key('browse-move')));
      await _tap(tester, find.text('Download'));
      await _tap(tester, find.byKey(const Key('paste-here')));
      expect(
        find.text('A folder can\'t go inside itself. Open another folder.'),
        findsOneWidget,
      );

      await _tap(tester, find.byKey(const Key('crumb-0')));
      await _tap(tester, find.text('Movies'));
      await _tap(tester, find.byKey(const Key('paste-here')));
      expect(app.storage.exists('$_vol/Movies/Download/song.mp3'), isTrue);
      expect(app.storage.exists('$_vol/Download'), isFalse);
    });

    testWidgets('compresses a folder and extracts the archive', (tester) async {
      final app = _phone();
      await app.pump(tester);
      await _openStorage(tester);

      await _menu(tester, 'Download', 'Compress');
      expect(find.text('Compress 1 item'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('rename-save')));
      expect(app.storage.exists('$_vol/Download.zip'), isTrue);

      await _menu(tester, 'Download.zip', 'Extract here');
      expect(
        app.storage.exists('$_vol/Download (1)/Download/song.mp3'),
        isTrue,
      );
      expect(find.text('Extracted into Download (1).'), findsOneWidget);
    });

    testWidgets('trashes a folder and puts it back with Undo', (tester) async {
      final app = _phone();
      await app.pump(tester);
      await _openStorage(tester);

      await _menu(tester, 'Movies', 'Move to trash');
      // The folder was measured, so the confirmation knows its size.
      expect(find.textContaining('40 MB'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('confirm-move')));
      await _tap(tester, find.byKey(const Key('keep-in-trash')));
      expect(app.storage.exists('$_vol/Movies'), isFalse);
      expect(find.text('Movies'), findsNothing);

      await _tap(tester, find.byKey(const Key('undo-trash')));
      expect(app.storage.exists('$_vol/Movies/trip.mp4'), isTrue);
      expect(find.text('Movies'), findsOneWidget);
      expect(app.trashStore.saved.last, isEmpty);
    });

    testWidgets('searches every sub-folder and opens a result\'s folder', (
      tester,
    ) async {
      final app = _phone();
      await app.pump(tester);
      await _openStorage(tester);

      await _tap(tester, find.byKey(const Key('search')));
      await _tap(tester, find.byKey(const Key('search-deep')));
      await tester.enterText(find.byKey(const Key('search-field')), 'img');
      await tester.pumpAndSettle();
      expect(find.text('IMG_1.jpg'), findsOneWidget);
      expect(find.textContaining('DCIM › Camera'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('search-field')), 'came');
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Camera'));
      expect(find.text('IMG_1.jpg'), findsOneWidget);
    });

    testWidgets('filters a folder by kind of file', (tester) async {
      final app = _phone();
      await app.pump(tester);
      await _openStorage(tester);
      await _tap(tester, find.text('Download'));

      await _tap(tester, find.byKey(const Key('filter-audio')));
      expect(find.text('song.mp3'), findsOneWidget);
      expect(find.text('report.pdf'), findsNothing);
      final chips = find.descendant(
        of: find.byKey(const Key('type-filters')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('filter-all')),
        -100,
        scrollable: chips,
      );
      await _tap(tester, find.byKey(const Key('filter-all')));
      expect(find.text('report.pdf'), findsOneWidget);
    });

    testWidgets('stars a folder, and shows it and recent files at home', (
      tester,
    ) async {
      final app = _phone();
      await app.pump(tester);
      await _openStorage(tester);

      await _menu(tester, 'Movies', 'Add to favourites');
      await _tap(tester, find.text('Download'));
      await _tap(tester, find.text('report.pdf'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Favourites'), findsOneWidget);
      expect(find.text('Recent files'), findsOneWidget);
      expect(app.places.places.recent.single.file.name, 'report.pdf');
      await _tap(
        tester,
        find.byKey(
          const ValueKey('fav-file:///storage/emulated/0|$_vol/Movies'),
        ),
      );
      expect(find.text('trip.mp4'), findsOneWidget);
    });

    testWidgets('folder details count what is inside', (tester) async {
      final app = _phone();
      await app.pump(tester);
      await _openStorage(tester);

      await _menu(tester, 'DCIM', 'Details');
      expect(find.text('1 file, 1 folder'), findsOneWidget);
      expect(find.text('3 MB'), findsOneWidget);
    });
  });

  group('storage', () {
    testWidgets('scans and shows space by kind of file and large files', (
      tester,
    ) async {
      final app = _phone();
      await app.pump(tester);
      await _tap(tester, find.byKey(const Key('tab-files')));
      await _tap(tester, find.byKey(const Key('open-storage')));
      await _tap(tester, find.byKey(const Key('storage-scan')));

      expect(find.textContaining('By kind of file'), findsOneWidget);
      expect(find.byKey(const Key('category-videos')), findsOneWidget);
      await _tap(tester, find.byKey(const Key('open-large-files')));
      expect(find.text('trip.mp4'), findsOneWidget);
      expect(find.text('song.mp3'), findsNothing);
    });

    testWidgets('a kind of file lists every match across storage', (
      tester,
    ) async {
      final app = _phone();
      await app.pump(tester);
      await _tap(tester, find.byKey(const Key('tab-files')));
      await _tap(tester, find.byKey(const Key('home-category-images')));
      // Not scanned yet: the list offers to scan first.
      await _tap(tester, find.byKey(const Key('storage-scan')));
      expect(find.text('IMG_1.jpg'), findsOneWidget);
      // The hidden thumbnail still takes space, so it is counted.
      expect(find.text('t.jpg'), findsOneWidget);
    });
  });
}
