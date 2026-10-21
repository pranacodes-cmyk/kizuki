import 'package:flutter_tts/flutter_tts.dart';

/// Japanese text-to-speech for words and examples — mirrors src/lib/speech.ts.
class Tts {
  static final FlutterTts _tts = FlutterTts();
  static bool _ready = false;

  static Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      await _tts.setLanguage('ja-JP');
      await _tts.setSpeechRate(0.45);
      await _tts.awaitSpeakCompletion(false);
    } catch (_) {
      // No Japanese voice installed — speak() still tries the default engine.
    }
  }

  static Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _init();
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }
}
