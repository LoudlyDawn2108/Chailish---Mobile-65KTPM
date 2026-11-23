import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'fake_implementation.dart';
import 'lesson_repository.dart';
import 'models/pronunciation.dart';

// ─────────────────────────────────────────────── TTS · Chủ sở hữu: Khánh (#12)

/// Đọc mẫu tiếng Trung. Dùng ở: Phát âm (#15), Từ vựng (#19), Flashcard (#20),
/// Kiểm tra nghe (#32), Trợ lý AI (#9).
abstract class TtsService {
  /// [slow] = tốc độ chậm (0.7x) để người học nghe rõ thanh điệu.
  Future<void> speak(String text, {bool slow = false});
  Future<void> stop();
}

final ttsServiceProvider = Provider<TtsService>((ref) {
  final tts = FlutterTtsService();
  ref.onDispose(tts.stop);
  return tts;
});

/// Bản thật tối thiểu (flutter_tts, zh-CN). Khánh hoàn thiện ở #12: chọn giọng,
/// chuẩn hoá văn bản, đúng tốc độ 1.0x / 0.7x trên cả Android và iOS.
class FlutterTtsService implements TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _configured = false;
  bool _isSpeaking = false;

  Future<void> _ensureInit() async {
    if (_configured) return;
    try {
      await _tts.setLanguage('zh-CN');
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0); // Giu 1.0 nguyen ban de khong bi meo tieng hoac no DSP
      await _tts.setSpeechRate(0.45); // Toc do ly tuong giup phat am ro, vang va to hon
      await _tts.awaitSpeakCompletion(true);
      try {
        await _tts.setQueueMode(0); // QUEUE_FLUSH
      } catch (_) {}
      _configured = true;
    } catch (_) {}
  }

  @override
  Future<void> speak(String text, {bool slow = false}) async {
    await _ensureInit();
    if (_isSpeaking) {
      try {
        await _tts.stop();
        await Future<void>.delayed(const Duration(milliseconds: 60));
      } catch (_) {}
    }
    _isSpeaking = true;
    try {
      await _tts.setSpeechRate(slow ? 0.30 : 0.45);
      // Chen dau cham cau tieng Trung 。 de bo tong hop am thanh tu dong ha bien do ve 0 (khong bi giat/no o cuoi)
      final clean = text.trim();
      final conditioned = clean.endsWith('。') || clean.endsWith('？') || clean.endsWith('！')
          ? clean
          : '$clean。';
      // Chen khoang trang o dau de khoi tao AudioTrack DAC voi mau 0 truoc khi phat am
      await _tts.speak(' $conditioned');
    } catch (e) {
      debugPrint('TTS speak error: $e');
    } finally {
      _isSpeaking = false;
    }
  }

  @override
  Future<void> stop() async {
    _isSpeaking = false;
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

// ─────────────────────────────── Nhận dạng giọng nói · Chủ sở hữu: Khánh (#11)

/// Nhận dạng giọng nói zh-CN thành chữ (Trợ lý AI #9, Phát âm #15).
abstract class SpeechRecognizer {
  Future<bool> initialize();

  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    void Function(double level)? onSoundLevel,
    void Function(String error)? onError,
  });

  Future<void> stop();
}

final speechRecognizerProvider = Provider<SpeechRecognizer>((ref) {
  final speech = SpeechToTextRecognizer();
  ref.onDispose(speech.stop);
  return speech;
});

class SpeechToTextRecognizer implements SpeechRecognizer {
  final SpeechToText _speech = SpeechToText();
  bool _ready = false;
  void Function(String error)? _currentOnError;

  @override
  Future<bool> initialize() async {
    if (_ready) return true;
    try {
      _ready = await _speech.initialize(
        onError: (e) {
          debugPrint('STT error: ${e.errorMsg} permanent: ${e.permanent}');
          _currentOnError?.call(e.errorMsg);
        },
        onStatus: (s) => debugPrint('STT status: $s'),
      );
    } catch (e) {
      debugPrint('STT initialize exception: $e');
      _ready = false;
    }
    return _ready;
  }

  @override
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    void Function(double level)? onSoundLevel,
    void Function(String error)? onError,
  }) async {
    _currentOnError = onError;
    if (!await initialize()) {
      onError?.call('Không thể khởi tạo bộ nhận dạng giọng nói');
      return;
    }
    String targetLocale = 'zh-CN';
    try {
      final locales = await _speech.locales();
      final zhLocale = locales.firstWhere(
        (l) => l.localeId.toLowerCase().startsWith('zh') || l.localeId.toLowerCase().startsWith('cmn'),
        orElse: () => LocaleName('zh-CN', 'Chinese'),
      );
      targetLocale = zhLocale.localeId;
    } catch (_) {}

    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) => onResult(result.recognizedWords, result.finalResult),
        onSoundLevelChange: onSoundLevel != null
            ? (level) {
                // Bien do tra ve thuong tu -2 dB den 10 dB tuy thuoc thiet bi
                final normalized = level <= 0 ? 0.08 : (level / 10.0).clamp(0.08, 1.0);
                onSoundLevel(normalized);
              }
            : null,
        listenOptions: SpeechListenOptions(
          localeId: targetLocale,
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.confirmation,
        ),
      );
    } catch (e) {
      debugPrint('STT listen error: $e');
      onError?.call(e.toString());
    }
  }

  @override
  Future<void> stop() async {
    _currentOnError = null;
    try {
      await _speech.stop();
    } catch (_) {}
  }
}

// ─────────────────────────────────────────── Ghi âm · Chủ sở hữu: Khánh (#11)

enum RecorderState { idle, recording, processing, done }

/// Ghi âm WAV 16 kHz mono để chấm phát âm.
abstract class VoiceRecorder {
  /// Âm lượng 0..1, phát liên tục khi đang ghi (vẽ sóng âm).
  Stream<double> get amplitude;

  /// Xin quyền micro rồi bắt đầu ghi. Trả false nếu người dùng từ chối quyền.
  Future<bool> start();

  /// Dừng ghi, trả về file ghi âm (null nếu chưa ghi gì).
  Future<Recording?> stop();

  Future<void> cancel();
}

final voiceRecorderProvider = Provider<VoiceRecorder>((ref) {
  final r = FakeVoiceRecorder();
  ref.onDispose(r.cancel);
  return r;
});

/// Bản giả: không chạm micro, phát sóng âm hình sin, trả bản ghi không có file.
class FakeVoiceRecorder with FakeImplementation implements VoiceRecorder {
  final _amp = StreamController<double>.broadcast();
  Timer? _timer;
  DateTime? _startedAt;

  @override
  Stream<double> get amplitude => _amp.stream;

  @override
  Future<bool> start() async {
    _startedAt = DateTime.now();
    var t = 0.0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      t += 0.35;
      _amp.add((0.5 + 0.4 * sin(t) * sin(t * 0.37)).clamp(0.05, 1.0));
    });
    return true;
  }

  @override
  Future<Recording?> stop() async {
    _timer?.cancel();
    final started = _startedAt;
    _startedAt = null;
    if (started == null) return null;
    return Recording(path: null, duration: DateTime.now().difference(started));
  }

  @override
  Future<void> cancel() async {
    _timer?.cancel();
    _startedAt = null;
  }
}

// ──────────────────────────────────────────────── Pinyin · Chủ sở hữu: Khánh (#12)

/// Đổi chữ Hán sang Pinyin có dấu.
abstract class PinyinService {
  /// "你好" → "nǐ hǎo". Mỗi âm tiết cách nhau một dấu cách.
  ///
  /// Mặc định giữ thanh điệu gốc theo từ điển (để hiển thị). [applySandhi] = true
  /// trả cách đọc thực tế sau biến điệu 3-3, 一, 不 ("ní hǎo"), dùng khi chấm phát âm.
  Future<String> toPinyin(String hanzi, {bool applySandhi = false});
}

final pinyinServiceProvider = Provider<PinyinService>((ref) {
  return FakePinyinService(ref.watch(lessonRepositoryProvider));
});

/// Bản giả: tra trong từ vựng của các bài mẫu (không có trong bài thì trả "?").
/// Chưa xử lý biến điệu: [applySandhi] bị bỏ qua.
class FakePinyinService with FakeImplementation implements PinyinService {
  final LessonRepository _lessons;
  Map<String, String>? _dict;

  FakePinyinService(this._lessons);

  @override
  Future<String> toPinyin(String hanzi, {bool applySandhi = false}) async {
    _dict ??= {
      for (final l in await _lessons.lessons())
        for (final w in l.words) w.hanzi: w.pinyin.toLowerCase(),
    };
    final dict = _dict!;
    final out = <String>[];
    var i = 0;
    while (i < hanzi.length) {
      // Khớp từ dài nhất trước (你好 trước 你).
      var matched = false;
      for (var len = min(4, hanzi.length - i); len > 0; len--) {
        final p = dict[hanzi.substring(i, i + len)];
        if (p != null) {
          out.add(p);
          i += len;
          matched = true;
          break;
        }
      }
      if (!matched) {
        final ch = hanzi[i];
        if (RegExp(r'[一-鿿]').hasMatch(ch)) out.add('?');
        i++;
      }
    }
    return out.join(' ');
  }
}
