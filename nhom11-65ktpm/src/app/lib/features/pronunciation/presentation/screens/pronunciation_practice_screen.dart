import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contracts/models/pronunciation.dart';
import '../../../../core/contracts/pronunciation_scorer.dart';
import '../../../../core/contracts/speech_services.dart';

/// Man hinh luyen phat am va xem phan hoi chi tiet. Chu so huu: Khanh (#15)
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

  @override
  Widget build(BuildContext context) {
    final tts = ref.watch(ttsServiceProvider);
    final recorder = ref.watch(voiceRecorderProvider);
    final scorer = ref.watch(pronunciationScorerProvider);
    final mode = ref.watch(scoringModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Luyện Phát Âm'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Chip(
                label: Text(
                  mode == ScoringMode.preferOnline ? 'Online (Azure)' : 'Offline',
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: mode == ScoringMode.preferOnline ? Colors.blue.shade50 : Colors.orange.shade50,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // The tu mau
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      widget.targetPinyin,
                      style: TextStyle(fontSize: 22, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.targetHanzi,
                      style: const TextStyle(fontSize: 54, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.meaning,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => tts.speak(widget.targetHanzi),
                          icon: const Icon(Icons.volume_up),
                          label: const Text('Nghe mẫu'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => tts.speak(widget.targetHanzi, slow: true),
                          icon: const Icon(Icons.speed),
                          label: const Text('Đọc chậm'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Visualizer song am khi ghi am
            if (_isRecording)
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.mic, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    const Text('Đang ghi âm giọng nói...', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _currentAmplitude,
                          backgroundColor: Colors.red.shade100,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Nut bam micro ghi am
            GestureDetector(
              onTap: _isAssessing
                  ? null
                  : () async {
                      if (_isRecording) {
                        setState(() {
                          _isRecording = false;
                          _isAssessing = true;
                        });
                        final recording = await recorder.stop();
                        final res = await scorer.assess(
                          referenceHanzi: widget.targetHanzi,
                          referencePinyin: widget.targetPinyin,
                          recording: recording,
                        );
                        setState(() {
                          _result = res;
                          _isAssessing = false;
                        });
                      } else {
                        final ok = await recorder.start();
                        if (ok) {
                          setState(() {
                            _isRecording = true;
                            _result = null;
                          });
                          recorder.amplitude.listen((amp) {
                            if (mounted) setState(() => _currentAmplitude = amp);
                          });
                        }
                      }
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording ? Colors.redAccent : Theme.of(context).primaryColor,
                  boxShadow: [
                    BoxShadow(
                      color: (_isRecording ? Colors.redAccent : Theme.of(context).primaryColor).withOpacity(_isRecording ? 0.5 : 0.25),
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
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),

            if (_isAssessing) ...[
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Đang phân tích phát âm...'),
            ],

            // Man hinh ket qua phan hoi chi tiet
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
    Color scoreColor = Colors.green;
    if (res.overall < 60) {
      scoreColor = Colors.red;
    } else if (res.overall < 80) {
      scoreColor = Colors.orange;
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kết Quả Đánh Giá', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Nguồn: ${res.source == ScoringSource.online ? "Azure Speech" : "Engine Offline"}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: scoreColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${res.overall.toInt()} đ',
                    style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
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
                Color chipColor = Colors.green;
                if (s.status == SyllableStatus.error) chipColor = Colors.red;
                if (s.status == SyllableStatus.warn) chipColor = Colors.orange;

                return Chip(
                  avatar: CircleAvatar(backgroundColor: chipColor, radius: 6),
                  label: Text('${s.hanzi} (${s.expected.initial}${s.expected.finalPart}${s.expected.tone})'),
                  backgroundColor: chipColor.withOpacity(0.1),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubScore(String label, double score) {
    return Column(
      children: [
        Text('${score.toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      ],
    );
  }
}
