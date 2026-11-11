import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../media/domain/media_storage.dart';
import '../../review/presentation/review_controller.dart';

/// A sharper picture than the grid thumbnail, for files too large to load
/// whole and for the frame shown while a video gets ready.
final posterProvider = FutureProvider.autoDispose.family<Uint8List?, FileRef>(
  (ref, file) => ref
      .watch(mediaViewerProvider)
      .thumbnail(file.treeUri, file.fileId, size: posterSize),
);

const posterSize = 1024;

final mediaInfoProvider = FutureProvider.autoDispose.family<MediaInfo, FileRef>(
  (ref, file) =>
      ref.watch(mediaViewerProvider).mediaInfo(file.treeUri, file.fileId),
);

final pdfPageCountProvider = FutureProvider.autoDispose.family<int, FileRef>(
  (ref, file) =>
      ref.watch(mediaViewerProvider).pdfPageCount(file.treeUri, file.fileId),
);

typedef PdfPageRef = ({FileRef file, int index, int width});

final pdfPageProvider = FutureProvider.autoDispose
    .family<PdfPageImage, PdfPageRef>(
      (ref, page) => ref
          .watch(mediaViewerProvider)
          .pdfPage(
            page.file.treeUri,
            page.file.fileId,
            page.index,
            width: page.width,
          ),
    );

/// How much of a text file is read and shown.
const textPreviewBytes = 256 * 1024;

/// The beginning of a text file. Bytes that are not valid UTF-8 are shown
/// as replacement characters rather than failing the whole file.
final textPreviewProvider = FutureProvider.autoDispose.family<String, FileRef>((
  ref,
  file,
) async {
  final bytes = await ref
      .watch(mediaViewerProvider)
      .readBytes(
        file.treeUri,
        file.fileId,
        maxBytes: textPreviewBytes,
        truncate: true,
      );
  return utf8.decode(bytes, allowMalformed: true);
});
