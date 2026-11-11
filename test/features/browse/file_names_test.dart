import 'package:chat_media_cleaner/features/browse/domain/file_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FileNames.check', () {
    test('accepts ordinary names', () {
      expect(FileNames.check('Holiday 2024.jpg'), isNull);
      expect(FileNames.check('  padded.pdf  '), isNull);
      expect(FileNames.check('.hidden'), isNull);
      expect(FileNames.check('వీడియో.mp4'), isNull);
    });

    test('rejects an empty name', () {
      expect(FileNames.check(''), NameProblem.empty);
      expect(FileNames.check('   '), NameProblem.empty);
    });

    test('rejects characters Android file names cannot hold', () {
      for (final bad in [
        'a/b.jpg',
        r'a\b',
        'a:b',
        'a*b',
        'a?b',
        'a"b',
        'a|b',
      ]) {
        expect(FileNames.check(bad), NameProblem.badCharacter, reason: bad);
      }
      expect(FileNames.check('line\nbreak'), NameProblem.badCharacter);
    });

    test('rejects the names that mean a folder', () {
      expect(FileNames.check('.'), NameProblem.reserved);
      expect(FileNames.check('..'), NameProblem.reserved);
    });

    test('measures the length in bytes, as the file system does', () {
      expect(FileNames.check('a' * 255), isNull);
      expect(FileNames.check('a' * 256), NameProblem.tooLong);
      // Each Telugu letter takes three bytes.
      expect(FileNames.check('వ' * 85), isNull);
      expect(FileNames.check('వ' * 86), NameProblem.tooLong);
    });
  });

  test('clean trims the ends only', () {
    expect(FileNames.clean('  my file.txt '), 'my file.txt');
  });

  test('stemLength stops before the extension', () {
    expect(FileNames.stemLength('photo.jpg'), 5);
    expect(FileNames.stemLength('archive.tar.gz'), 11);
    expect(FileNames.stemLength('README'), 6);
    expect(FileNames.stemLength('.hidden'), 7);
  });
}
