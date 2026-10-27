import 'package:chat_media_cleaner/features/media/domain/cancel_token.dart';
import 'package:chat_media_cleaner/features/media/domain/duplicate_finder.dart';
import 'package:chat_media_cleaner/features/media/domain/media_file.dart';
import 'package:chat_media_cleaner/features/media/domain/media_report.dart';
import 'package:chat_media_cleaner/features/media/domain/media_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_media_storage.dart';

void main() {
  late FakeMediaStorage storage;

  setUp(() {
    storage = FakeMediaStorage()..grant(waTree, waMediaId);
  });

  Future<List<MediaFile>> scan() async =>
      (await MediaScanner(storage).scan([waSource])).files;

  void add(String path, String content, {int? size, DateTime? date}) =>
      storage.addFile(
        path,
        content: content,
        size: size ?? content.length * 1000,
        modified: date ?? DateTime.utc(2025),
      );

  test('groups identical files and keeps the oldest', () async {
    add('WhatsApp Images/IMG-1.jpg', 'meme', date: DateTime.utc(2025, 3));
    add('WhatsApp Images/IMG-2.jpg', 'meme', date: DateTime.utc(2025, 1));
    add('WhatsApp Images/Sent/IMG-3.jpg', 'meme', date: DateTime.utc(2025, 6));
    add('WhatsApp Images/IMG-4.jpg', 'other');

    final sets = await DuplicateFinder(storage).find(await scan());

    expect(sets, hasLength(1));
    expect(sets.single.keep.name, 'IMG-2.jpg');
    expect(sets.single.copies.map((f) => f.name), ['IMG-1.jpg', 'IMG-3.jpg']);
    expect(sets.single.wastedBytes, 8000);
  });

  test('same size but different content is not a duplicate', () async {
    add('WhatsApp Video/a.mp4', 'aaaa');
    add('WhatsApp Video/b.mp4', 'bbbb');
    final sets = await DuplicateFinder(storage).find(await scan());
    expect(sets, isEmpty);
    expect(storage.hashCalls, 2);
  });

  test('only hashes files that share a size', () async {
    add('WhatsApp Video/a.mp4', 'x', size: 100);
    add('WhatsApp Video/b.mp4', 'x', size: 200);
    add('WhatsApp Video/c.mp4', 'x', size: 300);
    add('WhatsApp Images/d.jpg', 'y', size: 400);
    add('WhatsApp Images/e.jpg', 'y', size: 400);
    final sets = await DuplicateFinder(storage).find(await scan());
    expect(storage.hashCalls, 2);
    expect(sets.single.files.map((f) => f.name), ['d.jpg', 'e.jpg']);
  });

  test('ties on date keep the first path', () async {
    add('WhatsApp Images/b.jpg', 'same');
    add('WhatsApp Images/a.jpg', 'same');
    final sets = await DuplicateFinder(storage).find(await scan());
    expect(sets.single.keep.name, 'a.jpg');
  });

  test('ignores empty files', () async {
    add('WhatsApp Documents/a.txt', '', size: 0);
    add('WhatsApp Documents/b.txt', '', size: 0);
    expect(DuplicateFinder.candidates(await scan()), isEmpty);
    expect(await DuplicateFinder(storage).find(await scan()), isEmpty);
  });

  test('does not compare across sources', () async {
    storage.grant(wabTree, wabMediaId);
    add('WhatsApp Images/a.jpg', 'same');
    storage.addFile(
      'WhatsApp Business Images/a.jpg',
      content: 'same',
      size: 4000,
      rootId: wabMediaId,
    );
    final files = (await MediaScanner(
      storage,
    ).scan([waSource, wabSource])).files;
    expect(files, hasLength(2));
    expect(await DuplicateFinder(storage).find(files), isEmpty);
  });

  test('sorts sets by wasted space', () async {
    add('WhatsApp Images/small-1.jpg', 'small', size: 10);
    add('WhatsApp Images/small-2.jpg', 'small', size: 10);
    add('WhatsApp Video/big-1.mp4', 'big', size: 5000);
    add('WhatsApp Video/big-2.mp4', 'big', size: 5000);
    add('WhatsApp Video/big-3.mp4', 'big', size: 5000);
    final sets = await DuplicateFinder(storage).find(await scan());
    expect(sets.map((s) => s.wastedBytes), [10000, 10]);
  });

  test('leaves out files that cannot be read', () async {
    add('WhatsApp Images/a.jpg', 'same');
    add('WhatsApp Images/b.jpg', 'same');
    add('WhatsApp Images/c.jpg', 'same');
    storage.failHashes.add('$waMediaId/WhatsApp Images/a.jpg');
    final sets = await DuplicateFinder(storage).find(await scan());
    expect(sets.single.files.map((f) => f.name), ['b.jpg', 'c.jpg']);
  });

  test('reports progress up to the number of candidates', () async {
    for (var i = 0; i < 5; i++) {
      add('WhatsApp Stickers/s$i.webp', 'sticker');
    }
    final updates = <(int, int)>[];
    await DuplicateFinder(storage).find(
      await scan(),
      onProgress: (done, total) => updates.add((done, total)),
    );
    expect(updates.first, (0, 5));
    expect(updates.last, (5, 5));
    expect(updates.map((u) => u.$1), [0, 1, 2, 3, 4, 5]);
  });

  test('stops when cancelled', () async {
    for (var i = 0; i < 10; i++) {
      add('WhatsApp Stickers/s$i.webp', 'sticker');
    }
    final cancel = CancelToken();
    final future = DuplicateFinder(storage, parallel: 1).find(
      await scan(),
      cancel: cancel,
      onProgress: (done, _) {
        if (done == 3) cancel.cancel();
      },
    );
    await expectLater(future, throwsA(isA<ScanCancelled>()));
    expect(storage.hashCalls, 3);
  });

  group('in the report', () {
    final now = DateTime.utc(2026, 10, 27);

    test(
      'the duplicates group lists the extra copies, largest first',
      () async {
        add(
          'WhatsApp Video/v1.mp4',
          'video',
          size: 900,
          date: DateTime.utc(2024),
        );
        add('WhatsApp Video/v2.mp4', 'video', size: 900);
        add(
          'WhatsApp Images/i1.jpg',
          'image',
          size: 50,
          date: DateTime.utc(2024),
        );
        add('WhatsApp Images/i2.jpg', 'image', size: 50);
        add('WhatsApp Images/i3.jpg', 'image', size: 50);
        final files = await scan();
        final sets = await DuplicateFinder(storage).find(files);

        final report = MediaAnalyzer.analyze(
          files,
          rules: const AnalysisRules(),
          now: now,
          duplicates: sets,
        );
        final group = report.group(SmartGroup.duplicates);
        expect(group.files.map((f) => f.name), ['v2.mp4', 'i2.jpg', 'i3.jpg']);
        expect(group.bytes, 1000);
        expect(report.duplicateSets, hasLength(2));
      },
    );

    test('a set always keeps one file when files are removed', () async {
      add('WhatsApp Images/a.jpg', 'x', date: DateTime.utc(2024));
      add('WhatsApp Images/b.jpg', 'x', date: DateTime.utc(2025));
      add('WhatsApp Images/c.jpg', 'x', date: DateTime.utc(2026));
      final files = await scan();
      final sets = await DuplicateFinder(storage).find(files);

      // The kept oldest file was trashed from another group.
      final withoutOldest = files.where((f) => f.name != 'a.jpg').toList();
      var report = MediaAnalyzer.analyze(
        withoutOldest,
        rules: const AnalysisRules(),
        now: now,
        duplicates: sets,
      );
      expect(report.duplicateSets.single.keep.name, 'b.jpg');
      expect(report.group(SmartGroup.duplicates).files.single.name, 'c.jpg');

      // Only one copy left: no longer a duplicate.
      report = MediaAnalyzer.analyze(
        files.where((f) => f.name == 'c.jpg').toList(),
        rules: const AnalysisRules(),
        now: now,
        duplicates: sets,
      );
      expect(report.group(SmartGroup.duplicates).isEmpty, isTrue);
      expect(report.duplicateSets, isEmpty);
    });

    test('without hashes the group is empty', () async {
      add('WhatsApp Images/a.jpg', 'x');
      add('WhatsApp Images/b.jpg', 'x');
      final report = MediaAnalyzer.analyze(
        await scan(),
        rules: const AnalysisRules(),
        now: now,
      );
      expect(report.group(SmartGroup.duplicates).isEmpty, isTrue);
    });
  });
}
