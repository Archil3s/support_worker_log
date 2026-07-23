Uri googleDocsDownloadUri(String fileId) {
  final trimmedId = fileId.trim();
  if (trimmedId.isEmpty) {
    throw ArgumentError.value(fileId, 'fileId', 'Google Doc ID is required.');
  }

  return Uri(
    scheme: 'https',
    host: 'docs.google.com',
    pathSegments: ['document', 'd', trimmedId, 'export'],
    queryParameters: const {'format': 'docx'},
  );
}
