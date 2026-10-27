import 'package:chat_media_cleaner/features/media/domain/media_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MediaClassifier.classify', () {
    test('maps WhatsApp folders to types', () {
      const cases = {
        'WhatsApp Images/IMG-20240101-WA0001.jpg': MediaType.image,
        'WhatsApp Video/VID-20240101-WA0001.mp4': MediaType.video,
        'WhatsApp Animated Gifs/VID-20240101-WA0002.mp4': MediaType.gif,
        'WhatsApp Voice Notes/202403/PTT-20240115-WA0001.opus':
            MediaType.voiceNote,
        'WhatsApp Audio/AUD-20240101-WA0001.mp3': MediaType.audio,
        'WhatsApp Documents/Invoice.pdf': MediaType.document,
        'WhatsApp Stickers/STK-20240101-WA0001.webp': MediaType.sticker,
        '.Statuses/abc123.jpg': MediaType.status,
        'WhatsApp Video Notes/VID-1.mp4': MediaType.video,
        'WhatsApp Profile Photos/photo.jpg': MediaType.image,
      };
      for (final MapEntry(key: path, value: type) in cases.entries) {
        expect(MediaClassifier.classify(path), type, reason: path);
      }
    });

    test('maps WhatsApp Business folders the same way', () {
      expect(
        MediaClassifier.classify('WhatsApp Business Images/IMG-1.jpg'),
        MediaType.image,
      );
      expect(
        MediaClassifier.classify('WhatsApp Business Voice Notes/202401/P.opus'),
        MediaType.voiceNote,
      );
      expect(
        MediaClassifier.classify('WhatsApp Business Animated Gifs/V.mp4'),
        MediaType.gif,
      );
    });

    test('ignores folder name case', () {
      expect(
        MediaClassifier.classify('whatsapp video/clip.mp4'),
        MediaType.video,
      );
    });

    test('keeps the folder type for files in Sent and Private', () {
      expect(
        MediaClassifier.classify('WhatsApp Images/Sent/IMG-1.jpg'),
        MediaType.image,
      );
      expect(
        MediaClassifier.classify('WhatsApp Video/Private/VID-1.mp4'),
        MediaType.video,
      );
    });

    test('falls back to the MIME type outside known folders', () {
      expect(
        MediaClassifier.classify('Other/a.jpg', mimeType: 'image/jpeg'),
        MediaType.image,
      );
      expect(
        MediaClassifier.classify('a.gif', mimeType: 'image/gif'),
        MediaType.gif,
      );
      expect(
        MediaClassifier.classify('x/s.webp', mimeType: 'image/webp'),
        MediaType.sticker,
      );
      expect(
        MediaClassifier.classify('x/v.mp4', mimeType: 'video/mp4'),
        MediaType.video,
      );
      expect(
        MediaClassifier.classify('x/a.ogg', mimeType: 'audio/ogg'),
        MediaType.audio,
      );
      expect(
        MediaClassifier.classify('x/d.pdf', mimeType: 'application/pdf'),
        MediaType.document,
      );
      expect(MediaClassifier.classify('x/unknown'), MediaType.other);
      expect(
        MediaClassifier.classify('x/f', mimeType: 'font/ttf'),
        MediaType.other,
      );
    });

    test('a file directly in the Media folder uses its MIME type', () {
      expect(
        MediaClassifier.classify('WhatsApp Images', mimeType: 'video/mp4'),
        MediaType.video,
      );
    });
  });

  group('MediaClassifier.isSent', () {
    test('is true only for files in a Sent sub-folder', () {
      expect(MediaClassifier.isSent('WhatsApp Images/Sent/IMG-1.jpg'), isTrue);
      expect(MediaClassifier.isSent('WhatsApp Video/sent/VID-1.mp4'), isTrue);
      expect(MediaClassifier.isSent('WhatsApp Images/IMG-1.jpg'), isFalse);
      expect(MediaClassifier.isSent('Sent/IMG-1.jpg'), isFalse);
      expect(MediaClassifier.isSent('WhatsApp Images/Sent'), isFalse);
    });
  });

  group('MediaClassifier.isIgnoredFile', () {
    test('skips housekeeping files', () {
      expect(MediaClassifier.isIgnoredFile('.nomedia'), isTrue);
      expect(MediaClassifier.isIgnoredFile('.trashed-1700000-IMG.jpg'), isTrue);
      expect(MediaClassifier.isIgnoredFile('IMG-1.jpg'), isFalse);
      expect(MediaClassifier.isIgnoredFile('.hidden.jpg'), isFalse);
    });
  });

  test('hasPicture is true for visual types only', () {
    expect(
      MediaType.values.where((t) => t.hasPicture),
      unorderedEquals([
        MediaType.video,
        MediaType.image,
        MediaType.sticker,
        MediaType.gif,
        MediaType.status,
      ]),
    );
  });
}
