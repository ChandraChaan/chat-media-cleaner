import 'package:chat_media_cleaner/features/viewer/domain/share_mime.dart';
import 'package:chat_media_cleaner/features/viewer/domain/view_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ViewKinds.of', () {
    ViewKind kind(String name, [String? mime]) =>
        ViewKinds.of(name: name, mimeType: mime);

    test('knows the usual chat media by extension', () {
      expect(kind('IMG-20240101-WA0001.jpg', 'image/jpeg'), ViewKind.image);
      expect(kind('STK-20240101-WA0001.webp', 'image/webp'), ViewKind.image);
      expect(kind('VID-20240101-WA0001.mp4', 'video/mp4'), ViewKind.video);
      expect(kind('PTT-20240101-WA0001.opus', 'audio/ogg'), ViewKind.audio);
      expect(kind('AUD-20240101-WA0001.m4a', 'audio/mp4'), ViewKind.audio);
      expect(kind('Rent agreement.pdf', 'application/pdf'), ViewKind.pdf);
      expect(kind('notes.txt', 'text/plain'), ViewKind.text);
    });

    test('trusts a clear extension over a vague or wrong type', () {
      // Voice notes are sometimes reported as application/ogg, and files
      // from other apps as plain binary data.
      expect(kind('PTT-1.opus', 'application/ogg'), ViewKind.audio);
      expect(kind('scan.PDF', 'application/octet-stream'), ViewKind.pdf);
      expect(kind('contacts.vcf', 'application/octet-stream'), ViewKind.text);
      expect(kind('clip.MP4'), ViewKind.video);
    });

    test('falls back to the type when the extension says nothing', () {
      expect(kind('photo', 'image/jpeg'), ViewKind.image);
      expect(kind('clip.bin', 'video/webm'), ViewKind.video);
      expect(kind('voice', 'application/ogg'), ViewKind.audio);
      expect(kind('doc', 'application/pdf'), ViewKind.pdf);
      expect(kind('data', 'application/json'), ViewKind.text);
      expect(kind('readme', 'text/markdown'), ViewKind.text);
    });

    test('gives up on everything else', () {
      expect(kind('sheet.xlsx', 'application/vnd.ms-excel'), ViewKind.other);
      expect(kind('archive.zip', 'application/zip'), ViewKind.other);
      expect(kind('mystery'), ViewKind.other);
      expect(kind('.nomedia'), ViewKind.other);
    });
  });

  group('ViewKinds.extensionOf', () {
    test('is lowercase and without the dot', () {
      expect(ViewKinds.extensionOf('A.JPG'), 'jpg');
      expect(ViewKinds.extensionOf('a.tar.gz'), 'gz');
    });

    test('is empty for hidden files and names that end in a dot', () {
      expect(ViewKinds.extensionOf('.hidden'), '');
      expect(ViewKinds.extensionOf('name.'), '');
      expect(ViewKinds.extensionOf('name'), '');
    });
  });

  group('ShareMime.of', () {
    test('keeps the exact type when all files share it', () {
      expect(ShareMime.of(['image/jpeg', 'image/jpeg']), 'image/jpeg');
      expect(ShareMime.of(['Application/PDF']), 'application/pdf');
    });

    test('widens to the family when only that is shared', () {
      expect(ShareMime.of(['image/jpeg', 'image/png']), 'image/*');
      expect(ShareMime.of(['video/mp4', 'video/webm']), 'video/*');
    });

    test('is anything for mixed, unknown or no files', () {
      expect(ShareMime.of(['image/jpeg', 'video/mp4']), '*/*');
      expect(ShareMime.of(['image/jpeg', null]), '*/*');
      expect(ShareMime.of(['nonsense']), '*/*');
      expect(ShareMime.of(const []), '*/*');
    });
  });
}
