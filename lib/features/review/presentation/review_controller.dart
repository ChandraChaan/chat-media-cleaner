import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../home/presentation/scan_controller.dart';
import '../../media/domain/media_file.dart';
import '../../media/domain/media_report.dart';
import '../../media/domain/media_type.dart';

/// What a review screen shows: a smart group or every file of one type.
sealed class ReviewTarget {
  const ReviewTarget();

  /// Stable id, used to keep a selection per screen.
  String get id;

  SortOrder get defaultOrder;

  @override
  bool operator ==(Object other) =>
      other is ReviewTarget &&
      other.runtimeType == runtimeType &&
      other.id == id;

  @override
  int get hashCode => id.hashCode;
}

final class GroupReview extends ReviewTarget {
  const GroupReview(this.group);

  final SmartGroup group;

  @override
  String get id => 'group:${group.name}';

  @override
  SortOrder get defaultOrder => switch (group) {
    SmartGroup.oldForwards => SortOrder.oldest,
    SmartGroup.largest || SmartGroup.sentCopies => SortOrder.largest,
  };
}

final class TypeReview extends ReviewTarget {
  const TypeReview(this.type);

  final MediaType type;

  @override
  String get id => 'type:${type.name}';

  @override
  SortOrder get defaultOrder => SortOrder.largest;
}

enum SortOrder { largest, oldest, newest }

final sortOrderProvider = NotifierProvider.autoDispose
    .family<SortOrderController, SortOrder, ReviewTarget>(
      SortOrderController.new,
    );

final class SortOrderController extends Notifier<SortOrder> {
  SortOrderController(this.target);

  final ReviewTarget target;

  @override
  SortOrder build() => target.defaultOrder;

  void set(SortOrder order) => state = order;
}

/// The files a review screen shows, in the chosen order.
final reviewFilesProvider = Provider.autoDispose
    .family<List<MediaFile>, ReviewTarget>((ref, target) {
      final report = ref.watch(mediaReportProvider);
      if (report == null) return const [];
      final files = switch (target) {
        GroupReview(:final group) => report.group(group).files,
        TypeReview(:final type) => report.ofType(type).files,
      };
      final order = ref.watch(sortOrderProvider(target));
      return [...files]..sort(switch (order) {
        SortOrder.largest => (a, b) => b.size.compareTo(a.size),
        SortOrder.oldest => (a, b) => a.modified.compareTo(b.modified),
        SortOrder.newest => (a, b) => b.modified.compareTo(a.modified),
      });
    });

final selectionProvider = NotifierProvider.autoDispose
    .family<SelectionController, Set<String>, ReviewTarget>(
      SelectionController.new,
    );

/// The keys of the files the user selected on one review screen. Nothing is
/// ever selected without the user doing it.
final class SelectionController extends Notifier<Set<String>> {
  SelectionController(this.target);

  final ReviewTarget target;

  @override
  Set<String> build() {
    // Forget files that left the list (moved to the trash elsewhere).
    ref.listen(reviewFilesProvider(target), (_, files) {
      final present = {for (final f in files) f.key};
      if (!present.containsAll(state)) {
        state = state.intersection(present);
      }
    });
    return const {};
  }

  void toggle(MediaFile file) => state = state.contains(file.key)
      ? ({...state}..remove(file.key))
      : {...state, file.key};

  void selectAll(List<MediaFile> files) =>
      state = {for (final f in files) f.key};

  void clear() => state = const {};
}

/// The selected files of a review screen, in list order.
final selectedFilesProvider = Provider.autoDispose
    .family<List<MediaFile>, ReviewTarget>((ref, target) {
      final selected = ref.watch(selectionProvider(target));
      return [
        for (final f in ref.watch(reviewFilesProvider(target)))
          if (selected.contains(f.key)) f,
      ];
    });

typedef FileRef = ({String treeUri, String fileId});

final thumbnailProvider = FutureProvider.autoDispose
    .family<Uint8List?, FileRef>(
      (ref, file) =>
          ref.watch(mediaViewerProvider).thumbnail(file.treeUri, file.fileId),
    );

final previewBytesProvider = FutureProvider.autoDispose
    .family<Uint8List, FileRef>(
      (ref, file) =>
          ref.watch(mediaViewerProvider).readBytes(file.treeUri, file.fileId),
    );

extension MediaFileRef on MediaFile {
  FileRef get ref => (treeUri: sourceId, fileId: id);
}
