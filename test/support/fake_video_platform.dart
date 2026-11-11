import 'dart:async';

import 'package:flutter/material.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// A video player that opens anything at once and records what it is told.
class FakeVideoPlatform extends VideoPlayerPlatform
    with MockPlatformInterfaceMixin {
  final calls = <String>[];
  final opened = <String>[];
  final _events = <int, StreamController<VideoEvent>>{};
  int _next = 0;

  Duration position = Duration.zero;
  Duration duration = const Duration(minutes: 5);
  Size size = const Size(1920, 1080);
  bool looping = false;

  /// What stands in for the video picture.
  Widget view = const SizedBox.expand(key: Key('fake-video'));
  double volume = 1;
  double speed = 1;

  /// The seeks so far, in seconds.
  List<int> get seeks => [
    for (final call in calls)
      if (call.startsWith('seek ')) int.parse(call.substring(5)),
  ];

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = _next++;
    opened.add(options.dataSource.uri ?? '');
    _events[id] = StreamController<VideoEvent>()
      ..add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: duration,
          size: size,
        ),
      );
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async {
    calls.add('dispose');
    await _events.remove(playerId)?.close();
  }

  @override
  Future<void> play(int playerId) async => calls.add('play');

  @override
  Future<void> pause(int playerId) async => calls.add('pause');

  @override
  Future<void> setLooping(int playerId, bool looping) async =>
      this.looping = looping;

  @override
  Future<void> setVolume(int playerId, double volume) async =>
      this.volume = volume;

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {
    calls.add('speed $speed');
    this.speed = speed;
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    calls.add('seek ${position.inSeconds}');
    this.position = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async => position;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => view;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}
