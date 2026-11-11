import 'package:chat_media_cleaner/features/viewer/presentation/player_controls.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../support/fake_media_storage.dart';
import '../support/fake_video_platform.dart';
import '../support/test_app.dart';

const _tall = 'VID-20250101-WA0001.mp4';
const _wide = 'VID-20260901-WA0007.mp4';
const _tallId = '$waMediaId/WhatsApp Video/$_tall';
const _tallKey = '$waTree|$_tallId';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder get _video => find.byKey(const Key('video-gestures'));
Finder get _indicator => find.byKey(const Key('player-indicator'));

void main() {
  late FakeVideoPlatform player;
  late TestApp app;

  setUp(() {
    player = FakeVideoPlatform();
    VideoPlayerPlatform.instance = player;
    app = TestApp();
    addSampleMedia(app.storage);
  });

  /// Opens [name] from [folder] in the viewer.
  Future<void> open(
    WidgetTester tester, {
    String folder = 'WhatsApp Video',
    String name = _tall,
  }) async {
    await app.pump(tester);
    await _tap(tester, find.byKey(const Key('tab-files')));
    await _tap(tester, find.text('WhatsApp'));
    await _tap(tester, find.text(folder));
    await _tap(tester, find.text(name));
  }

  testWidgets('plays at once, keeps the screen on, and pauses on a tap', (
    tester,
  ) async {
    await open(tester);

    expect(player.opened.single, startsWith('content://fake/'));
    expect(player.calls, contains('play'));
    expect(app.storage.screenOn, [true]);
    expect(find.byTooltip('Pause'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('player-play')));
    expect(player.calls.last, 'pause');
    expect(app.storage.screenOn, [true, false]);
    expect(find.byTooltip('Play'), findsOneWidget);
  });

  testWidgets('a double tap on either half skips ten seconds', (tester) async {
    player.position = const Duration(seconds: 60);
    await open(tester);
    await tester.pump(const Duration(milliseconds: 600));
    final box = tester.getRect(_video);

    Future<void> doubleTap(Offset at) async {
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(at);
      await tester.pumpAndSettle();
    }

    await doubleTap(Offset(box.right - 40, box.center.dy - 120));
    expect(player.seeks.last, 70);
    expect(find.text('10 s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await doubleTap(Offset(box.left + 40, box.center.dy - 120));
    expect(player.seeks.last, 60);
  });

  testWidgets('a sideways swipe scrubs and seeks on release', (tester) async {
    await open(tester);
    final box = tester.getRect(_video);

    final gesture = await tester.startGesture(
      Offset(box.left + 60, box.center.dy - 150),
    );
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.moveBy(Offset(box.width / 2, 2));
    await tester.pump();

    // Half the width is 45 seconds.
    expect(_indicator, findsOneWidget);
    expect(find.textContaining('/ 5:00'), findsOneWidget);
    expect(player.seeks, isEmpty);

    await gesture.up();
    await tester.pump();
    expect(player.seeks.single, inInclusiveRange(44, 52));
    await tester.pump(const Duration(seconds: 1));
    expect(_indicator, findsNothing);
  });

  testWidgets('swiping up on the left brightens, on the right turns it up', (
    tester,
  ) async {
    await open(tester);
    final box = tester.getRect(_video);

    Future<void> swipeUp(double x) async {
      final gesture = await tester.startGesture(Offset(x, box.center.dy));
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -120));
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(seconds: 1));
    }

    expect(app.storage.screenBrightness, isNull);
    await swipeUp(box.left + 60);
    // From the middle (the screen was following the system) upwards.
    expect(app.storage.screenBrightness, greaterThan(0.6));
    expect(app.storage.mediaVolume, 5);

    await swipeUp(box.right - 60);
    expect(app.storage.mediaVolume, greaterThan(6));

    // Leaving the viewer gives the brightness back to the system.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(app.storage.screenBrightness, isNull);
  });

  testWidgets('holding plays at double speed until let go', (tester) async {
    await open(tester);
    final box = tester.getRect(_video);

    final gesture = await tester.startGesture(
      Offset(box.center.dx, box.center.dy - 150),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    expect(player.speed, heldSpeed);
    expect(find.text('2×'), findsOneWidget);

    await gesture.up();
    await tester.pump();
    expect(player.speed, 1);
    expect(_indicator, findsNothing);
  });

  testWidgets('lock hides every control until unlocked', (tester) async {
    await open(tester);

    await _tap(tester, find.byKey(const Key('player-lock')));
    expect(find.text('Locked'), findsOneWidget);
    expect(find.byKey(const Key('player-play')), findsNothing);
    expect(find.byKey(const Key('player-unlock')), findsNothing);

    // A tap only offers the way out, and swipes do nothing.
    await tester.tapAt(tester.getRect(_video).center - const Offset(0, 200));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('player-unlock')), findsOneWidget);
    expect(find.byKey(const Key('player-play')), findsNothing);
    await tester.dragFrom(
      tester.getRect(_video).center - const Offset(100, 200),
      const Offset(200, 0),
    );
    await tester.pump();
    expect(player.seeks, isEmpty);

    await _tap(tester, find.byKey(const Key('player-unlock')));
    expect(find.byKey(const Key('player-play')), findsOneWidget);
  });

  testWidgets('cycles the picture size', (tester) async {
    await open(tester);
    BoxFit fit() => tester
        .widget<FittedBox>(
          find.ancestor(
            of: find.byKey(const Key('fake-video')),
            matching: find.byType(FittedBox),
          ),
        )
        .fit;

    expect(fit(), BoxFit.contain);
    await tester.tap(find.byKey(const Key('player-fit')));
    await tester.pump();
    expect(find.text('Crop to fill'), findsOneWidget);
    expect(fit(), BoxFit.cover);
    await _tap(tester, find.byKey(const Key('player-fit')));
    expect(fit(), BoxFit.fill);
    await _tap(tester, find.byKey(const Key('player-fit')));
    expect(fit(), BoxFit.contain);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('moves between files with the previous and next buttons', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('1 of 2'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('player-previous')))
          .onPressed,
      isNull,
    );

    // A sideways swipe scrubs; it does not change the file.
    await tester.dragFrom(
      tester.getRect(_video).center + const Offset(100, -200),
      const Offset(-250, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 of 2'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('player-next')));
    expect(find.text('2 of 2'), findsOneWidget);
    expect(find.text(_wide), findsOneWidget);
    expect(player.opened, hasLength(2));

    await _tap(tester, find.byKey(const Key('player-previous')));
    expect(find.text('1 of 2'), findsOneWidget);
  });

  testWidgets('carries on from where the video was stopped', (tester) async {
    app.positions.positions = {_tallKey: 60000};
    await open(tester);

    expect(player.seeks, [60]);
    expect(find.text('Carrying on from 1:00'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(_indicator, findsNothing);
  });

  testWidgets('remembers where a video is stopped', (tester) async {
    await open(tester);

    player.position = const Duration(seconds: 90);
    await tester.pump(const Duration(seconds: 1));
    await _tap(tester, find.byKey(const Key('player-play')));
    expect(app.positions.positions, {_tallKey: 90000});

    // Near the end counts as finished.
    await _tap(tester, find.byKey(const Key('player-play')));
    player.position = const Duration(minutes: 4, seconds: 57);
    await tester.pump(const Duration(seconds: 1));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(app.positions.positions, isEmpty);
  });

  testWidgets('the sleep timer pauses playback', (tester) async {
    await open(tester);

    await _tap(tester, find.byKey(const Key('player-more')));
    await _tap(tester, find.text('Sleep timer'));
    await tester.tap(find.byKey(const Key('sleep-15')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Pauses in 15 min'), findsOneWidget);
    expect(player.calls.last, isNot('pause'));

    await tester.pump(const Duration(minutes: 15, seconds: 1));
    expect(player.calls.last, 'pause');

    // The controls hid themselves meanwhile; a tap brings them back.
    await tester.tapAt(tester.getRect(_video).center - const Offset(0, 200));
    await tester.pump(const Duration(milliseconds: 400));
    await _tap(tester, find.byKey(const Key('player-more')));
    expect(find.text('Sleep timer'), findsOneWidget);
  });

  testWidgets('saves the current frame as a photo next to the video', (
    tester,
  ) async {
    player.position = const Duration(seconds: 75);
    await open(tester);
    await tester.pump(const Duration(seconds: 1));

    await _tap(tester, find.byKey(const Key('player-more')));
    await tester.tap(find.text('Save this frame as a photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    const photo = 'VID-20250101-WA0001 1m15s.jpg';
    expect(find.text('Saved $photo'), findsOneWidget);
    expect(app.storage.exists('$waMediaId/WhatsApp Video/$photo'), isTrue);

    await tester.pump(const Duration(seconds: 2));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text(photo), findsOneWidget);
  });

  testWidgets('says so when a frame cannot be saved', (tester) async {
    app.storage.failFrames.add(_tallId);
    await open(tester);

    await _tap(tester, find.byKey(const Key('player-more')));
    await tester.tap(find.text('Save this frame as a photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text("Couldn't save this frame"), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('repeat and mute carry over to the next video', (tester) async {
    await open(tester);

    await _tap(tester, find.byKey(const Key('player-more')));
    // The menu row takes the tap, not the words on it.
    await tester.tap(find.text('Repeat'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(player.looping, isTrue);
    await _tap(tester, find.byKey(const Key('player-mute')));
    expect(player.volume, 0);

    player
      ..looping = false
      ..volume = 1;
    await _tap(tester, find.byKey(const Key('player-next')));
    expect(player.looping, isTrue);
    expect(player.volume, 0);
  });

  testWidgets('a GIF plays silently in a loop and is not resumed', (
    tester,
  ) async {
    app.storage.addFile('WhatsApp Animated Gifs/VID-20261001-WA0003.mp4');
    app.positions.positions = {
      '$waTree|$waMediaId/WhatsApp Animated Gifs/VID-20261001-WA0003.mp4':
          60000,
    };
    await open(
      tester,
      folder: 'WhatsApp Animated Gifs',
      name: 'VID-20261001-WA0003.mp4',
    );

    expect(player.looping, isTrue);
    expect(player.volume, 0);
    expect(player.seeks, isEmpty);
  });

  testWidgets('plays a voice note, with its own controls', (tester) async {
    await open(tester, folder: 'WhatsApp Voice Notes', name: '202610');
    await _tap(tester, find.text('PTT-20261020-WA0002.opus'));

    expect(player.calls, contains('play'));
    // Sound alone does not keep the screen on.
    expect(app.storage.screenOn, isEmpty);
    expect(find.byKey(const Key('player-scrubber')), findsOneWidget);

    await _tap(tester, find.byTooltip('Forward 10 seconds'));
    expect(player.seeks.last, 10);
    await _tap(tester, find.byKey(const Key('player-play')));
    expect(player.calls.last, 'pause');
  });
}
