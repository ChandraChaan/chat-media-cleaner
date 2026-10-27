import 'package:chat_media_cleaner/features/media/domain/media_file.dart';
import 'package:chat_media_cleaner/features/media/domain/media_report.dart';
import 'package:chat_media_cleaner/features/media/domain/media_type.dart';
import 'package:flutter_test/flutter_test.dart';

const _mb = 1024 * 1024;
final _now = DateTime.utc(2026, 10, 27, 12);

MediaFile _file(
  String path, {
  int size = 1000,
  DateTime? modified,
  MediaType? type,
  bool? sent,
}) => MediaFile(
  id: 'id:$path',
  sourceId: 'tree',
  parentId: 'id:${path.substring(0, path.lastIndexOf('/'))}',
  name: path.substring(path.lastIndexOf('/') + 1),
  relativePath: path,
  size: size,
  modified: modified ?? DateTime.utc(2026, 10, 1),
  type: type ?? MediaClassifier.classify(path),
  isSent: sent ?? MediaClassifier.isSent(path),
);

void main() {
  group('totals', () {
    test('adds up count and bytes per type, largest first', () {
      final report = MediaAnalyzer.analyze(
        [
          _file('WhatsApp Images/a.jpg', size: 100),
          _file('WhatsApp Images/b.jpg', size: 300),
          _file('WhatsApp Video/v.mp4', size: 5000),
          _file('WhatsApp Voice Notes/202401/p.opus', size: 50),
        ],
        rules: const AnalysisRules(),
        now: _now,
      );
      expect(report.totalBytes, 5450);
      expect(report.totalCount, 4);
      expect(report.ofType(MediaType.image).count, 2);
      expect(report.ofType(MediaType.image).bytes, 400);
      expect(report.ofType(MediaType.image).files.map((f) => f.name), [
        'b.jpg',
        'a.jpg',
      ]);
      expect(report.ofType(MediaType.video).bytes, 5000);
      expect(report.ofType(MediaType.voiceNote).count, 1);
      expect(report.byType.containsKey(MediaType.document), isFalse);
      expect(report.ofType(MediaType.document).isEmpty, isTrue);
    });

    test('an empty scan has empty groups', () {
      final report = MediaAnalyzer.analyze(
        const [],
        rules: const AnalysisRules(),
        now: _now,
      );
      expect(report.totalBytes, 0);
      for (final group in SmartGroup.values) {
        expect(report.group(group).isEmpty, isTrue);
      }
    });
  });

  group('largest files', () {
    test('lists files of at least the minimum size, largest first', () {
      final report = MediaAnalyzer.analyze(
        [
          _file('WhatsApp Video/small.mp4', size: _mb - 1),
          _file('WhatsApp Video/big.mp4', size: 40 * _mb),
          _file('WhatsApp Documents/doc.pdf', size: 3 * _mb),
          _file('WhatsApp Images/exact.jpg', size: _mb),
        ],
        rules: const AnalysisRules(),
        now: _now,
      );
      expect(report.group(SmartGroup.largest).files.map((f) => f.name), [
        'big.mp4',
        'doc.pdf',
        'exact.jpg',
      ]);
      expect(report.group(SmartGroup.largest).bytes, 44 * _mb);
    });

    test('keeps at most largestCount files', () {
      final files = [
        for (var i = 1; i <= 10; i++)
          _file('WhatsApp Video/v$i.mp4', size: i * _mb),
      ];
      final report = MediaAnalyzer.analyze(
        files,
        rules: const AnalysisRules(largestCount: 3),
        now: _now,
      );
      expect(report.group(SmartGroup.largest).files.map((f) => f.name), [
        'v10.mp4',
        'v9.mp4',
        'v8.mp4',
      ]);
    });

    test('breaks size ties by path so the order is stable', () {
      final report = MediaAnalyzer.analyze(
        [
          _file('WhatsApp Video/b.mp4', size: 2 * _mb),
          _file('WhatsApp Video/a.mp4', size: 2 * _mb),
        ],
        rules: const AnalysisRules(),
        now: _now,
      );
      expect(report.group(SmartGroup.largest).files.map((f) => f.name), [
        'a.mp4',
        'b.mp4',
      ]);
    });
  });

  group('old forwards and memes', () {
    final old = DateTime.utc(2026, 1, 1);

    test('includes received photos, GIFs and short videos past the age', () {
      final report = MediaAnalyzer.analyze(
        [
          _file('WhatsApp Images/meme.jpg', modified: old),
          _file('WhatsApp Animated Gifs/g.mp4', modified: old),
          _file('WhatsApp Video/clip.mp4', size: 5 * _mb, modified: old),
          _file('WhatsApp Images/new.jpg', modified: DateTime.utc(2026, 10)),
        ],
        rules: const AnalysisRules(),
        now: _now,
      );
      expect(
        report.group(SmartGroup.oldForwards).files.map((f) => f.name),
        unorderedEquals(['meme.jpg', 'g.mp4', 'clip.mp4']),
      );
    });

    test('leaves out sent media, long videos and personal types', () {
      final report = MediaAnalyzer.analyze(
        [
          _file('WhatsApp Images/Sent/mine.jpg', modified: old),
          _file('WhatsApp Video/wedding.mp4', size: 200 * _mb, modified: old),
          _file('WhatsApp Voice Notes/202401/p.opus', modified: old),
          _file('WhatsApp Documents/contract.pdf', modified: old),
          _file('WhatsApp Stickers/s.webp', modified: old),
          _file('.Statuses/st.jpg', modified: old),
        ],
        rules: const AnalysisRules(),
        now: _now,
      );
      expect(report.group(SmartGroup.oldForwards).isEmpty, isTrue);
    });

    test('a video exactly at the size limit is included', () {
      final report = MediaAnalyzer.analyze(
        [_file('WhatsApp Video/v.mp4', size: 16 * _mb, modified: old)],
        rules: const AnalysisRules(),
        now: _now,
      );
      expect(report.group(SmartGroup.oldForwards).count, 1);
    });

    test('uses the age rule in months, oldest first', () {
      final files = [
        _file('WhatsApp Images/4m.jpg', modified: DateTime.utc(2026, 6, 20)),
        _file('WhatsApp Images/8m.jpg', modified: DateTime.utc(2026, 2, 20)),
        _file('WhatsApp Images/13m.jpg', modified: DateTime.utc(2025, 9, 20)),
      ];
      String names(int months) => MediaAnalyzer.analyze(
        files,
        rules: AnalysisRules(oldAfterMonths: months),
        now: _now,
      ).group(SmartGroup.oldForwards).files.map((f) => f.name).join(',');

      expect(names(3), '13m.jpg,8m.jpg,4m.jpg');
      expect(names(6), '13m.jpg,8m.jpg');
      expect(names(12), '13m.jpg');
      expect(names(24), '');
    });

    test('a file modified exactly at the cutoff is not old yet', () {
      final cutoff = monthsBefore(_now, 6);
      final report = MediaAnalyzer.analyze(
        [
          _file('WhatsApp Images/edge.jpg', modified: cutoff),
          _file(
            'WhatsApp Images/older.jpg',
            modified: cutoff.subtract(const Duration(seconds: 1)),
          ),
        ],
        rules: const AnalysisRules(),
        now: _now,
      );
      expect(
        report.group(SmartGroup.oldForwards).files.single.name,
        'older.jpg',
      );
    });
  });

  test('sent copies lists everything in Sent folders, largest first', () {
    final report = MediaAnalyzer.analyze(
      [
        _file('WhatsApp Images/Sent/a.jpg', size: 10),
        _file('WhatsApp Video/Sent/b.mp4', size: 99),
        _file('WhatsApp Images/c.jpg', size: 50),
      ],
      rules: const AnalysisRules(),
      now: _now,
    );
    expect(report.group(SmartGroup.sentCopies).files.map((f) => f.name), [
      'b.mp4',
      'a.jpg',
    ]);
    expect(report.group(SmartGroup.sentCopies).bytes, 109);
  });

  group('monthsBefore', () {
    test('subtracts calendar months', () {
      expect(
        monthsBefore(DateTime.utc(2026, 10, 27, 8, 30), 6),
        DateTime.utc(2026, 4, 27, 8, 30),
      );
      expect(
        monthsBefore(DateTime.utc(2026, 1, 15), 1),
        DateTime.utc(2025, 12, 15),
      );
      expect(
        monthsBefore(DateTime.utc(2026, 3, 10), 24),
        DateTime.utc(2024, 3, 10),
      );
    });

    test('clamps to the end of shorter months', () {
      expect(
        monthsBefore(DateTime.utc(2026, 3, 31), 1),
        DateTime.utc(2026, 2, 28),
      );
      expect(
        monthsBefore(DateTime.utc(2024, 3, 31), 1),
        DateTime.utc(2024, 2, 29),
      );
      expect(
        monthsBefore(DateTime.utc(2026, 10, 31), 6),
        DateTime.utc(2026, 4, 30),
      );
    });

    test('works from local times', () {
      final local = DateTime(2026, 5, 15, 12);
      expect(monthsBefore(local, 0), local.toUtc());
      expect(monthsBefore(local, 0).isUtc, isTrue);
    });
  });
}
