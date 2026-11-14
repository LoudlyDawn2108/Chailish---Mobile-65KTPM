// Module M3 – Phản hồi kết quả phát âm · Phụ trách: Đinh Thị Hoa
//
// Hiển thị điểm số, tô màu từng từ, đánh dấu âm vị phát âm sai, mẹo
// cải thiện và đề xuất bài tập luyện thêm.

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models/lesson.dart';
import '../../core/models/pronunciation_result.dart';
import '../../core/providers.dart';
import '../../core/widgets/common_widgets.dart';
import '../progress/streak_calculator.dart';
import '../pronunciation/engine/phonemes.dart';
import '../recording/practice_screen.dart';
import 'exercise_recommender.dart';
import 'phoneme_tips.dart';

enum FeedbackAction { retry, next }

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({
    super.key,
    required this.result,
    this.item,
    this.audioPath,
    this.streak,
    this.hasNext = false,
    this.readOnly = false,
  });

  final PronunciationResult result;
  final LessonItem? item;
  final String? audioPath;
  final StreakInfo? streak;
  final bool hasNext;

  /// Mở từ lịch sử: không có nút thử lại / tiếp theo.
  final bool readOnly;

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final AudioPlayer _player = AudioPlayer();

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String get _verdict {
    final s = widget.result.overall;
    if (s >= 90) return 'Xuất sắc! Phát âm gần như người bản xứ 🎉';
    if (s >= 80) return 'Rất tốt! Chỉ cần chỉnh một chút nữa 👍';
    if (s >= 60) return 'Khá ổn, hãy chú ý các âm được đánh dấu 💪';
    if (s > 0) return 'Cần luyện thêm. Nghe mẫu rồi thử lại nhé!';
    return 'Không nghe được bạn nói. Hãy thử lại!';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final lessons = ref.watch(lessonsProvider).value ?? const <Lesson>[];
    final recs = recommendFromErrors(r.errorPhonemes, lessons,
        excludeItemId: widget.item?.id);
    final tts = ref.read(ttsServiceProvider);
    final rate = ref.watch(settingsProvider).ttsRate;

    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả')),
      bottomNavigationBar: widget.readOnly
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.replay),
                      label: const Text('Thử lại'),
                      onPressed: () =>
                          Navigator.of(context).pop(FeedbackAction.retry),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: Icon(widget.hasNext ? Icons.arrow_forward : Icons.check),
                      label: Text(widget.hasNext ? 'Tiếp theo' : 'Hoàn thành'),
                      onPressed: () =>
                          Navigator.of(context).pop(FeedbackAction.next),
                    ),
                  ),
                ]),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          if (widget.streak != null && widget.streak!.current > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                color: AppColors.streak.withValues(alpha: 0.12),
                child: ListTile(
                  leading: const Icon(Icons.local_fire_department,
                      color: AppColors.streak, size: 32),
                  title: Text('Chuỗi ${widget.streak!.current} ngày luyện tập!',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Kỷ lục: ${widget.streak!.longest} ngày'),
                ),
              ),
            ),
          // ---- Điểm tổng & thành phần ----
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(children: [
                  ScoreRing(score: r.overall, size: 120, label: 'Tổng điểm'),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(children: [
                      ScoreBar(label: 'Độ chính xác', score: r.accuracy),
                      ScoreBar(label: 'Độ trôi chảy', score: r.fluency),
                      ScoreBar(label: 'Độ đầy đủ', score: r.completeness),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(_verdict,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  r.engine == 'azure'
                      ? 'Chấm bởi Azure AI Pronunciation Assessment'
                      : 'Chấm bởi thuật toán so sánh âm vị (offline)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ]),
            ),
          ),

          // ---- Từng từ ----
          const SectionTitle('Phân tích từng từ'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final w in r.words) _WordChip(word: w),
                  ]),
                  const SizedBox(height: 12),
                  Text('Bấm vào từ để xem chi tiết từng âm.',
                      style: Theme.of(context).textTheme.bodySmall),
                  const Divider(height: 24),
                  Text('Ứng dụng nghe được:',
                      style: Theme.of(context).textTheme.labelLarge),
                  Text(r.recognizedText.isEmpty ? '(không có)' : '"${r.recognizedText}"',
                      style: const TextStyle(fontStyle: FontStyle.italic)),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.volume_up),
                      label: const Text('Nghe mẫu'),
                      onPressed: () => tts.speak(r.referenceText, rate: rate),
                    ),
                    if (widget.audioPath != null)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Nghe lại tôi'),
                        onPressed: () =>
                            _player.play(DeviceFileSource(widget.audioPath!)),
                      ),
                  ]),
                ],
              ),
            ),
          ),

          // ---- Âm cần cải thiện ----
          if (r.errorPhonemes.isNotEmpty) ...[
            const SectionTitle('Âm cần cải thiện'),
            for (final p in r.errorPhonemes.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TipCard(
                  phoneme: p,
                  onSpeak: (w) => tts.speak(w, rate: rate * 0.8),
                ),
              ),
          ],

          // ---- Bài tập gợi ý ----
          if (recs.any((x) => x.items.isNotEmpty)) ...[
            const SectionTitle('Bài tập gợi ý'),
            for (final rec in recs.where((x) => x.items.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          PhonemeChip(rec.phoneme, color: AppColors.bad),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(
                                  'Luyện ${rec.items.length} từ có âm /${ipaOfPhone(rec.phoneme)}/')),
                        ]),
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final it in rec.items) Chip(label: Text(it.text)),
                        ]),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.fitness_center),
                            label: const Text('Luyện ngay'),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PracticeScreen(
                                  title: 'Luyện âm /${ipaOfPhone(rec.phoneme)}/',
                                  items: rec.items,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  const _WordChip({required this.word});
  final WordResult word;

  @override
  Widget build(BuildContext context) {
    final insertion = word.errorType == WordErrorType.insertion;
    final omission = word.errorType == WordErrorType.omission;
    final color = insertion
        ? Theme.of(context).colorScheme.outline
        : AppColors.forScore(word.score);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: insertion ? null : () => _showDetail(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            insertion ? '+${word.word}' : word.word,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
              decoration: omission || insertion ? TextDecoration.lineThrough : null,
            ),
          ),
          Text(
            insertion
                ? 'thừa'
                : omission
                    ? 'bỏ sót'
                    : word.score.round().toString(),
            style: TextStyle(fontSize: 11, color: color),
          ),
        ]),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final expected = word.phonemes.where((p) => !p.isInsertion).toList();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(word.word,
                  style: Theme.of(ctx)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text('Chuẩn: /${wordToIpa([for (final p in expected) p.expected])}/'),
              if (word.recognized != null && word.recognized != word.word)
                Text('Bạn đọc gần giống: "${word.recognized}"'),
              const SizedBox(height: 12),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(),
                  1: FlexColumnWidth(),
                  2: IntrinsicColumnWidth(),
                },
                children: [
                  const TableRow(children: [
                    Padding(padding: EdgeInsets.all(6), child: Text('Âm chuẩn', style: TextStyle(fontWeight: FontWeight.bold))),
                    Padding(padding: EdgeInsets.all(6), child: Text('Bạn phát âm', style: TextStyle(fontWeight: FontWeight.bold))),
                    Padding(padding: EdgeInsets.all(6), child: Text('Điểm', style: TextStyle(fontWeight: FontWeight.bold))),
                  ]),
                  for (final p in word.phonemes)
                    TableRow(children: [
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(p.isInsertion ? '—' : '/${ipaOfPhone(p.expected)}/',
                            style: const TextStyle(fontSize: 16)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          p.actual == null
                              ? '(bỏ sót)'
                              : p.isInsertion
                                  ? '/${ipaOfPhone(p.actual!)}/ (thừa)'
                                  : '/${ipaOfPhone(p.actual!)}/',
                          style: TextStyle(
                              fontSize: 16,
                              color: p.isError ? AppColors.bad : null),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(p.score.round().toString(),
                            style: TextStyle(
                                color: AppColors.forScore(p.score),
                                fontWeight: FontWeight.bold)),
                      ),
                    ]),
                ],
              ),
              for (final p in expected.where((p) => p.isError).map((p) => baseOf(p.expected)).toSet()) ...[
                const SizedBox(height: 8),
                Text('/${ipaOfPhone(p)}/: ${tipFor(p).howTo}'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.phoneme, required this.onSpeak});
  final String phoneme;
  final void Function(String) onSpeak;

  @override
  Widget build(BuildContext context) {
    final tip = tipFor(phoneme);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              PhonemeChip(phoneme, color: AppColors.bad),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(tip.howTo,
                      style: const TextStyle(fontWeight: FontWeight.w500))),
            ]),
            if (tip.commonMistake != null) ...[
              const SizedBox(height: 6),
              Text('Lỗi thường gặp: ${tip.commonMistake}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            if (tip.examples.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: [
                for (final e in tip.examples)
                  ActionChip(
                    avatar: const Icon(Icons.volume_up, size: 16),
                    label: Text(e),
                    onPressed: () => onSpeak(e),
                  ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
