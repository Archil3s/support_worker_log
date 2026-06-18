import 'dart:js_interop';

@JS('supportWorkerLogSpeechToText')
external JSPromise<JSString?> _supportWorkerLogSpeechToText();

@JS('supportWorkerLogStopSpeechToText')
external void _supportWorkerLogStopSpeechToText();

class SpeechToTextService {
  Future<String?> listenOnce() async {
    try {
      final result = await _supportWorkerLogSpeechToText().toDart;
      final text = result?.toDart.trim();
      if (text == null || text.isEmpty) return null;
      return text;
    } catch (_) {
      return null;
    }
  }

  void stopListening() {
    try {
      _supportWorkerLogStopSpeechToText();
    } catch (_) {}
  }
}
