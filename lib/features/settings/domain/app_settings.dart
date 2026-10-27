import '../../media/domain/media_source.dart';

/// The user's choices, plus the folders they granted.
final class AppSettings {
  const AppSettings({
    this.sources = const [],
    this.trashDays = defaultTrashDays,
    this.oldAfterMonths = defaultOldAfterMonths,
    this.freedBytes = 0,
  });

  static const defaultTrashDays = 7;
  static const defaultOldAfterMonths = 6;
  static const trashDayChoices = [1, 3, 7, 14, 30];
  static const oldAfterMonthChoices = [3, 6, 12, 24];

  final List<MediaSource> sources;

  /// How long files stay in the trash before they are deleted for good.
  final int trashDays;

  /// Received media older than this counts as an old forward or meme.
  final int oldAfterMonths;

  /// Space freed by this app so far, in bytes.
  final int freedBytes;

  Duration get retention => Duration(days: trashDays);

  AppSettings copyWith({
    List<MediaSource>? sources,
    int? trashDays,
    int? oldAfterMonths,
    int? freedBytes,
  }) => AppSettings(
    sources: sources ?? this.sources,
    trashDays: trashDays ?? this.trashDays,
    oldAfterMonths: oldAfterMonths ?? this.oldAfterMonths,
    freedBytes: freedBytes ?? this.freedBytes,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      _sameSources(other.sources, sources) &&
      other.trashDays == trashDays &&
      other.oldAfterMonths == oldAfterMonths &&
      other.freedBytes == freedBytes;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(sources),
    trashDays,
    oldAfterMonths,
    freedBytes,
  );

  static bool _sameSources(List<MediaSource> a, List<MediaSource> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

abstract interface class SettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}
