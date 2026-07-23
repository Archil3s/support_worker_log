import 'package:flutter_test/flutter_test.dart';
import 'package:support_worker_log/core/utils/google_docs_download_utils.dart';

void main() {
  test('builds a read-only Google Docs docx export link', () {
    final uri = googleDocsDownloadUri('doc-id-123');

    expect(uri.scheme, 'https');
    expect(uri.host, 'docs.google.com');
    expect(uri.path, '/document/d/doc-id-123/export');
    expect(uri.queryParameters, {'format': 'docx'});
  });

  test('requires a Google Doc ID', () {
    expect(() => googleDocsDownloadUri('  '), throwsArgumentError);
  });
}
