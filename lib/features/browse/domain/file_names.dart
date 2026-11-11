/// Why a new file name was turned down.
enum NameProblem {
  empty,

  /// It has a `/` or another character Android file names cannot hold.
  badCharacter,

  /// `.` and `..` mean "this folder" and "the folder above".
  reserved,
  tooLong,
}

/// Rules for the names a user types when renaming a file.
abstract final class FileNames {
  /// Android's limit is 255 bytes; names are measured in UTF-8.
  static const maxBytes = 255;

  static final _forbidden = RegExp(r'[/\\:*?"<>|\x00-\x1f]');

  /// The name as it will be used: without spaces at either end.
  static String clean(String input) => input.trim();

  /// What is wrong with [input], or null when it can be used.
  static NameProblem? check(String input) {
    final name = clean(input);
    if (name.isEmpty) return NameProblem.empty;
    if (name == '.' || name == '..') return NameProblem.reserved;
    if (_forbidden.hasMatch(name)) return NameProblem.badCharacter;
    if (_utf8Length(name) > maxBytes) return NameProblem.tooLong;
    return null;
  }

  /// The part of [name] before its extension, which is what a user usually
  /// wants to change. `photo.jpg` gives 5; names without one give their
  /// whole length.
  static int stemLength(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? dot : name.length;
  }

  static int _utf8Length(String s) {
    var bytes = 0;
    for (final rune in s.runes) {
      bytes += rune < 0x80
          ? 1
          : rune < 0x800
          ? 2
          : rune < 0x10000
          ? 3
          : 4;
    }
    return bytes;
  }
}
