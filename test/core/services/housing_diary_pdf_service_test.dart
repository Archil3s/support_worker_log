import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:support_worker_log/core/services/housing_diary_pdf_service.dart';

void main() {
  test('buildCaseworkDocx writes casework sections', () {
    final bytes = HousingDiaryPdfService.buildCaseworkDocx(
      caseCode: 'CASE-001',
      worker: 'DW',
      sections: const [
        CaseworkDocxSection(
          title: 'If client is not currently on a benefit',
          lines: [
            '[x] Photo ID checked',
            '[ ] Recent bank statements available if MSD asks',
          ],
        ),
        CaseworkDocxSection(
          title: 'Live note output',
          lines: ['MSD call support note', 'No safe place tonight'],
        ),
      ],
    );

    final text = _docxText(bytes);

    expect(text, contains('CASEWORK FILE'));
    expect(text, contains('Case code: CASE-001'));
    expect(text, contains('If client is not currently on a benefit'));
    expect(text, contains('[x] Photo ID checked'));
    expect(text, contains('MSD call support note'));
  });
}

String _docxText(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final file = archive.files.firstWhere(
    (item) => item.name == 'word/document.xml',
  );
  final xml = utf8.decode(file.content as List<int>);
  return xml.replaceAll(RegExp(r'<[^>]+>'), ' ');
}
