import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../../core/contracts/models/pronunciation.dart';
import '../../../../core/contracts/speech_services.dart';

/// Cai dat that VoiceRecorder su dung thu vien record (WAV 16kHz mono).
/// Chu so huu: Khanh (#11)
class RealVoiceRecorder implements VoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  final _amp = StreamController<double>.broadcast();

  StreamSubscription<RecordState>? _recordSub;
  StreamSubscription<Amplitude>? _ampSub;
  DateTime? _startedAt;
  String? _currentPath;

  RealVoiceRecorder() {
    _recordSub = _recorder.onStateChanged().listen((state) {
      if (state == RecordState.stop) {
        _ampSub?.cancel();
        _ampSub = null;
      }
    });
  }

  @override
  Stream<double> get amplitude => _amp.stream;

  @override
  Future<bool> start() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) return false;

      final dir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${dir.path}/recordings');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      final fileName = 'rec_${DateTime.now().millisecondsSinceEpoch}.wav';
      _currentPath = '${audioDir.path}/$fileName';
      _startedAt = DateTime.now();

      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 128000,
      );

      await _recorder.start(config, path: _currentPath!);

      _ampSub?.cancel();
      _ampSub = Stream.periodic(const Duration(milliseconds: 60))
          .asyncMap((_) => _recorder.getAmplitude())
          .listen((amp) {
        // Chuyen tu dB sang khoang 0.0 - 1.0
        final db = amp.current;
        if (db < -50) {
          _amp.add(0.05);
        } else if (db > 0) {
          _amp.add(1.0);
        } else {
          _amp.add(((db + 50) / 50).clamp(0.05, 1.0));
        }
      });

      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Recording?> stop() async {
    try {
      _ampSub?.cancel();
      _ampSub = null;
      final path = await _recorder.stop();
      final started = _startedAt;
      _startedAt = null;
      if (started == null || path == null) return null;
      final duration = DateTime.now().difference(started);
      return Recording(path: path, duration: duration);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> cancel() async {
    try {
      _ampSub?.cancel();
      _ampSub = null;
      await _recorder.cancel();
      _startedAt = null;
      if (_currentPath != null) {
        final file = File(_currentPath!);
        if (await file.exists()) {
          await file.delete();
        }
        _currentPath = null;
      }
    } catch (_) {}
  }

  void dispose() {
    _ampSub?.cancel();
    _recordSub?.cancel();
    _amp.close();
    _recorder.dispose();
  }
}
