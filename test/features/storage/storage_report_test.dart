import 'package:chat_media_cleaner/features/media/domain/duplicate_finder.dart';
import 'package:chat_media_cleaner/features/media/domain/media_file.dart';
import 'package:chat_media_cleaner/features/media/domain/media_type.dart';
import 'package:chat_media_cleaner/features/storage/domain/file_category.dart';
import 'package:chat_media_cleaner/features/storage/domain/storage_report.dart';
import 'package:flutter_test/flutter_test.dart';

const _mb = 1000 * 1000;

MediaFile _file(String path, int size, {int year = 2026}) => MediaFile(
  id: '/v/$path',
  sourceId: 'file:///v',
  parentId: '/v',
  name: path.split('/').last,
  relativePath: path,
  size: size,
  modified: DateTime.utc(year),
  type: MediaType.other,
);

void main() {
  final movie = _file('Movies/film.mkv', 900 * _mb);
  final photo = _file('DCIM/a.jpg', 3 * _mb);
  final copy = _file('Download/a.jpg', 3 * _mb, year: 2027);
  final apk = _file('Download/app.apk', 40 * _mb);
  final trashed = _file('.media-cleaner-trash/x/old.mp4', 500 * _mb);
  final chatTrash = _file(
    'Android/media/com.whatsapp/WhatsApp/Media/.media-cleaner-trash/x/v.mp4',
    200 * _mb,
  );

  test('adds up space by kind of file, leaving out the app trash', () {
    final report = StorageReport.from([
      movie,
      photo,
      copy,
      apk,
      trashed,
      chatTrash,
    ]);
    expect(report.files, hasLength(4));
    expect(report.totalBytes, 946 * _mb);
    expect(report.usage[FileCategory.videos]!.bytes, 900 * _mb);
    expect(report.usage[FileCategory.images]!.count, 2);
    expect(report.usage[FileCategory.apps]!.bytes, 40 * _mb);
    expect(report.usage[FileCategory.audio]!.count, 0);
    expect(report.ofCategory(FileCategory.images), [photo, copy]);
  });

  test('lists files of 10 MB or more, biggest first', () {
    final report = StorageReport.from([photo, apk, movie]);
    expect(report.largest, [movie, apk]);
  });

  test('keeps the oldest of each duplicate set and drops trashed ones', () {
    final report = StorageReport.from(
      [movie, photo, copy],
      duplicates: [
        DuplicateSet([copy, photo]),
      ],
    );
    expect(report.duplicateCopies, [copy]);
    expect(report.duplicateBytes, 3 * _mb);

    final after = report.without({copy.key});
    expect(after.duplicates, isEmpty);
    expect(after.files, [movie, photo]);
  });
}
