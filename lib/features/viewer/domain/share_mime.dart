/// The MIME type to announce when sharing several files at once.
abstract final class ShareMime {
  static const any = '*/*';

  /// The common type of [types]: the exact type when all files have the
  /// same one, `image/*` (and so on) when they only share the first part,
  /// and `*/*` otherwise or when a type is unknown.
  static String of(Iterable<String?> types) {
    String? exact;
    String? family;
    var first = true;
    for (final type in types) {
      if (type == null || !type.contains('/')) return any;
      final lower = type.toLowerCase();
      final top = lower.substring(0, lower.indexOf('/'));
      if (first) {
        exact = lower;
        family = top;
        first = false;
        continue;
      }
      if (lower != exact) exact = null;
      if (top != family) return any;
    }
    if (first) return any;
    return exact ?? '$family/*';
  }
}
