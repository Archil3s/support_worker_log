import '../../models/google_drive_file.dart';

class GoogleDriveApiPlatform {
  Future<GoogleDriveFile> createFolder({
    required String accessToken,
    required String name,
    String? parentId,
  }) {
    throw UnsupportedError(
      'Google Drive folders are only available in the web app.',
    );
  }

  Future<GoogleDriveFile> uploadFile({
    required String accessToken,
    required String name,
    required String mimeType,
    required List<int> bytes,
    required String parentId,
  }) {
    throw UnsupportedError(
      'Google Drive uploads are only available in the web app.',
    );
  }

  Future<List<GoogleDriveFile>> listChildren({
    required String accessToken,
    required String parentId,
  }) {
    throw UnsupportedError(
      'Google Drive file listing is only available in the web app.',
    );
  }
}
