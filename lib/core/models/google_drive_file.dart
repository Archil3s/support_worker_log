class GoogleDriveFile {
  const GoogleDriveFile({
    required this.id,
    required this.name,
    required this.mimeType,
    this.webViewLink,
  });

  final String id;
  final String name;
  final String mimeType;
  final String? webViewLink;

  bool get isFolder => mimeType == 'application/vnd.google-apps.folder';
}
