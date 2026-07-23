import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';

class GoogleDocsDownloadService {
  const GoogleDocsDownloadService._();

  static Future<void> saveWordDocument({
    required String fileName,
    required Uint8List bytes,
  }) {
    final safeName = fileName
        .replaceFirst(RegExp(r'\.docx$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[<>:"/\\|?*\u0000-\u001F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return FileSaver.instance.saveFile(
      name: safeName.isEmpty ? 'Google Doc' : safeName,
      bytes: bytes,
      fileExtension: 'docx',
      mimeType: MimeType.microsoftWord,
    );
  }
}
