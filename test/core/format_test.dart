import 'package:chat_media_cleaner/core/format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  test('formatBytes uses 1000-based units like Android settings', () {
    expect(formatBytes(0, 'en'), '0 B');
    expect(formatBytes(999, 'en'), '999 B');
    expect(formatBytes(1000, 'en'), '1 KB');
    expect(formatBytes(1500, 'en'), '1.5 KB');
    expect(formatBytes(60 * 1000 * 1000, 'en'), '60 MB');
    expect(formatBytes(65490000, 'en'), '65.5 MB');
    expect(formatBytes(123456789, 'en'), '123 MB');
    expect(formatBytes(4200000000, 'en'), '4.2 GB');
    expect(formatBytes(5 * 1000 * 1000 * 1000 * 1000 * 1000, 'en'), '5,000 TB');
  });

  test('formatBytes follows the locale', () {
    expect(formatBytes(1500000, 'de'), '1,5 MB');
  });

  test('formatCount groups digits', () {
    expect(formatCount(12345, 'en'), '12,345');
  });

  test('formatDate shows a short local date', () {
    expect(formatDate(DateTime(2024, 3, 5, 12), 'en'), 'Mar 5, 2024');
  });
}
