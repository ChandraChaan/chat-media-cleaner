import 'package:chat_media_cleaner/features/media/domain/media_source.dart';
import 'package:chat_media_cleaner/features/media/domain/media_storage.dart';
import 'package:chat_media_cleaner/features/viewer/presentation/media_player_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_media_storage.dart';
import '../support/test_app.dart';

const _bigVideo = 'VID-20250101-WA0001.mp4';
const _newVideo = 'VID-20260901-WA0007.mp4';
const _pdf = 'Rent agreement.pdf';
const _pdfId = '$waMediaId/WhatsApp Documents/$_pdf';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Opens the Files tab and the WhatsApp folder in it.
Future<void> _openFiles(WidgetTester tester) async {
  await _tap(tester, find.byKey(const Key('tab-files')));
  await _tap(tester, find.text('WhatsApp'));
}

Future<void> _open(WidgetTester tester, String name) =>
    _tap(tester, find.text(name));

Future<void> _menu(WidgetTester tester, String file, String item) async {
  await _tap(tester, find.byKey(ValueKey('menu|$file')));
  await _tap(tester, find.text(item));
}

bool _isAbove(WidgetTester tester, String upper, String lower) =>
    tester.getTopLeft(find.text(upper)).dy <
    tester.getTopLeft(find.text(lower)).dy;

void main() {
  group('browsing', () {
    testWidgets('walks down into folders and back up with the breadcrumb', (
      tester,
    ) async {
      final app = TestApp();
      addSampleMedia(app.storage);
      // The app's own trash folder never shows up.
      app.storage.addFile('.media-cleaner-trash/x/old.jpg');
      await app.pump(tester);
      await _openFiles(tester);

      expect(find.text('WhatsApp Documents'), findsOneWidget);
      expect(find.text('WhatsApp Images'), findsOneWidget);
      expect(find.text('WhatsApp Video'), findsOneWidget);
      expect(find.text('WhatsApp Voice Notes'), findsOneWidget);
      expect(find.text('.media-cleaner-trash'), findsNothing);

      await _open(tester, 'WhatsApp Images');
      expect(find.text('Sent'), findsOneWidget);
      expect(find.text('IMG-20240305-WA0003.jpg'), findsOneWidget);
      expect(find.text('2 MB · Mar 5, 2024'), findsOneWidget);

      await _open(tester, 'Sent');
      expect(find.text('IMG-20260110-WA0010.jpg'), findsOneWidget);

      // Two levels up in one tap.
      await tester.ensureVisible(find.byKey(const Key('crumb-0')));
      await _tap(tester, find.byKey(const Key('crumb-0')));
      expect(find.text('WhatsApp Video'), findsOneWidget);
      expect(find.text('IMG-20260110-WA0010.jpg'), findsNothing);
    });

    testWidgets('shows how much each folder holds once scanned', (
      tester,
    ) async {
      final app = TestApp();
      addSampleMedia(app.storage);
      await app.pump(tester);
      await _tap(tester, find.byKey(const Key('scan')));

      await _tap(tester, find.byKey(const Key('tab-files')));
      expect(find.textContaining('6 files · 65.5 MB'), findsOneWidget);
      await _tap(tester, find.text('WhatsApp'));
      expect(find.text('2 files · 60 MB'), findsOneWidget);
      expect(find.text('2 files · 5 MB'), findsOneWidget);
    });

    testWidgets('sorts and searches a folder', (tester) async {
      final app = TestApp();
      addSampleMedia(app.storage);
      await app.pump(tester);
      await _openFiles(tester);
      await _open(tester, 'WhatsApp Video');

      expect(_isAbove(tester, _bigVideo, _newVideo), isTrue);

      await _tap(tester, find.byKey(const Key('sort')));
      await _tap(tester, find.text('Newest first'));
      expect(_isAbove(tester, _newVideo, _bigVideo), isTrue);

      await _tap(tester, find.byKey(const Key('search')));
      await tester.enterText(find.byKey(const Key('search-field')), '2025');
      await tester.pumpAndSettle();
      expect(find.text(_bigVideo), findsOneWidget);
      expect(find.text(_newVideo), findsNothing);

      await tester.enterText(find.byKey(const Key('search-field')), 'cat');
      await tester.pumpAndSettle();
      expect(find.text('Nothing here matches "cat".'), findsOneWidget);

      await _tap(tester, find.byTooltip('Close search'));
      expect(find.text(_newVideo), findsOneWidget);
    });

    testWidgets('shows files as a grid', (tester) async {
      final app = TestApp();
      addSampleMedia(app.storage);
      await app.pump(tester);
      await _openFiles(tester);
      await _open(tester, 'WhatsApp Video');

      await _tap(tester, find.byKey(const Key('toggle-view')));
      expect(find.bySemanticsLabel('$_bigVideo, 48 MB'), findsOneWidget);
      expect(find.byTooltip('Show as list'), findsOneWidget);
    });

    testWidgets('says so when a folder is empty or cannot be opened', (
      tester,
    ) async {
      final app = TestApp();
      addSampleMedia(app.storage);
      app.storage
        ..addDir('WhatsApp Stickers')
        ..failLists.add('$waMediaId/WhatsApp Video');
      await app.pump(tester);
      await _openFiles(tester);

      await _open(tester, 'WhatsApp Stickers');
      expect(find.text('This folder is empty'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await _open(tester, 'WhatsApp Video');
      expect(find.textContaining("Couldn't open this folder"), findsOneWidget);
      app.storage.failLists.clear();
      await _tap(tester, find.text('Try again'));
      expect(find.text(_bigVideo), findsOneWidget);
    });
  });

  group('file actions', () {
    testWidgets('selects with a long press, then shares the selection', (
      tester,
    ) async {
      final app = TestApp();
      addSampleMedia(app.storage);
      await app.pump(tester);
      await _openFiles(tester);
      await _open(tester, 'WhatsApp Video');

      await tester.longPress(find.text(_bigVideo));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      await _tap(tester, find.text(_newVideo));
      expect(find.text('2 selected'), findsOneWidget);
      expect(find.text('2 selected · 60 MB'), findsOneWidget);

      await _tap(tester, find.byKey(const Key('browse-share')));
      expect(app.storage.shared.single.ids, [
        '$waMediaId/WhatsApp Video/$_bigVideo',
        '$waMediaId/WhatsApp Video/$_newVideo',
      ]);
      expect(app.storage.shared.single.mimeType, 'video/mp4');

      await _tap(tester, find.byKey(const Key('cancel-selection')));
      expect(find.text('2 selected'), findsNothing);
    });

    testWidgets('moves the selection to the trash and updates the folder', (
      tester,
    ) async {
      final app = TestApp();
      addSampleMedia(app.storage);
      await app.pump(tester);
      await _openFiles(tester);
      await _open(tester, 'WhatsApp Video');

      await tester.longPress(find.text(_bigVideo));
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const Key('browse-trash')));
      expect(find.text('Move 1 file to the trash?'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('confirm-move')));
      await _tap(tester, find.byKey(const Key('keep-in-trash')));

      expect(find.text(_bigVideo), findsNothing);
      expect(find.text(_newVideo), findsOneWidget);
      expect(app.storage.trashedFiles().single, endsWith('/$_bigVideo'));
      expect(app.trashStore.saved.last.single.name, _bigVideo);
    });

    testWidgets('renames a file', (tester) async {
      final app = TestApp();
      addSampleMedia(app.storage);
      await app.pump(tester);
      await _openFiles(tester);
      await _open(tester, 'WhatsApp Video');

      await _menu(tester, _bigVideo, 'Rename');
      await tester.enterText(
        find.byKey(const Key('rename-field')),
        'Goa trip.mp4',
      );
      await _tap(tester, find.byKey(const Key('rename-save')));

      expect(find.text('Renamed to Goa trip.mp4.'), findsOneWidget);
      expect(find.text('Goa trip.mp4'), findsOneWidget);
      expect(find.text(_bigVideo), findsNothing);
      expect(
        app.storage.exists('$waMediaId/WhatsApp Video/Goa trip.mp4'),
        isTrue,
      );
    });

    testWidgets('explains a name that cannot be used', (tester) async {
      final app = TestApp();
      addSampleMedia(app.storage);
      await app.pump(tester);
      await _openFiles(tester);
      await _open(tester, 'WhatsApp Video');

      await _menu(tester, _bigVideo, 'Rename');
      final field = find.byKey(const Key('rename-field'));

      await tester.enterText(field, 'a/b.mp4');
      await _tap(tester, find.byKey(const Key('rename-save')));
      expect(find.textContaining("can't contain"), findsOneWidget);

      await tester.enterText(field, _newVideo);
      await _tap(tester, find.byKey(const Key('rename-save')));
      expect(
        find.text('This folder already has a file with that name.'),
        findsOneWidget,
      );

      await _tap(tester, find.text('Cancel'));
      expect(find.text(_bigVideo), findsOneWidget);
      expect(
        app.storage.exists('$waMediaId/WhatsApp Video/$_bigVideo'),
        isTrue,
      );
    });

    testWidgets('shows details, with size and length where known', (
      tester,
    ) async {
      final app = TestApp();
      addSampleMedia(app.storage);
      app.storage.infos['$waMediaId/WhatsApp Video/$_bigVideo'] =
          const MediaInfo(
            width: 1280,
            height: 720,
            duration: Duration(minutes: 1, seconds: 5),
          );
      await app.pump(tester);
      await _openFiles(tester);
      await _open(tester, 'WhatsApp Video');

      await _menu(tester, _bigVideo, 'Details');
      expect(find.text('WhatsApp › WhatsApp Video'), findsOneWidget);
      expect(find.text('48 MB'), findsOneWidget);
      expect(find.text('Videos (video/mp4)'), findsOneWidget);
      expect(find.text('1280 × 720'), findsOneWidget);
      expect(find.text('1:05'), findsOneWidget);
    });

    testWidgets('opens a file in another app from the menu', (tester) async {
      final app = TestApp();
      addSampleMedia(app.storage);
      await app.pump(tester);
      await _openFiles(tester);
      await _open(tester, 'WhatsApp Documents');

      await _menu(tester, _pdf, 'Open with…');
      expect(app.storage.opened, [_pdfId]);
    });
  });

  group('viewer', () {
    testWidgets('shows a PDF page by page and lets go of it afterwards', (
      tester,
    ) async {
      final app = TestApp();
      addSampleMedia(app.storage);
      app.storage.pdfPages[_pdfId] = 3;
      await app.pump(tester);
      await _openFiles(tester);
      await _open(tester, 'WhatsApp Documents');

      await _open(tester, _pdf);
      expect(find.byKey(const Key('viewer-title')), findsOneWidget);
      expect(find.text('Page 1 of 3'), findsOneWidget);
      expect(app.storage.drawnPdfPages, contains('$_pdfId#0'));

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(app.storage.pdfCloses, 1);
      expect(find.text(_pdf), findsOneWidget);
    });

    testWidgets('offers another app for a PDF with a password', (tester) async {
      final app = TestApp();
      addSampleMedia(app.storage);
      app.storage.lockedPdfs.add(_pdfId);
      await app.pump(tester);
      await _openFiles(tester);
      await _open(tester, 'WhatsApp Documents');

      await _open(tester, _pdf);
      expect(find.textContaining('needs a password'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('fallback-open-with')));
      expect(app.storage.opened, [_pdfId]);
    });

    testWidgets('shows text, and swipes on to the next file', (tester) async {
      final app = TestApp();
      app.storage
        ..addFile('WhatsApp Documents/a notes.txt', content: 'Milk, eggs, tea')
        ..addFile('WhatsApp Documents/b sheet.xlsx');
      await app.pump(tester);
      await _openFiles(tester);
      await _open(tester, 'WhatsApp Documents');

      await _open(tester, 'a notes.txt');
      expect(find.text('Milk, eggs, tea'), findsOneWidget);
      expect(find.text('1 of 2'), findsOneWidget);

      await tester.drag(
        find.byKey(const Key('viewer-pages')),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 of 2'), findsOneWidget);
      expect(
        find.text("This kind of file can't be shown here."),
        findsOneWidget,
      );
      await _tap(tester, find.byKey(const Key('fallback-open-with')));
      expect(app.storage.opened, [
        '$waMediaId/WhatsApp Documents/b sheet.xlsx',
      ]);
    });

    testWidgets('shares the file on screen', (tester) async {
      final app = TestApp();
      app.storage.addFile('WhatsApp Documents/notes.txt', content: 'hello');
      await app.pump(tester);
      await _openFiles(tester);
      await _open(tester, 'WhatsApp Documents');
      await _open(tester, 'notes.txt');

      await _tap(tester, find.byKey(const Key('viewer-share')));
      expect(app.storage.shared.single.ids, [
        '$waMediaId/WhatsApp Documents/notes.txt',
      ]);
      expect(app.storage.shared.single.mimeType, 'text/plain');
    });

    testWidgets('trashing the file on screen moves on to the next one', (
      tester,
    ) async {
      final app = TestApp();
      app.storage
        ..addFile('WhatsApp Documents/a.txt', content: 'first')
        ..addFile('WhatsApp Documents/b.txt', content: 'second');
      await app.pump(tester);
      await _openFiles(tester);
      await _open(tester, 'WhatsApp Documents');
      await _open(tester, 'a.txt');

      await _tap(tester, find.byKey(const Key('viewer-delete')));
      await _tap(tester, find.byKey(const Key('confirm-move')));
      await _tap(tester, find.byKey(const Key('keep-in-trash')));

      expect(find.text('second'), findsOneWidget);
      expect(find.text('first'), findsNothing);
      expect(app.storage.trashedFiles().single, endsWith('/a.txt'));

      // The last file closes the viewer, and the folder is empty.
      await _tap(tester, find.byKey(const Key('viewer-delete')));
      await _tap(tester, find.byKey(const Key('confirm-move')));
      await _tap(tester, find.byKey(const Key('keep-in-trash')));
      expect(find.byKey(const Key('viewer-pages')), findsNothing);
      expect(find.text('This folder is empty'), findsOneWidget);
    });

    testWidgets('a video the phone cannot play offers another app', (
      tester,
    ) async {
      final app = TestApp();
      addSampleMedia(app.storage);
      await app.pump(tester);
      await _openFiles(tester);
      await _open(tester, 'WhatsApp Video');

      // No video player exists in tests, which is what a phone without
      // the right decoder looks like to the app.
      await tester.tap(find.text(_bigVideo));
      await tester.pump();
      await tester.pump(playerOpenTimeout + const Duration(seconds: 1));
      await tester.pump();
      expect(find.text("This file can't be played here."), findsOneWidget);
      expect(find.byKey(const Key('fallback-open-with')), findsOneWidget);
    });
  });

  group('any folder', () {
    testWidgets('adds a folder that is not a chat app\'s and browses it', (
      tester,
    ) async {
      final app = TestApp(sources: const []);
      app.storage
        ..addFile(
          'IMG_0001.jpg',
          rootId: 'primary:DCIM/Camera',
          size: 4 * mb,
          modified: DateTime.utc(2020, 5, 1),
        )
        ..pickQueue.add(
          const PickedFolder(
            treeUri: 'tree:camera',
            treeDocId: 'primary:DCIM/Camera',
          ),
        );
      await app.pump(tester);

      await _tap(tester, find.byKey(const Key('choose-other')));
      // The picker starts wherever the user last was.
      expect(app.storage.initialDocIds.single, isNull);
      final source = app.settings.settings.sources.single;
      expect(source.app, ChatApp.other);
      expect(find.widgetWithText(Chip, 'Camera'), findsOneWidget);

      // An old camera photo is not an "old forward".
      await _tap(tester, find.byKey(const Key('scan')));
      expect(find.text('4 MB'), findsWidgets);
      final old = find.byKey(const Key('group-oldForwards'));
      await tester.scrollUntilVisible(old, 200);
      expect(
        find.descendant(of: old, matching: find.text('Nothing here')),
        findsOneWidget,
      );

      await _tap(tester, find.byKey(const Key('tab-files')));
      await _tap(tester, find.text('Camera'));
      expect(find.text('IMG_0001.jpg'), findsOneWidget);
    });
  });
}
