// Module M2 – Phát âm mẫu (Text-to-Speech) · Phụ trách: Lê Tuấn Khanh

import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    await _tts.setLanguage('en-US');
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
    _ready = true;
  }

  /// [rate]: 0.0–1.0 (Android). 0.45 ~ tốc độ bình thường, 0.25 ~ chậm.
  Future<void> speak(String text, {double rate = 0.45}) async {
    try {
      await _init();
      await _tts.stop();
      await _tts.setSpeechRate(rate);
      await _tts.speak(text);
    } catch (_) {
      // Thiết bị không có engine TTS: bỏ qua, không làm hỏng luồng luyện tập.
    }
  }

  Future<void> stop() => _tts.stop();
}
