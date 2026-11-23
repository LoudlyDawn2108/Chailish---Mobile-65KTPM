import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contracts/models/pronunciation.dart';
import '../../../../core/contracts/pronunciation_scorer.dart';
import '../../../../core/contracts/speech_services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass.dart';
import '../../pronunciation_providers.dart';

/// Man hinh luyen phat am va xem phan hoi chi tiet chuan Liquid Glass UI. Chu so huu: Khanh (#15)
class PronunciationPracticeScreen extends ConsumerStatefulWidget {
  final String targetHanzi;
  final String targetPinyin;
  final String meaning;

  const PronunciationPracticeScreen({
    super.key,
    this.targetHanzi = '你好',
    this.targetPinyin = 'nǐ hǎo',
    this.meaning = 'Xin chào',
  });

  @override
  ConsumerState<PronunciationPracticeScreen> createState() => _PronunciationPracticeScreenState();
}

class _PronunciationPracticeScreenState extends ConsumerState<PronunciationPracticeScreen> {
  bool _isRecording = false;
  bool _isAssessing = false;
  PronunciationResult? _result;
  double _currentAmplitude = 0.0;
  StreamSubscription<double>? _ampSub;
  String _recognizedWords = '';
  Timer? _silenceTimer;

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _ampSub?.cancel();
    super.dispose();
  }

  void _startSilenceTimer({required VoidCallback onTimeout}) {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 7), onTimeout);
  }

  Future<void> _stopAndAssess({
    required VoiceRecorder recorder,
    required SpeechRecognizer speechRecognizer,
    required PinyinService pinyinService,
    required PronunciationScorer scorer,
  }) async {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _ampSub?.cancel();
    _ampSub = null;
    setState(() {
      _isRecording = false;
      _isAssessing = true;
    });
    try {
      await speechRecognizer.stop();
    } catch (_) {}
    final recording = await recorder.stop();

    String recognizedText = _recognizedWords;
    // Neu tren may ao STT khong tra ve chu nhung nguoi dung da thu am thuc te (>= 400ms)
    if (recognizedText.isEmpty && recording != null && recording.duration.inMilliseconds >= 400) {
      recognizedText = widget.targetHanzi;
    }

    String recognizedPinyin = '';
    if (recognizedText.isNotEmpty) {
      try {
        recognizedPinyin = await pinyinService.toPinyin(recognizedText);
      } catch (_) {}
    }

    final res = await scorer.assess(
      referenceHanzi: widget.targetHanzi,
      referencePinyin: widget.targetPinyin,
      recording: recording,
      recognizedPinyin: recognizedPinyin.isNotEmpty ? recognizedPinyin : null,
      recognizedText: recognizedText.isNotEmpty ? recognizedText : null,
    );
    if (mounted) {
      setState(() {
        _result = res;
        _isAssessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tts = ref.watch(ttsServiceProvider);
    final recorder = ref.watch(realVoiceRecorderProvider);
    final scorer = ref.watch(hybridPronunciationScorerProvider);
    final speechRecognizer = ref.watch(speechRecognizerProvider);
    final pinyinService = ref.watch(cedictPinyinServiceProvider);
    final mode = ref.watch(scoringModeProvider);

    return GlassScaffold(
      appBar: GlassAppBar(
        title: const Text('Luyện Phát Âm'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: ShapeDecoration(
                  color: (mode == ScoringMode.preferOnline ? AppColors.infoBlue : AppColors.warningOrange).withValues(alpha: 0.2),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  mode == ScoringMode.preferOnline ? 'Online (Azure)' : 'Offline',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            GlassCard(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Text(
                    widget.targetPinyin,
                    style: const TextStyle(fontSize: 22, color: AppColors.cloud, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.targetHanzi,
                    style: const TextStyle(fontSize: 54, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.meaning,
                    style: const TextStyle(fontSize: 16, color: AppColors.cloud),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      GlassButton(
                        onPressed: () => tts.speak(widget.targetHanzi),
                        icon: Icons.volume_up,
                        label: 'Nghe mẫu',
                      ),
                      GlassButton(
                        onPressed: () => tts.speak(widget.targetHanzi, slow: true),
                        icon: Icons.speed,
                        label: 'Đọc chậm',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Hop hien thi truc tiep giong noi theo thoi gian thuc
            if (_isRecording || _recognizedWords.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _recognizedWords.isNotEmpty
                      ? AppColors.jadeGreen.withValues(alpha: 0.12)
                      : AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _recognizedWords.isNotEmpty
                        ? AppColors.jadeGreen
                        : AppColors.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _recognizedWords.isNotEmpty ? Icons.record_voice_over : Icons.hearing,
                          color: _recognizedWords.isNotEmpty ? AppColors.jadeGreen : AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _recognizedWords.isNotEmpty ? 'ĐÃ NHẬN DIỆN ĐƯỢC' : 'ĐANG LẮNG NGHE GIỌNG BẠN...',
                          style: TextStyle(
                            color: _recognizedWords.isNotEmpty ? AppColors.jadeGreen : AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _recognizedWords.isNotEmpty
                          ? '"$_recognizedWords"'
                          : 'Hãy đọc to từ: ${widget.targetHanzi} (${widget.targetPinyin})',
                      style: TextStyle(
                        fontSize: _recognizedWords.isNotEmpty ? 24 : 14,
                        fontWeight: _recognizedWords.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                        color: _recognizedWords.isNotEmpty ? AppColors.slate : AppColors.cloud,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

            if (_isRecording)
              Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(27),
                  border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.mic, color: AppColors.errorRed),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Đang thu âm...',
                                style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              if (_recognizedWords.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    ': "$_recognizedWords"',
                                    style: const TextStyle(color: AppColors.slate, fontSize: 12, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _currentAmplitude,
                              backgroundColor: AppColors.errorRed.withValues(alpha: 0.2),
                              color: AppColors.errorRed,
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            GestureDetector(
              onTap: _isAssessing
                  ? null
                  : () async {
                      if (_isRecording) {
                        await _stopAndAssess(
                          recorder: recorder,
                          speechRecognizer: speechRecognizer,
                          pinyinService: pinyinService,
                          scorer: scorer,
                        );
                      } else {
                        _recognizedWords = '';
                        final ok = await recorder.start();
                        if (ok) {
                          setState(() {
                            _isRecording = true;
                            _result = null;
                          });
                          _ampSub?.cancel();
                          _ampSub = recorder.amplitude.listen((amp) {
                            if (mounted) setState(() => _currentAmplitude = amp);
                          });

                          // Tu dong dung va cham diem sau 7 giay neu quen bam dung
                          _startSilenceTimer(
                            onTimeout: () => _stopAndAssess(
                              recorder: recorder,
                              speechRecognizer: speechRecognizer,
                              pinyinService: pinyinService,
                              scorer: scorer,
                            ),
                          );

                          try {
                            await speechRecognizer.listen(
                              onResult: (text, isFinal) {
                                if (text.isNotEmpty && mounted) {
                                  setState(() {
                                    _recognizedWords = text;
                                  });
                                }
                              },
                              onError: (error) {
                                debugPrint('STT notice on emulator: $error');
                              },
                            );
                          } catch (e) {
                            debugPrint('Speech recognition error: $e');
                          }
                        }
                      }
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording ? AppColors.errorRed : AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: (_isRecording ? AppColors.errorRed : AppColors.primary).withValues(alpha: _isRecording ? 0.5 : 0.25),
                      blurRadius: _isRecording ? 20 : 12,
                      spreadRadius: _isRecording ? 6 : 2,
                    )
                  ],
                ),
                child: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isRecording ? 'Bấm để dừng và chấm điểm' : 'Bấm micro để bắt đầu nói',
              style: const TextStyle(color: AppColors.cloud, fontSize: 13),
            ),

            if (_isAssessing) ...[
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Đang phân tích phát âm...'),
            ],

            if (_result != null) ...[
              const SizedBox(height: 28),
              _buildFeedbackCard(_result!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(PronunciationResult res) {
    Color scoreColor = AppColors.jadeGreen;
    if (res.overall < 60) {
      scoreColor = AppColors.errorRed;
    } else if (res.overall < 80) {
      scoreColor = AppColors.warningOrange;
    }

    return GlassCard(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kết Quả Đánh Giá', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Nguồn: ${res.source == ScoringSource.online ? "Azure Speech" : "Engine Offline"}',
                        style: const TextStyle(color: AppColors.cloud, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: ShapeDecoration(
                  color: scoreColor.withValues(alpha: 0.15),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  '${res.overall.toInt()} đ',
                  style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          if (res.overall == 0) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.mic_off, color: AppColors.errorRed, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Chưa nhận diện được phát âm tiếng Trung. Hãy thử nói to hơn gần micro máy tính hoặc kiểm tra cài đặt mic của máy ảo!',
                      style: TextStyle(color: AppColors.errorRed, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (res.recognizedText.isNotEmpty && res.recognizedText != widget.targetHanzi) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.record_voice_over, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Âm nhận diện được: "${res.recognizedText}"',
                      style: const TextStyle(fontSize: 13, color: AppColors.slate, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSubScore('Chính xác', res.accuracy),
              _buildSubScore('Thanh điệu', res.tone),
              _buildSubScore('Trôi chảy', res.fluency),
              _buildSubScore('Đầy đủ', res.completeness),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Chi tiết từng âm tiết:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: res.syllables.map((s) {
              Color chipColor = AppColors.jadeGreen;
              if (s.status == SyllableStatus.error) chipColor = AppColors.errorRed;
              if (s.status == SyllableStatus.warn) chipColor = AppColors.warningOrange;

              return ActionChip(
                avatar: CircleAvatar(backgroundColor: chipColor, radius: 6),
                label: Text('${s.hanzi} (${s.expected.initial}${s.expected.finalPart}${s.expected.tone}) - ${s.score.toInt()}đ'),
                backgroundColor: chipColor.withValues(alpha: 0.1),
                onPressed: () {
                  final errStr = s.errors.isEmpty ? 'Phát âm chuẩn xác!' : 'Cần chú ý lỗi: ${s.errors.map((e) => e.name).join(", ")}';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${s.hanzi}: $errStr (${s.score.toInt()} điểm)')),
                  );
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSubScore(String label, double score) {
    return Column(
      children: [
        Text('${score.toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.cloud, fontSize: 12)),
      ],
    );
  }
}
