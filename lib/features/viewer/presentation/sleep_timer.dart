import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The sleep timer: [minutes] is what it was set to (null when off), and
/// [fired] counts how often it has run out, for players to listen to.
final class SleepTimerState {
  const SleepTimerState({this.minutes, this.fired = 0});

  final int? minutes;
  final int fired;
}

const sleepTimerChoices = [15, 30, 45, 60];

final sleepTimerProvider =
    NotifierProvider<SleepTimerController, SleepTimerState>(
      SleepTimerController.new,
    );

/// Pauses whatever is playing after a while, for falling asleep to a video.
final class SleepTimerController extends Notifier<SleepTimerState> {
  Timer? _timer;

  @override
  SleepTimerState build() {
    ref.onDispose(() => _timer?.cancel());
    return const SleepTimerState();
  }

  /// Starts the timer over at [minutes], or turns it off with null.
  void set(int? minutes) {
    _timer?.cancel();
    _timer = minutes == null
        ? null
        : Timer(Duration(minutes: minutes), () {
            state = SleepTimerState(fired: state.fired + 1);
          });
    state = SleepTimerState(minutes: minutes, fired: state.fired);
  }
}
