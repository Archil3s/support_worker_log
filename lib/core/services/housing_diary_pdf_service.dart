import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class HousingDiaryPropertyEntry {
  const HousingDiaryPropertyEntry({
    required this.area,
    required this.date,
    required this.address,
    required this.details,
    required this.landlordAndPhone,
    required this.outcome,
    required this.link,
  });

  final String area;
  final String date;
  final String address;
  final String details;
  final String landlordAndPhone;
  final String outcome;
  final String link;
}

class HousingDiaryActionEntry {
  const HousingDiaryActionEntry({
    required this.date,
    required this.action,
    required this.outcome,
  });

  final String date;
  final String action;
  final String outcome;
}

class LeadSearchPdfEntry {
  const LeadSearchPdfEntry({
    required this.title,
    required this.subtitle,
    this.category = '',
    required this.tags,
    required this.contact,
    required this.source,
    required this.notes,
  });

  final String title;
  final String subtitle;
  final String category;
  final List<String> tags;
  final String contact;
  final String source;
  final String notes;
}

class HousingDiaryPdfService {
  const HousingDiaryPdfService._();

  static Future<void> exportHousingDiary({
    required String caseCode,
    required String worker,
    required List<HousingDiaryPropertyEntry> properties,
    required List<HousingDiaryActionEntry> actions,
  }) async {
    final bytes = await buildHousingDiaryPdf(
      caseCode: caseCode,
      worker: worker,
      properties: properties,
      actions: actions,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Housing Diary $caseCode.pdf',
    );
  }

  static Future<void> exportLeadSearchPdf({
    required String title,
    required String caseCode,
    required String worker,
    required String filterSummary,
    required List<LeadSearchPdfEntry> entries,
  }) async {
    final bytes = await buildLeadSearchPdf(
      title: title,
      caseCode: caseCode,
      worker: worker,
      filterSummary: filterSummary,
      entries: entries,
    );
    final fileTitle = title.replaceAll(RegExp(r'[^A-Za-z0-9 ]+'), '').trim();

    await Printing.sharePdf(bytes: bytes, filename: '$fileTitle $caseCode.pdf');
  }

  static Future<void> exportHousingDiaryDocx({
    required String caseCode,
    required String worker,
    required List<HousingDiaryPropertyEntry> properties,
    required List<HousingDiaryActionEntry> actions,
  }) async {
    final bytes = Uint8List.fromList(
      buildHousingDiaryDocx(
        caseCode: caseCode,
        worker: worker,
        properties: properties,
        actions: actions,
      ),
    );

    await FileSaver.instance.saveFile(
      name: 'Housing Diary $caseCode',
      bytes: bytes,
      fileExtension: 'docx',
      mimeType: MimeType.microsoftWord,
    );
  }

  static List<int> buildHousingDiaryDocx({
    required String caseCode,
    required String worker,
    required List<HousingDiaryPropertyEntry> properties,
    required List<HousingDiaryActionEntry> actions,
  }) {
    final archive = Archive();

    void addTextFile(String name, String contents) {
      final bytes = utf8.encode(contents);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    addTextFile('[Content_Types].xml', _contentTypesXml);
    addTextFile('_rels/.rels', _rootRelationshipsXml);
    addTextFile('docProps/app.xml', _appPropertiesXml);
    addTextFile('docProps/core.xml', _corePropertiesXml(caseCode));
    addTextFile(
      'word/document.xml',
      _documentXml(
        caseCode: caseCode,
        worker: worker,
        properties: properties,
        actions: actions,
      ),
    );

    return ZipEncoder().encode(archive) ?? <int>[];
  }

  static Future<Uint8List> buildHousingDiaryPdf({
    required String caseCode,
    required String worker,
    required List<HousingDiaryPropertyEntry> properties,
    required List<HousingDiaryActionEntry> actions,
  }) async {
    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(42, 42, 42, 34),
        build: (context) {
          return [
            _templateHeader(caseCode: caseCode, worker: worker),
            pw.SizedBox(height: 18),
            _templateSectionTitle('PROPERTIES I HAVE APPLIED FOR:'),
            pw.SizedBox(height: 14),
            ..._propertyBlocks(properties),
          ];
        },
      ),
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(42, 42, 42, 34),
        build: (context) {
          return [
            pw.SizedBox(height: 34),
            _templateSectionTitle('OTHER THINGS I HAVE DONE THIS WEEK:'),
            pw.SizedBox(height: 14),
            ..._actionBlocks(actions),
          ];
        },
      ),
    );

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(42, 42, 42, 34),
        build: (context) => pw.SizedBox.expand(),
      ),
    );

    return document.save();
  }

  static Future<Uint8List> buildLeadSearchPdf({
    required String title,
    required String caseCode,
    required String worker,
    required String filterSummary,
    required List<LeadSearchPdfEntry> entries,
  }) async {
    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(34, 34, 34, 34),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (context) {
          return [
            _leadSearchHeader(
              title: title,
              caseCode: caseCode,
              worker: worker,
              filterSummary: filterSummary,
              count: entries.length,
            ),
            pw.SizedBox(height: 18),
            if (entries.isEmpty)
              _emptyLeadSearchBlock()
            else
              ..._leadSearchBlocks(entries),
          ];
        },
      ),
    );

    return document.save();
  }

  static pw.Widget _leadSearchHeader({
    required String title,
    required String caseCode,
    required String worker,
    required String filterSummary,
    required int count,
  }) {
    final workerText = worker.trim().isEmpty ? '-' : worker.trim();

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey900,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Case code: $caseCode    Worker: $workerText',
            style: const pw.TextStyle(color: PdfColors.grey200, fontSize: 10),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              _leadSummaryPill('Listings', '$count'),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _leadSummaryPill('Filters', filterSummary)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _leadSummaryPill(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(
                color: PdfColors.blueGrey700,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.TextSpan(
              text: value,
              style: const pw.TextStyle(
                color: PdfColors.blueGrey900,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _emptyLeadSearchBlock() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
        borderRadius: pw.BorderRadius.circular(7),
      ),
      child: pw.Text(
        'No saved listings matched the selected filters.',
        style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 11),
      ),
    );
  }

  static List<pw.Widget> _leadSearchBlocks(List<LeadSearchPdfEntry> entries) {
    final grouped = entries.any((entry) => entry.category.trim().isNotEmpty);
    if (!grouped) return [for (final entry in entries) _leadSearchCard(entry)];

    final categories = <String>[];
    final byCategory = <String, List<LeadSearchPdfEntry>>{};
    for (final entry in entries) {
      final category = entry.category.trim().isEmpty
          ? 'Other'
          : entry.category.trim();
      byCategory
          .putIfAbsent(category, () {
            categories.add(category);
            return <LeadSearchPdfEntry>[];
          })
          .add(entry);
    }

    return [
      for (final category in categories) ...[
        _leadCategoryTitle(category, byCategory[category]!.length),
        pw.SizedBox(height: 8),
        for (final entry in byCategory[category]!) _leadSearchCard(entry),
        pw.SizedBox(height: 6),
      ],
    ];
  }

  static pw.Widget _leadCategoryTitle(String category, int count) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey100,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Text(
        '$category ($count)',
        style: pw.TextStyle(
          color: PdfColors.blueGrey900,
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _leadSearchCard(LeadSearchPdfEntry entry) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
        borderRadius: pw.BorderRadius.circular(7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            _pdfText(entry.title),
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          if (entry.subtitle.trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              _pdfText(entry.subtitle),
              style: const pw.TextStyle(
                color: PdfColors.blueGrey700,
                fontSize: 10,
              ),
            ),
          ],
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [for (final tag in entry.tags) _leadTag(_pdfText(tag))],
          ),
          if (entry.contact.trim().isNotEmpty) ...[
            pw.SizedBox(height: 7),
            _leadLine('Contact', _pdfText(entry.contact)),
          ],
          if (entry.source.trim().isNotEmpty) ...[
            pw.SizedBox(height: 6),
            _leadLink('Source', entry.source),
          ],
          if (entry.notes.trim().isNotEmpty) ...[
            pw.SizedBox(height: 7),
            _leadLine('Notes', _pdfText(entry.notes)),
          ],
        ],
      ),
    );
  }

  static pw.Widget _leadTag(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(_pdfText(text), style: const pw.TextStyle(fontSize: 8)),
    );
  }

  static pw.Widget _leadLine(String label, String value) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label: ',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.TextSpan(
            text: value,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
          ),
        ],
      ),
    );
  }

  static pw.Widget _leadLink(String label, String url) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label: ',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.WidgetSpan(
            child: pw.UrlLink(
              destination: url,
              child: pw.Text(
                _pdfText(url),
                style: const pw.TextStyle(
                  color: PdfColors.blue700,
                  decoration: pw.TextDecoration.underline,
                  fontSize: 8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _pdfText(String value) {
    return value
        .replaceAll('\u00a0', ' ')
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'")
        .replaceAll('\u201c', '"')
        .replaceAll('\u201d', '"')
        .replaceAll('\u2013', '-')
        .replaceAll('\u2014', '-')
        .replaceAll('\u2022', '-')
        .replaceAll('\u00d7', 'x')
        .replaceAll(RegExp(r'[^\x09\x0A\x0D\x20-\x7E]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static pw.Widget _templateHeader({
    required String caseCode,
    required String worker,
  }) {
    final workerText = worker.trim().isEmpty ? '-' : worker.trim();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Center(
          child: pw.Text(
            'HOUSING DIARY',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Case code: $caseCode    Worker: $workerText',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
      ],
    );
  }

  static pw.Widget _templateSectionTitle(String text) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.only(bottom: 3),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black, width: 0.7),
        ),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static List<pw.Widget> _propertyBlocks(
    List<HousingDiaryPropertyEntry> entries,
  ) {
    final rows = entries.isEmpty
        ? <HousingDiaryPropertyEntry>[
            HousingDiaryPropertyEntry(
              area: '',
              date: '',
              address: '',
              details: '',
              landlordAndPhone: '',
              outcome: '',
              link: '',
            ),
          ]
        : entries;
    final blanksNeeded = rows.length >= 7 ? 0 : 7 - rows.length;
    final allRows = [
      ...rows,
      for (var index = 0; index < blanksNeeded; index++)
        const HousingDiaryPropertyEntry(
          area: '',
          date: '',
          address: '',
          details: '',
          landlordAndPhone: '',
          outcome: '',
          link: '',
        ),
    ];

    final blocks = <pw.Widget>[];
    String? currentArea;
    for (final entry in allRows) {
      final area = entry.area.trim();
      if (area.isNotEmpty && area != currentArea) {
        blocks.add(_areaHeading(area));
        currentArea = area;
      }
      blocks.add(_propertyBlock(entry));
    }
    return blocks;
  }

  static pw.Widget _areaHeading(String area) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 7),
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        border: pw.Border.all(color: PdfColors.grey500, width: 0.4),
      ),
      child: pw.Text(
        area,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _propertyBlock(HousingDiaryPropertyEntry entry) {
    final isBlank =
        entry.date.isEmpty &&
        entry.address.isEmpty &&
        entry.details.isEmpty &&
        entry.landlordAndPhone.isEmpty &&
        entry.outcome.isEmpty &&
        entry.link.isEmpty;

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 13),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _inlineLine([
            _label('Date:'),
            _value(entry.date, width: 72),
            _label('Property Address:'),
            _value(entry.address, expand: true),
          ]),
          pw.SizedBox(height: 4),
          _line('Property details:', entry.details),
          pw.SizedBox(height: 4),
          _line('Landlord & phone number:', entry.landlordAndPhone),
          pw.SizedBox(height: 4),
          _line('Outcome:', entry.outcome),
          if (!isBlank && entry.link.trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            _linkedLine('Link:', entry.link.trim()),
          ],
        ],
      ),
    );
  }

  static List<pw.Widget> _actionBlocks(List<HousingDiaryActionEntry> entries) {
    final rows = entries.isEmpty
        ? const [HousingDiaryActionEntry(date: '', action: '', outcome: '')]
        : entries;
    final blanksNeeded = rows.length >= 4 ? 0 : 4 - rows.length;
    final allRows = [
      ...rows,
      for (var index = 0; index < blanksNeeded; index++)
        const HousingDiaryActionEntry(date: '', action: '', outcome: ''),
    ];

    return [for (final entry in allRows) _actionBlock(entry)];
  }

  static pw.Widget _actionBlock(HousingDiaryActionEntry entry) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _inlineLine([
            _label('Date:'),
            _value(entry.date, width: 82),
            _label('Actions:'),
            _value(entry.action, expand: true),
          ]),
          pw.SizedBox(height: 4),
          _line('Outcome:', entry.outcome),
        ],
      ),
    );
  }

  static pw.Widget _line(String label, String value) {
    return _inlineLine([_label(label), _value(value, expand: true)]);
  }

  static pw.Widget _linkedLine(String label, String url) {
    return _inlineLine([
      _label(label),
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 2),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey500, width: 0.4),
            ),
          ),
          child: pw.UrlLink(
            destination: url,
            child: pw.Text(
              url,
              style: const pw.TextStyle(
                color: PdfColors.blue700,
                decoration: pw.TextDecoration.underline,
                fontSize: 8,
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  static pw.Widget _inlineLine(List<pw.Widget> children) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [for (final child in children) child],
    );
  }

  static pw.Widget _label(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(right: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _value(String text, {double? width, bool expand = false}) {
    final field = pw.Container(
      width: width,
      padding: const pw.EdgeInsets.only(bottom: 2),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey500, width: 0.4),
        ),
      ),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );
    return expand ? pw.Expanded(child: field) : field;
  }

  static String _documentXml({
    required String caseCode,
    required String worker,
    required List<HousingDiaryPropertyEntry> properties,
    required List<HousingDiaryActionEntry> actions,
  }) {
    final workerText = worker.trim().isEmpty ? '-' : worker.trim();
    final propertyBlocks = _docxPropertyBlocks(properties);
    final actionBlocks = _docxActionBlocks(actions);

    return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    ${_docxParagraph('HOUSING DIARY', style: 'Title', align: 'center')}
    ${_docxParagraph('Case code: $caseCode    Worker: $workerText', style: 'Small')}
    ${_docxSpacer()}
    ${_docxParagraph('PROPERTIES I HAVE APPLIED FOR:', style: 'Heading')}
    $propertyBlocks
    ${_docxPageBreak()}
    ${_docxParagraph('OTHER THINGS I HAVE DONE THIS WEEK:', style: 'Heading')}
    $actionBlocks
    ${_docxPageBreak()}
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="850" w:right="850" w:bottom="850" w:left="850" w:header="720" w:footer="720" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>
''';
  }

  static String _docxPropertyBlocks(List<HousingDiaryPropertyEntry> entries) {
    final rows = entries.isEmpty
        ? <HousingDiaryPropertyEntry>[
            const HousingDiaryPropertyEntry(
              area: '',
              date: '',
              address: '',
              details: '',
              landlordAndPhone: '',
              outcome: '',
              link: '',
            ),
          ]
        : entries;
    final blanksNeeded = rows.length >= 7 ? 0 : 7 - rows.length;
    final allRows = [
      ...rows,
      for (var index = 0; index < blanksNeeded; index++)
        const HousingDiaryPropertyEntry(
          area: '',
          date: '',
          address: '',
          details: '',
          landlordAndPhone: '',
          outcome: '',
          link: '',
        ),
    ];

    final buffer = StringBuffer();
    String? currentArea;
    for (final entry in allRows) {
      final area = entry.area.trim();
      if (area.isNotEmpty && area != currentArea) {
        buffer.write(_docxParagraph(area, style: 'Area'));
        currentArea = area;
      }
      buffer
        ..write(
          _docxParagraph(
            'Date: ${entry.date}    Property Address: ${entry.address}',
          ),
        )
        ..write(_docxParagraph('Property details: ${entry.details}'))
        ..write(
          _docxParagraph('Landlord & phone number: ${entry.landlordAndPhone}'),
        )
        ..write(_docxParagraph('Outcome: ${entry.outcome}'));
      if (entry.link.trim().isNotEmpty) {
        buffer.write(
          _docxParagraph('Link: ${entry.link.trim()}', style: 'Small'),
        );
      }
      buffer.write(_docxSpacer());
    }
    return buffer.toString();
  }

  static String _docxActionBlocks(List<HousingDiaryActionEntry> entries) {
    final rows = entries.isEmpty
        ? const [HousingDiaryActionEntry(date: '', action: '', outcome: '')]
        : entries;
    final blanksNeeded = rows.length >= 4 ? 0 : 4 - rows.length;
    final allRows = [
      ...rows,
      for (var index = 0; index < blanksNeeded; index++)
        const HousingDiaryActionEntry(date: '', action: '', outcome: ''),
    ];

    return [
      for (final entry in allRows) ...[
        _docxParagraph('Date: ${entry.date}    Actions: ${entry.action}'),
        _docxParagraph('Outcome: ${entry.outcome}'),
        _docxSpacer(),
      ],
    ].join();
  }

  static String _docxParagraph(
    String text, {
    String style = 'Body',
    String? align,
  }) {
    final escaped = _xml(text);
    final paragraphProps = switch (style) {
      'Title' => '<w:jc w:val="${align ?? 'left'}"/><w:spacing w:after="220"/>',
      'Heading' =>
        '<w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" w:color="000000"/></w:pBdr><w:spacing w:before="120" w:after="180"/>',
      'Area' =>
        '<w:spacing w:before="80" w:after="80"/><w:shd w:fill="EDEDED"/>',
      'Small' => '<w:spacing w:after="100"/>',
      _ => '<w:spacing w:after="80"/>',
    };
    final runProps = switch (style) {
      'Title' => '<w:b/><w:sz w:val="44"/>',
      'Heading' => '<w:b/><w:sz w:val="26"/>',
      'Area' => '<w:b/><w:sz w:val="21"/>',
      'Small' => '<w:sz w:val="18"/><w:color w:val="666666"/>',
      _ => '<w:sz w:val="21"/>',
    };

    return '''
<w:p>
  <w:pPr>$paragraphProps</w:pPr>
  <w:r><w:rPr>$runProps</w:rPr><w:t xml:space="preserve">$escaped</w:t></w:r>
</w:p>
''';
  }

  static String _docxSpacer() {
    return '<w:p><w:pPr><w:spacing w:after="120"/></w:pPr></w:p>';
  }

  static String _docxPageBreak() {
    return '<w:p><w:r><w:br w:type="page"/></w:r></w:p>';
  }

  static String _xml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _corePropertiesXml(String caseCode) {
    final now = DateTime.now().toUtc().toIso8601String();
    return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>Housing Diary $caseCode</dc:title>
  <dc:creator>Support Worker Log</dc:creator>
  <cp:lastModifiedBy>Support Worker Log</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">$now</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">$now</dcterms:modified>
</cp:coreProperties>
''';
  }

  static const _contentTypesXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
''';

  static const _rootRelationshipsXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
''';

  static const _appPropertiesXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>Support Worker Log</Application>
</Properties>
''';
}
