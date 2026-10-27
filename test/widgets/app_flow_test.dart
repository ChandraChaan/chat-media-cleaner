import 'package:chat_media_cleaner/features/media/domain/media_scanner.dart';
import 'package:chat_media_cleaner/features/media/domain/media_storage.dart';
import 'package:chat_media_cleaner/features/media/domain/media_type.dart';
import 'package:chat_media_cleaner/features/review/presentation/review_screen.dart';
import 'package:chat_media_cleaner/features/trash/domain/trash_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_media_storage.dart';
import '../support/test_app.dart';

const _bigVideo = '$waMediaId/WhatsApp Video/VID-20250101-WA0001.mp4';
const _newVideo = '$waMediaId/WhatsApp Video/VID-20260901-WA0007.mp4';

Future<void> _scan(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('scan')));
  await tester.pumpAndSettle();
}

Future<void> _openGroup(WidgetTester tester, String group) async {
  final card = find.byKey(Key('group-$group'));
  await tester.scrollUntilVisible(card, 200);
  await tester.tap(card);
  await tester.pumpAndSettle();
}

Finder _tile(String name) => find.bySemanticsLabel(RegExp('^$name, '));

void main() {
  group('first start', () {
    testWidgets('explains folder access and adds the picked folder', (
      tester,
    ) async {
      final app = TestApp(sources: const []);
      addSampleMedia(app.storage);
      app.storage.pickQueue.add(
        const PickedFolder(treeUri: waTree, treeDocId: waMediaId),
      );
      await app.pump(tester);

      expect(find.text('Choose your chat media folder'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('No internet permission'),
        200,
      );
      await tester.scrollUntilVisible(find.textContaining('not made by'), 200);
      expect(find.textContaining('not made by'), findsOneWidget);

      await tester.tap(find.byKey(const Key('choose-whatsapp')));
      await tester.pumpAndSettle();

      expect(app.storage.initialDocIds.single, waMediaId);
      expect(app.settings.settings.sources.single.rootId, waMediaId);
      expect(find.byKey(const Key('scan')), findsOneWidget);
      expect(find.widgetWithText(Chip, 'WhatsApp'), findsOneWidget);
    });

    testWidgets('says so when the folder has no chat media', (tester) async {
      final app = TestApp(sources: const []);
      app.storage
        ..addFile('IMG_1.jpg', rootId: 'primary:DCIM/Camera')
        ..pickQueue.add(
          const PickedFolder(
            treeUri: 'tree:dcim',
            treeDocId: 'primary:DCIM/Camera',
          ),
        );
      await app.pump(tester);

      await tester.tap(find.byKey(const Key('choose-whatsapp')));
      await tester.pumpAndSettle();

      expect(find.textContaining("doesn't contain WhatsApp media"), findsOne);
      expect(app.settings.settings.sources, isEmpty);
      expect(app.storage.released, ['tree:dcim']);
    });

    testWidgets('does nothing when the picker is cancelled', (tester) async {
      final app = TestApp(sources: const []);
      app.storage.pickQueue.add(null);
      await app.pump(tester);

      await tester.tap(find.byKey(const Key('choose-business')));
      await tester.pumpAndSettle();

      expect(
        app.storage.initialDocIds.single,
        'primary:Android/media/com.whatsapp.w4b/WhatsApp Business/Media',
      );
      expect(find.text('Choose your chat media folder'), findsOneWidget);
    });
  });

  group('scan', () {
    testWidgets('shows totals by type and the smart groups', (tester) async {
      final app = TestApp();
      addSampleMedia(app.storage);
      await app.pump(tester);
      await _scan(tester);

      expect(find.byKey(const Key('total-size')), findsOneWidget);
      expect(find.text('65.5 MB'), findsOneWidget);
      expect(find.text('in 6 files'), findsOneWidget);
      expect(find.text('Videos'), findsOneWidget);
      expect(find.text('60 MB'), findsOneWidget);
      expect(find.text('Voice notes'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('group-sentCopies')),
        200,
      );
      expect(find.text('Largest files'), findsOneWidget);
      expect(find.text('Old forwards and memes'), findsOneWidget);
      expect(find.text('Sent media copies'), findsOneWidget);
    });

    testWidgets('asks to choose the folder again when access is gone', (
      tester,
    ) async {
      final app = TestApp();
      await app.pump(tester);
      app.storage.revoke(waTree);
      await _scan(tester);

      expect(find.textContaining("Can't open the folder"), findsOneWidget);
      expect(find.text('Choose folder again'), findsOneWidget);
    });
  });

  group('review and delete', () {
    testWidgets('nothing can be deleted until files are selected', (
      tester,
    ) async {
      final app = TestApp();
      addSampleMedia(app.storage);
      await app.pump(tester);
      await _scan(tester);
      await _openGroup(tester, 'largest');

      expect(find.byKey(const Key('move-to-trash')), findsNothing);
      expect(_tile('VID-20250101-WA0001.mp4'), findsOneWidget);

      await tester.tap(_tile('VID-20250101-WA0001.mp4'));
      await tester.pump();
      expect(find.text('1 selected · 48 MB'), findsOneWidget);

      await tester.tap(_tile('VID-20250101-WA0001.mp4'));
      await tester.pump();
      expect(find.byKey(const Key('move-to-trash')), findsNothing);
      expect(app.storage.trashedFiles(), isEmpty);
    });

    testWidgets('select all, cancel the confirmation, nothing moves', (
      tester,
    ) async {
      final app = TestApp();
      addSampleMedia(app.storage);
      await app.pump(tester);
      await _scan(tester);
      await _openGroup(tester, 'largest');

      await tester.tap(find.byKey(const Key('select-all')));
      await tester.pump();
      expect(find.text('4 selected · 65 MB'), findsOneWidget);

      await tester.tap(find.byKey(const Key('move-to-trash')));
      await tester.pumpAndSettle();
      expect(find.text('Move 4 files to the trash?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(app.storage.trashedFiles(), isEmpty);
      expect(find.text('4 selected · 65 MB'), findsOneWidget);
    });

    testWidgets('moves selected files to the trash and keeps them there', (
      tester,
    ) async {
      final app = TestApp();
      addSampleMedia(app.storage);
      await app.pump(tester);
      await _scan(tester);
      await _openGroup(tester, 'largest');

      await tester.tap(_tile('VID-20250101-WA0001.mp4'));
      await tester.tap(_tile('VID-20260901-WA0007.mp4'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('move-to-trash')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('restore anything from there for 7 days'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('confirm-move')));
      await tester.pumpAndSettle();

      expect(find.text('Moved 2 files (60 MB) to the trash'), findsOneWidget);
      await tester.tap(find.byKey(const Key('keep-in-trash')));
      await tester.pumpAndSettle();

      expect(app.storage.exists(_bigVideo), isFalse);
      expect(app.storage.exists(_newVideo), isFalse);
      expect(app.storage.trashedFiles(), hasLength(2));
      expect(app.trashStore.saved.last, hasLength(2));
      expect(_tile('VID-20250101-WA0001.mp4'), findsNothing);
      expect(find.byKey(const Key('move-to-trash')), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('5.5 MB'), findsOneWidget);
      expect(find.text('In the trash: 60 MB'), findsOneWidget);
    });

    testWidgets('delete now frees the space and counts it', (tester) async {
      final app = TestApp();
      addSampleMedia(app.storage);
      await app.pump(tester);
      await _scan(tester);
      await _openGroup(tester, 'largest');

      await tester.tap(_tile('VID-20250101-WA0001.mp4'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('move-to-trash')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-move')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-now')));
      await tester.pumpAndSettle();

      expect(find.text('Freed 48 MB'), findsOneWidget);
      expect(app.storage.trashedFiles(), isEmpty);
      expect(app.trashStore.saved.last, isEmpty);
      expect(app.settings.settings.freedBytes, 48 * mb);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('freed-so-far')),
        200,
      );
      expect(find.text('Freed so far: 48 MB'), findsOneWidget);
    });

    testWidgets('long press opens the preview, which can select', (
      tester,
    ) async {
      final app = TestApp();
      addSampleMedia(app.storage);
      await app.pump(tester);
      await _scan(tester);
      await _openGroup(tester, 'largest');

      await tester.longPress(_tile('VID-20250101-WA0001.mp4'));
      await tester.pumpAndSettle();
      expect(find.text('WhatsApp Video'), findsOneWidget);
      expect(find.text('48 MB'), findsOneWidget);

      await tester.tap(find.text('Open with…'));
      await tester.pump();
      expect(app.storage.opened, [_bigVideo]);

      await tester.tap(find.byKey(const Key('preview-select')));
      await tester.pump();
      expect(find.text('Selected'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('1 selected · 48 MB'), findsOneWidget);
    });

    testWidgets('lists files of one type from the summary', (tester) async {
      final app = TestApp();
      addSampleMedia(app.storage);
      await app.pump(tester);
      await _scan(tester);

      await tester.scrollUntilVisible(find.text('Documents'), 200);
      await tester.ensureVisible(find.text('Documents'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Documents'));
      await tester.pumpAndSettle();

      expect(find.byType(ReviewScreen), findsOneWidget);
      expect(_tile('Rent agreement.pdf'), findsOneWidget);
      expect(find.text('Rent agreement.pdf'), findsOneWidget);
    });
  });

  group('trash', () {
    TrashEntry entry(
      String path, {
      required DateTime trashedAt,
      int size = 5 * mb,
    }) {
      final name = path.substring(path.lastIndexOf('/') + 1);
      final folder = path.substring(0, path.lastIndexOf('/'));
      return TrashEntry(
        id: 'item-$name',
        sourceId: waTree,
        originalId: '$waMediaId/$path',
        originalParentId: '$waMediaId/$folder',
        relativePath: path,
        name: name,
        size: size,
        modified: DateTime.utc(2025),
        type: MediaClassifier.classify(path),
        trashedAt: trashedAt,
        item: TrashedItem(
          itemDirId: '$waMediaId/${MediaScanner.trashFolderName}/item-$name',
          fileId: '$waMediaId/${MediaScanner.trashFolderName}/item-$name/$name',
        ),
      );
    }

    TestApp appWithTrash(List<TrashEntry> entries) {
      final app = TestApp(trash: entries);
      app.storage.addDir('WhatsApp Images');
      for (final e in entries) {
        app.storage.addFile(
          '${MediaScanner.trashFolderName}/item-${e.name}/${e.name}',
          size: e.size,
        );
      }
      return app;
    }

    Future<void> openTrash(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('open-trash')));
      await tester.pumpAndSettle();
    }

    testWidgets('restores selected files to where they were', (tester) async {
      final app = appWithTrash([
        entry(
          'WhatsApp Images/IMG-1.jpg',
          trashedAt: DateTime.utc(2026, 10, 25),
        ),
        entry(
          'WhatsApp Images/IMG-2.jpg',
          trashedAt: DateTime.utc(2026, 10, 26),
        ),
      ]);
      await app.pump(tester);
      await openTrash(tester);

      expect(find.text('IMG-1.jpg'), findsOneWidget);
      expect(find.textContaining('Deleted for good in 5 days'), findsOneWidget);
      expect(find.textContaining('Deleted for good in 6 days'), findsOneWidget);

      await tester.tap(find.text('IMG-1.jpg'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('restore-selected')));
      await tester.pumpAndSettle();

      expect(find.text('Restored 1 file.'), findsOneWidget);
      expect(
        app.storage.exists('$waMediaId/WhatsApp Images/IMG-1.jpg'),
        isTrue,
      );
      expect(find.text('IMG-1.jpg'), findsNothing);
      expect(find.text('IMG-2.jpg'), findsOneWidget);
      expect(app.trashStore.saved.last.single.name, 'IMG-2.jpg');
    });

    testWidgets('keeps a file whose folder is gone and says why', (
      tester,
    ) async {
      final app = appWithTrash([
        entry(
          'WhatsApp Video/VID-1.mp4',
          trashedAt: DateTime.utc(2026, 10, 26),
        ),
      ]);
      await app.pump(tester);
      await openTrash(tester);

      await tester.tap(find.text('VID-1.mp4'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('restore-selected')));
      await tester.pumpAndSettle();

      expect(find.textContaining('folder no longer exists'), findsOneWidget);
      expect(find.text('VID-1.mp4'), findsOneWidget);
    });

    testWidgets('empty trash asks first, then frees the space', (tester) async {
      final app = appWithTrash([
        entry(
          'WhatsApp Images/IMG-1.jpg',
          trashedAt: DateTime.utc(2026, 10, 25),
        ),
        entry(
          'WhatsApp Images/IMG-2.jpg',
          trashedAt: DateTime.utc(2026, 10, 26),
        ),
      ]);
      await app.pump(tester);
      await openTrash(tester);

      await tester.tap(find.byKey(const Key('empty-trash')));
      await tester.pumpAndSettle();
      expect(find.text('Delete 2 files for good?'), findsOneWidget);
      expect(find.text("This frees 10 MB. You can't undo this."), findsOne);

      await tester.tap(find.byKey(const Key('confirm-delete')));
      await tester.pumpAndSettle();

      expect(find.text('Freed 10 MB'), findsOneWidget);
      expect(find.text('The trash is empty'), findsOneWidget);
      expect(app.storage.trashedFiles(), isEmpty);
      expect(app.settings.settings.freedBytes, 10 * mb);
    });

    testWidgets('files past the restore window are deleted on start', (
      tester,
    ) async {
      final app = appWithTrash([
        entry('WhatsApp Images/OLD.jpg', trashedAt: DateTime.utc(2026, 10, 19)),
        entry('WhatsApp Images/NEW.jpg', trashedAt: DateTime.utc(2026, 10, 26)),
      ]);
      await app.pump(tester);

      expect(app.trashStore.saved.last.single.name, 'NEW.jpg');
      expect(app.storage.trashedFiles().single, endsWith('NEW.jpg'));
      expect(app.settings.settings.freedBytes, 5 * mb);

      await openTrash(tester);
      expect(find.text('OLD.jpg'), findsNothing);
      expect(find.text('NEW.jpg'), findsOneWidget);
    });

    testWidgets('a restored file shows up in the scan results again', (
      tester,
    ) async {
      final app = TestApp();
      addSampleMedia(app.storage);
      await app.pump(tester);
      await _scan(tester);
      await _openGroup(tester, 'largest');

      await tester.tap(_tile('VID-20250101-WA0001.mp4'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('move-to-trash')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-move')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('keep-in-trash')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await openTrash(tester);
      await tester.tap(find.text('VID-20250101-WA0001.mp4'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('restore-selected')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(app.storage.exists(_bigVideo), isTrue);
      expect(find.text('65.5 MB'), findsOneWidget);
    });
  });

  testWidgets('settings change the age rule of the old media group', (
    tester,
  ) async {
    final app = TestApp();
    addSampleMedia(app.storage);
    await app.pump(tester);
    await _scan(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('group-oldForwards')),
      200,
    );
    expect(find.textContaining('older than 6 months'), findsOneWidget);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('6 months'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('24 months').last);
    await tester.pumpAndSettle();
    expect(app.settings.settings.oldAfterMonths, 24);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.textContaining('older than 24 months'), findsOneWidget);
  });
}
