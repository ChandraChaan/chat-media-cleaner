import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/trash_entry.dart';
import '../domain/trash_repository.dart';

/// Keeps the trash index as a JSON file in app-private storage.
final class FileTrashIndexStore implements TrashIndexStore {
  FileTrashIndexStore([Future<Directory> Function()? directory])
    : _directory = directory ?? getApplicationSupportDirectory;

  static const _fileName = 'trash_index.json';

  final Future<Directory> Function() _directory;

  @override
  Future<List<TrashEntry>> load() async {
    final file = await _file();
    if (!file.existsSync()) return [];
    final json = jsonDecode(await file.readAsString()) as List<Object?>;
    return [
      for (final item in json)
        TrashEntry.fromJson(item! as Map<String, Object?>),
    ];
  }

  @override
  Future<void> save(List<TrashEntry> entries) async {
    final file = await _file();
    // Write a temporary file and rename it, so a crash never leaves a
    // half-written index behind.
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode([for (final e in entries) e.toJson()]),
      flush: true,
    );
    await temp.rename(file.path);
  }

  Future<File> _file() async => File('${(await _directory()).path}/$_fileName');
}
