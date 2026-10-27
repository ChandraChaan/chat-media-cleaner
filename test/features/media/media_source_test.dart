import 'package:chat_media_cleaner/features/media/domain/media_source.dart';
import 'package:chat_media_cleaner/features/media/domain/media_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_media_storage.dart';

void main() {
  group('SourceLocator.initialDocId', () {
    test('points at Android/media on Android 11 and newer', () {
      expect(
        SourceLocator.initialDocId(ChatApp.whatsapp, 30),
        'primary:Android/media/com.whatsapp/WhatsApp/Media',
      );
      expect(
        SourceLocator.initialDocId(ChatApp.whatsappBusiness, 35),
        'primary:Android/media/com.whatsapp.w4b/WhatsApp Business/Media',
      );
    });

    test('points at the old top-level folder on Android 10 and older', () {
      expect(
        SourceLocator.initialDocId(ChatApp.whatsapp, 29),
        'primary:WhatsApp/Media',
      );
      expect(
        SourceLocator.initialDocId(ChatApp.whatsappBusiness, 26),
        'primary:WhatsApp Business/Media',
      );
    });

    test('uses the WhatsApp folder for other apps', () {
      expect(
        SourceLocator.initialDocId(ChatApp.other, 34),
        'primary:Android/media/com.whatsapp/WhatsApp/Media',
      );
    });
  });

  test('pathOf strips the volume', () {
    expect(SourceLocator.pathOf('primary:WhatsApp/Media'), 'WhatsApp/Media');
    expect(SourceLocator.pathOf('1234-ABCD:'), '');
    expect(SourceLocator.pathOf('no-volume'), 'no-volume');
  });

  group('SourceLocator.resolve', () {
    late FakeMediaStorage storage;

    setUp(() {
      storage = FakeMediaStorage()
        ..addFile('WhatsApp Images/a.jpg')
        ..addFile('WhatsApp Images/b.jpg', rootId: wabMediaId);
    });

    Future<List<MediaSource>> pick(String treeUri, String docId) {
      storage.grant(treeUri, docId);
      return SourceLocator.resolve(
        storage,
        PickedFolder(treeUri: treeUri, treeDocId: docId),
      );
    }

    test('accepts the modern WhatsApp Media folder itself', () async {
      final sources = await pick('tree:wa', waMediaId);
      expect(sources, [
        const MediaSource(
          treeUri: 'tree:wa',
          rootId: waMediaId,
          app: ChatApp.whatsapp,
        ),
      ]);
    });

    test('finds the Media folder below a picked parent', () async {
      final sources = await pick(
        'tree:wa',
        'primary:Android/media/com.whatsapp',
      );
      expect(sources.single.rootId, waMediaId);
      expect(sources.single.app, ChatApp.whatsapp);
      expect(sources.single.treeUri, 'tree:wa');
    });

    test('detects WhatsApp Business', () async {
      final sources = await pick(
        'tree:wab',
        'primary:Android/media/com.whatsapp.w4b',
      );
      expect(sources.single.rootId, wabMediaId);
      expect(sources.single.app, ChatApp.whatsappBusiness);
    });

    test('finds both apps when Android/media is picked', () async {
      final sources = await pick('tree:all', 'primary:Android/media');
      expect(sources.map((s) => s.app), [
        ChatApp.whatsapp,
        ChatApp.whatsappBusiness,
      ]);
      expect(sources.map((s) => s.rootId), [waMediaId, wabMediaId]);
    });

    test('accepts the legacy layout from Android 10 and older', () async {
      storage.addFile('WhatsApp Video/v.mp4', rootId: 'primary:WhatsApp/Media');
      final sources = await pick('tree:legacy', 'primary:WhatsApp');
      expect(sources.single.rootId, 'primary:WhatsApp/Media');
      expect(sources.single.app, ChatApp.whatsapp);
    });

    test(
      'prefers the modern folder when both layouts are under the pick',
      () async {
        storage.addFile(
          'WhatsApp Video/v.mp4',
          rootId: 'primary:WhatsApp/Media',
        );
        storage.grant('tree:root', 'primary:');
        final sources = await SourceLocator.resolve(
          storage,
          const PickedFolder(treeUri: 'tree:root', treeDocId: 'primary:'),
        );
        expect(
          sources.where((s) => s.app == ChatApp.whatsapp).single.rootId,
          waMediaId,
        );
      },
    );

    test('accepts a copied media folder elsewhere by its contents', () async {
      storage.addFile(
        'WhatsApp Images/c.jpg',
        rootId: 'ABCD-1234:Backup/WhatsApp copy',
      );
      final sources = await pick('tree:sd', 'ABCD-1234:Backup/WhatsApp copy');
      expect(sources.single.rootId, 'ABCD-1234:Backup/WhatsApp copy');
      expect(sources.single.app, ChatApp.whatsapp);
    });

    test('rejects a folder without chat media', () async {
      storage.addFile('photo.jpg', rootId: 'primary:DCIM/Camera');
      await expectLater(
        pick('tree:dcim', 'primary:DCIM/Camera'),
        throwsA(isA<NotAChatMediaFolder>()),
      );
    });

    test('rejects a known parent whose Media folder is missing', () async {
      final empty = FakeMediaStorage()
        ..grant('tree:wab', 'primary:Android/media/com.whatsapp.w4b');
      await expectLater(
        SourceLocator.resolve(
          empty,
          const PickedFolder(
            treeUri: 'tree:wab',
            treeDocId: 'primary:Android/media/com.whatsapp.w4b',
          ),
        ),
        throwsA(isA<NotAChatMediaFolder>()),
      );
    });
  });

  test('MediaSource survives a JSON round trip', () {
    expect(MediaSource.fromJson(waSource.toJson()), waSource);
    expect(
      MediaSource.fromJson({...wabSource.toJson(), 'app': 'unknown'}).app,
      ChatApp.other,
    );
  });
}
