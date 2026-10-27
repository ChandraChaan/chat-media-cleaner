import 'duplicate_finder.dart';
import 'media_file.dart';
import 'media_type.dart';

/// The ready-made groups offered for review on the home screen.
enum SmartGroup {
  /// The biggest files, largest first.
  largest,

  /// Extra copies of identical files; the oldest copy of each is kept and
  /// never listed.
  duplicates,

  /// Received photos, GIFs and short videos older than the age rule: mostly
  /// forwards and memes that are no longer of interest.
  oldForwards,

  /// Copies of media you sent; the originals usually stay in your gallery.
  sentCopies,
}

/// Thresholds for the smart groups. The age rule is a user setting.
final class AnalysisRules {
  const AnalysisRules({
    this.oldAfterMonths = 6,
    this.largestCount = 100,
    this.largestMinBytes = 1024 * 1024,
    this.oldMaxVideoBytes = 16 * 1024 * 1024,
  });

  /// Received media older than this many months counts as old.
  final int oldAfterMonths;

  /// How many files the largest-files group shows at most.
  final int largestCount;

  /// Files smaller than this never appear in the largest-files group.
  final int largestMinBytes;

  /// Videos bigger than this are not treated as forwards or memes: they are
  /// more likely to be something personal.
  final int oldMaxVideoBytes;

  AnalysisRules copyWith({int? oldAfterMonths}) => AnalysisRules(
    oldAfterMonths: oldAfterMonths ?? this.oldAfterMonths,
    largestCount: largestCount,
    largestMinBytes: largestMinBytes,
    oldMaxVideoBytes: oldMaxVideoBytes,
  );
}

/// A list of files with their combined size.
final class FileGroup {
  FileGroup(this.files) : bytes = files.fold(0, (sum, f) => sum + f.size);

  static final empty = FileGroup(const []);

  final List<MediaFile> files;
  final int bytes;

  int get count => files.length;
  bool get isEmpty => files.isEmpty;
}

/// Totals by type and the smart groups, computed from a scan.
final class MediaReport {
  const MediaReport({
    required this.files,
    required this.byType,
    required this.groups,
    this.duplicateSets = const [],
  });

  final List<MediaFile> files;

  /// Every type with at least one file, each sorted largest first.
  final Map<MediaType, FileGroup> byType;
  final Map<SmartGroup, FileGroup> groups;

  /// Identical files, limited to those still present.
  final List<DuplicateSet> duplicateSets;

  int get totalBytes => files.fold(0, (sum, f) => sum + f.size);
  int get totalCount => files.length;

  FileGroup group(SmartGroup group) => groups[group] ?? FileGroup.empty;
  FileGroup ofType(MediaType type) => byType[type] ?? FileGroup.empty;
}

abstract final class MediaAnalyzer {
  /// [duplicates] come from [DuplicateFinder]; sets are re-checked against
  /// [files], so files moved to the trash since drop out and a set always
  /// keeps one copy.
  static MediaReport analyze(
    List<MediaFile> files, {
    required AnalysisRules rules,
    required DateTime now,
    List<DuplicateSet> duplicates = const [],
  }) {
    final bySizeDesc = [...files]..sort(_largestFirst);

    final byType = <MediaType, List<MediaFile>>{};
    for (final file in bySizeDesc) {
      (byType[file.type] ??= []).add(file);
    }

    final largest = bySizeDesc
        .where((f) => f.size >= rules.largestMinBytes)
        .take(rules.largestCount)
        .toList();

    final cutoff = monthsBefore(now, rules.oldAfterMonths);
    final old = files.where((f) => _isOldForward(f, rules, cutoff)).toList()
      ..sort(_oldestFirst);

    final sent = bySizeDesc.where((f) => f.isSent).toList();

    final present = {for (final f in files) f.key: f};
    final sets = [for (final set in duplicates) ?set.within(present)];
    final copies = [for (final set in sets) ...set.copies]..sort(_largestFirst);

    return MediaReport(
      files: List.unmodifiable(files),
      byType: {
        for (final type in MediaType.values)
          if (byType[type] case final list?) type: FileGroup(list),
      },
      groups: {
        SmartGroup.largest: FileGroup(largest),
        SmartGroup.duplicates: FileGroup(copies),
        SmartGroup.oldForwards: FileGroup(old),
        SmartGroup.sentCopies: FileGroup(sent),
      },
      duplicateSets: sets,
    );
  }

  static bool _isOldForward(MediaFile f, AnalysisRules rules, DateTime cutoff) {
    if (f.isSent || !f.modified.isBefore(cutoff)) return false;
    return switch (f.type) {
      MediaType.image || MediaType.gif => true,
      MediaType.video => f.size <= rules.oldMaxVideoBytes,
      _ => false,
    };
  }

  static int _largestFirst(MediaFile a, MediaFile b) {
    final bySize = b.size.compareTo(a.size);
    return bySize != 0 ? bySize : a.relativePath.compareTo(b.relativePath);
  }

  static int _oldestFirst(MediaFile a, MediaFile b) {
    final byDate = a.modified.compareTo(b.modified);
    return byDate != 0 ? byDate : a.relativePath.compareTo(b.relativePath);
  }
}

/// [now] minus [months] calendar months, in UTC. The day is clamped to the
/// last day of the target month (31 March minus one month is 28 or 29
/// February).
DateTime monthsBefore(DateTime now, int months) {
  final utc = now.toUtc();
  final totalMonths = utc.year * 12 + (utc.month - 1) - months;
  final year = totalMonths ~/ 12;
  final month = totalMonths % 12 + 1;
  final lastDay = DateTime.utc(year, month + 1, 0).day;
  return DateTime.utc(
    year,
    month,
    utc.day > lastDay ? lastDay : utc.day,
    utc.hour,
    utc.minute,
    utc.second,
    utc.millisecond,
  );
}
