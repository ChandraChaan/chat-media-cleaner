/// Lets the user stop a long scan. Work checks it between steps.
final class CancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  /// Throws [ScanCancelled] once [cancel] was called.
  void throwIfCancelled() {
    if (_cancelled) throw const ScanCancelled();
  }
}

final class ScanCancelled implements Exception {
  const ScanCancelled();
}
