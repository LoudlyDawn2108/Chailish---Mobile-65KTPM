// Module M2 – Thu âm & nhận dạng giọng nói · Phụ trách: Lê Tuấn Khanh
//
// Hai chế độ:
//  * Offline (mặc định): dùng bộ nhận dạng giọng nói của Android
//    (speech_to_text) để lấy văn bản + độ tin cậy -> engine so sánh âm vị.
//  * Azure: ghi âm WAV 16 kHz mono (record) -> gửi lên Azure chấm điểm.
// Android không cho 2 tác vụ cùng dùng micro, nên mỗi lần chỉ chạy 1 chế độ.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechCapture {
  const SpeechCapture({
    required this.text,
    this.confidence = -1,
    this.duration,
    this.audioPath,
  });

  final String text;
  final double confidence;
  final Duration? duration;
  final String? audioPath;
}

class SpeechException implements Exception {
  const SpeechException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SpeechService {
  final SpeechToText _stt = SpeechToText();
  // Tạo khi cần (chỉ chế độ Azure dùng tới).
  AudioRecorder? _rec;
  AudioRecorder get _recorder => _rec ??= AudioRecorder();

  bool _sttReady = false;
  Completer<SpeechCapture>? _pending;
  String _lastText = '';
  double _lastConfidence = -1;
  DateTime? _firstWordAt;
  DateTime? _lastWordAt;
  void Function(String)? _onPartial;
  static const _silenceToFinish = Duration(milliseconds: 3500);

  bool get isListening => _stt.isListening;

  /// Xin quyền micro. Trả về false nếu bị từ chối.
  Future<bool> ensureMicPermission() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;
    status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> isMicPermanentlyDenied() =>
      Permission.microphone.isPermanentlyDenied;

  Future<bool> _initStt() async {
    if (_sttReady) return true;
    _sttReady = await _stt.initialize(
      onError: _handleError,
      onStatus: _handleStatus,
    );
    return _sttReady;
  }

  // ------------------------------------------------------------------
  // Chế độ offline: nhận dạng giọng nói
  // ------------------------------------------------------------------

  /// Bắt đầu nghe. Future hoàn thành khi người dùng ngừng nói hoặc gọi
  /// [stopListening]. [onPartial] nhận văn bản tạm thời theo thời gian thực.
  Future<SpeechCapture> listen({
    required void Function(String partial) onPartial,
    void Function(double level)? onSoundLevel,
    Duration listenFor = const Duration(seconds: 15),
  }) async {
    if (!await ensureMicPermission()) {
      throw const SpeechException('Ứng dụng cần quyền micro để chấm phát âm.');
    }
    if (!await _initStt()) {
      throw const SpeechException(
          'Thiết bị không hỗ trợ nhận dạng giọng nói. Hãy cài/bật ứng dụng Google '
          'và gói ngôn ngữ tiếng Anh, hoặc dùng chế độ Azure trong Cài đặt.');
    }
    await _stt.cancel();
    _pending = Completer<SpeechCapture>();
    _lastText = '';
    _lastConfidence = -1;
    _firstWordAt = null;
    _lastWordAt = null;
    _onPartial = onPartial;
    await _stt.listen(
      onResult: _handleResult,
      onSoundLevelChange: onSoundLevel,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        localeId: 'en-US', // plugin truyền nguyên văn vào EXTRA_LANGUAGE (BCP-47)
        listenFor: listenFor,
        // pauseFor được plugin gửi xuống Android dưới dạng
        // EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS: thiếu nó, bộ nhận
        // dạng offline (SODA) chạy chế độ "oneshot" và hay trả kết quả rỗng.
        pauseFor: _silenceToFinish,
      ),
    );
    // Bộ đếm pauseFor phía Dart chỉ đặt lại khi có chữ nhận dạng, mà SODA
    // không gửi kết quả tạm -> người nói chậm bị cắt sau vài giây (lỗi tìm
    // thấy khi QA trên Redmi Note 11T). Nới bộ đếm Dart bằng listenFor; việc
    // chốt câu khi im lặng do Android đảm nhận. Chỉ gọi SAU khi listen() trả
    // về (gọi sớm hơn -> plugin tính sai thời gian và dừng ngay).
    if (_stt.isListening) {
      try {
        _stt.changePauseFor(listenFor);
      } catch (_) {}
    }
    return _pending!.future;
  }

  Future<void> stopListening() async {
    if (_stt.isListening) await _stt.stop();
    // Nếu nền tảng không gửi kết quả cuối, trả về kết quả tạm gần nhất.
    Future.delayed(const Duration(milliseconds: 1200), _completeWithLast);
  }

  Future<void> cancelListening() async {
    await _stt.cancel();
    _pending = null;
  }

  void _handleResult(SpeechRecognitionResult r) {
    final text = r.recognizedWords;
    if (text.isNotEmpty) {
      final now = DateTime.now();
      _firstWordAt ??= now;
      if (text != _lastText) _lastWordAt = now;
      _lastText = text;
      _onPartial?.call(text);
    }
    // Android thường gửi confidence = 0 cho kết quả tạm; chỉ lấy từ kết quả
    // cuối và coi giá trị <= 0 là "không có".
    if (r.finalResult && r.hasConfidenceRating && r.confidence > 0) {
      _lastConfidence = r.confidence;
    }
    if (r.finalResult) _completeWithLast();
  }

  void _handleStatus(String status) {
    if (status == SpeechToText.doneStatus) {
      Future.delayed(const Duration(milliseconds: 600), _completeWithLast);
    }
  }

  void _handleError(SpeechRecognitionError e) {
    final c = _pending;
    if (c == null || c.isCompleted) return;
    if (_lastText.isNotEmpty) {
      _completeWithLast();
      return;
    }
    final msg = switch (e.errorMsg) {
      'error_no_match' || 'error_speech_timeout' =>
        'Không nghe rõ, bạn hãy nói to và rõ hơn nhé.',
      'error_network' || 'error_network_timeout' || 'error_server' =>
        'Lỗi mạng khi nhận dạng giọng nói. Hãy kiểm tra kết nối hoặc tải gói '
            'ngôn ngữ tiếng Anh ngoại tuyến.',
      'error_audio' => 'Không truy cập được micro.',
      'error_permission' || 'error_insufficient_permissions' =>
        'Ứng dụng chưa được cấp quyền micro.',
      'error_busy' => 'Micro đang bận, thử lại sau giây lát.',
      _ => 'Lỗi nhận dạng giọng nói (${e.errorMsg}).',
    };
    c.completeError(SpeechException(msg));
    _pending = null;
  }

  void _completeWithLast() {
    final c = _pending;
    if (c == null || c.isCompleted) return;
    _pending = null;
    if (_lastText.trim().isEmpty) {
      c.completeError(
          const SpeechException('Không nghe rõ, bạn hãy nói to và rõ hơn nhé.'));
      return;
    }
    Duration? d;
    if (_firstWordAt != null && _lastWordAt != null) {
      // Kết quả tạm đầu tiên đến sau khi bắt đầu nói ~0.5 s.
      d = _lastWordAt!.difference(_firstWordAt!) +
          const Duration(milliseconds: 700);
    }
    c.complete(SpeechCapture(
        text: _lastText, confidence: _lastConfidence, duration: d));
  }

  // ------------------------------------------------------------------
  // Chế độ Azure: ghi âm WAV
  // ------------------------------------------------------------------

  Stream<Amplitude> amplitude() =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 120));

  Future<void> startRecording() async {
    if (!await ensureMicPermission()) {
      throw const SpeechException('Ứng dụng cần quyền micro để ghi âm.');
    }
    if (_stt.isListening) await _stt.cancel();
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'recordings'));
    if (!folder.existsSync()) folder.createSync(recursive: true);
    final path = p.join(
        folder.path, 'rec_${DateTime.now().millisecondsSinceEpoch}.wav');
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        noiseSuppress: true,
      ),
      path: path,
    );
  }

  Future<String?> stopRecording() => _recorder.stop();

  Future<void> cancelRecording() => _recorder.cancel();

  Future<bool> isRecording() async => _rec != null && await _rec!.isRecording();

  Future<void> dispose() async {
    await _stt.cancel();
    await _rec?.dispose();
  }
}
