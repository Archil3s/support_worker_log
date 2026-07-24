import 'dart:typed_data';

class LocalSupportNoteFileSnapshot {
  const LocalSupportNoteFileSnapshot({
    required this.bytes,
    required this.modifiedAt,
  });

  final Uint8List bytes;
  final DateTime modifiedAt;
}

class LocalSupportNotesPlatform {
  bool hasFolder() {
    return false;
  }

  Future<bool> chooseFolder() async {
    throw UnsupportedError(
      'Local folder writing is only available on web or Windows.',
    );
  }

  Future<bool> writeFile({
    required String fileName,
    required String contents,
  }) async {
    throw UnsupportedError(
      'Local folder writing is only available on web or Windows.',
    );
  }

  Future<bool> renameFile({
    required String oldFileName,
    required String newFileName,
    required String contents,
  }) async {
    throw UnsupportedError(
      'Local folder writing is only available on web or Windows.',
    );
  }

  Future<bool> openFile(String fileName) async {
    throw UnsupportedError(
      'Opening files is only available on web or Windows.',
    );
  }

  Future<bool> openFolder(String fileName) async {
    throw UnsupportedError(
      'Opening folders is only available on web or Windows.',
    );
  }

  Future<LocalSupportNoteFileSnapshot> readFile(String fileName) async {
    throw UnsupportedError(
      'Reading local Word documents is only available on web or Windows.',
    );
  }
}
