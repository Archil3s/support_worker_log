import 'dart:js_interop';

@JS('supportWorkerLogInstallApp')
external JSPromise<JSBoolean> _supportWorkerLogInstallApp();

class WebInstallPromptService {
  Future<bool> promptInstall() async {
    try {
      final result = await _supportWorkerLogInstallApp().toDart;
      return result.toDart;
    } catch (_) {
      return false;
    }
  }
}
