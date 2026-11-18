import 'package:flutter_test/flutter_test.dart';

import 'package:healthbook_test/utils/file_kind.dart';

void main() {
  group('fileKindFor', () {
    test('recognises PDFs, ignoring case', () {
      expect(fileKindFor('report.pdf'), FileKind.pdf);
      expect(fileKindFor('/storage/emulated/0/Download/Scan.PDF'), FileKind.pdf);
    });

    test('recognises common image types', () {
      expect(fileKindFor('xray.png'), FileKind.image);
      expect(fileKindFor('blood-test.JPG'), FileKind.image);
      expect(fileKindFor('photo.jpeg'), FileKind.image);
    });

    test('everything else is other', () {
      expect(fileKindFor('notes.docx'), FileKind.other);
      expect(fileKindFor('no_extension'), FileKind.other);
      expect(fileKindFor(''), FileKind.other);
    });

    test('a dot in a folder name is not an extension', () {
      expect(fileKindFor('/data/my.files/report'), FileKind.other);
    });
  });
}
