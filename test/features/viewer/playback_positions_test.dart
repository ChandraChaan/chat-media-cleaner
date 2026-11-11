import 'package:chat_media_cleaner/features/viewer/domain/playback_positions.dart';
import 'package:chat_media_cleaner/features/viewer/presentation/sleep_timer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_stores.dart';

const _tenMinutes = Duration(minutes: 10);

void main() {
  group('PlaybackPositions', () {
    late MemoryPlaybackPositionStore store;
    late PlaybackPositions positions;

    setUp(() {
      store = MemoryPlaybackPositionStore();
      positions = PlaybackPositions(store);
    });

    test('carries on from where a video was stopped', () async {
      await positions.remember(
        'a',
        position: const Duration(minutes: 3),
        duration: _tenMinutes,
      );
      expect(store.positions, {'a': 180000});
      expect(
        await positions.resumeAt('a', duration: _tenMinutes),
        const Duration(minutes: 3),
      );
      expect(await positions.resumeAt('other', duration: _tenMinutes), isNull);
    });

    test('survives a restart', () async {
      await positions.remember(
        'a',
        position: const Duration(minutes: 3),
        duration: _tenMinutes,
      );
      final again = PlaybackPositions(store);
      expect(
        await again.resumeAt('a', duration: _tenMinutes),
        const Duration(minutes: 3),
      );
    });

    test('starts over when stopped in the first seconds', () async {
      await positions.remember(
        'a',
        position: const Duration(seconds: 4),
        duration: _tenMinutes,
      );
      expect(store.positions, isEmpty);
    });

    test('forgets a video that was watched to the end', () async {
      await positions.remember(
        'a',
        position: const Duration(minutes: 3),
        duration: _tenMinutes,
      );
      await positions.remember(
        'a',
        position: const Duration(minutes: 9, seconds: 55),
        duration: _tenMinutes,
      );
      expect(store.positions, isEmpty);
      expect(await positions.resumeAt('a', duration: _tenMinutes), isNull);
    });

    test('ignores a position that no longer fits the file', () async {
      store.positions = {'a': 180000};
      expect(
        await PlaybackPositions(
          store,
        ).resumeAt('a', duration: const Duration(minutes: 3)),
        isNull,
      );
    });

    test('never remembers without a known length', () {
      expect(
        PlaybackPositions.worthResuming(
          const Duration(minutes: 1),
          Duration.zero,
        ),
        isFalse,
      );
    });

    test('keeps only the most recent videos', () async {
      for (var i = 0; i < PlaybackPositions.maxEntries + 5; i++) {
        await positions.remember(
          'v$i',
          position: const Duration(minutes: 1),
          duration: _tenMinutes,
        );
      }
      expect(store.positions, hasLength(PlaybackPositions.maxEntries));
      expect(store.positions.containsKey('v0'), isFalse);
      expect(store.positions.containsKey('v5'), isTrue);

      // Watching an old one again makes it the newest.
      await positions.remember(
        'v5',
        position: const Duration(minutes: 2),
        duration: _tenMinutes,
      );
      await positions.remember(
        'new',
        position: const Duration(minutes: 1),
        duration: _tenMinutes,
      );
      expect(store.positions.containsKey('v5'), isTrue);
      expect(store.positions.containsKey('v6'), isFalse);
    });
  });

  group('sleep timer', () {
    testWidgets('fires once after the chosen time', (tester) async {
      final container = ProviderContainer.test();
      final timer = container.read(sleepTimerProvider.notifier);

      timer.set(15);
      expect(container.read(sleepTimerProvider).minutes, 15);
      await tester.pump(const Duration(minutes: 14, seconds: 59));
      expect(container.read(sleepTimerProvider).fired, 0);
      await tester.pump(const Duration(seconds: 2));
      expect(container.read(sleepTimerProvider).fired, 1);
      expect(container.read(sleepTimerProvider).minutes, isNull);
    });

    testWidgets('can be turned off or started over', (tester) async {
      final container = ProviderContainer.test();
      final timer = container.read(sleepTimerProvider.notifier);

      timer.set(15);
      await tester.pump(const Duration(minutes: 10));
      timer.set(30);
      await tester.pump(const Duration(minutes: 20));
      expect(container.read(sleepTimerProvider).fired, 0);

      timer.set(null);
      expect(container.read(sleepTimerProvider).minutes, isNull);
      await tester.pump(const Duration(hours: 2));
      expect(container.read(sleepTimerProvider).fired, 0);
    });
  });
}
