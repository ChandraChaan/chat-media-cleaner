/// Saves and loads where videos were stopped: file key to milliseconds.
abstract interface class PlaybackPositionStore {
  Future<Map<String, int>> load();
  Future<void> save(Map<String, int> positions);
}

/// Remembers where each video was stopped, so it can carry on from there.
final class PlaybackPositions {
  PlaybackPositions(this._store);

  /// A video stopped in its first seconds starts from the beginning.
  static const minPosition = Duration(seconds: 5);

  /// A video stopped this close to its end counts as finished.
  static const endMargin = Duration(seconds: 8);

  /// The oldest positions are forgotten beyond this many videos.
  static const maxEntries = 200;

  final PlaybackPositionStore _store;
  Map<String, int>? _positions;

  /// Where to carry on [key] from, or null to start at the beginning.
  Future<Duration?> resumeAt(String key, {required Duration duration}) async {
    final millis = (await _load())[key];
    if (millis == null) return null;
    final position = Duration(milliseconds: millis);
    return worthResuming(position, duration) ? position : null;
  }

  /// Notes that [key] was stopped at [position], or forgets it when that is
  /// too close to either end to be worth coming back to.
  Future<void> remember(
    String key, {
    required Duration position,
    required Duration duration,
  }) async {
    final positions = await _load();
    final had = positions.remove(key);
    if (worthResuming(position, duration)) {
      // Added last, so the map stays ordered oldest first.
      positions[key] = position.inMilliseconds;
      while (positions.length > maxEntries) {
        positions.remove(positions.keys.first);
      }
    } else if (had == null) {
      return;
    }
    await _store.save(positions);
  }

  static bool worthResuming(Duration position, Duration duration) =>
      duration > Duration.zero &&
      position >= minPosition &&
      duration - position >= endMargin;

  Future<Map<String, int>> _load() async =>
      _positions ??= {...await _store.load()};
}
