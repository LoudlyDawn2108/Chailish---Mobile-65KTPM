import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/ai_chat_repository.dart';
import '../../data/models/ai_chat_models.dart';
import '../widgets/chat_bubbles.dart' show hanziFontFallback, scoreColor;
import '../widgets/grammar_analysis_view.dart';

/// Kết thúc phiên (server tổng kết và lưu vào lịch sử ôn tập) rồi trả về phiên đầy đủ.
final finishedConversationProvider =
    FutureProvider.autoDispose.family<AiConversation, String>((ref, conversationId) {
  return ref.watch(aiChatRepositoryProvider).finishConversation(conversationId);
});

/// Màn hình tổng kết sau phiên trò chuyện với AI.
class AiChatSummaryScreen extends ConsumerWidget {
  final String conversationId;
  final VoidCallback? onPracticeAgain;

  const AiChatSummaryScreen({super.key, required this.conversationId, this.onPracticeAgain});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(finishedConversationProvider(conversationId));
    return Scaffold(
      appBar: AppBar(title: const Text('Tổng kết phiên ôn bài')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.primary),
                const SizedBox(height: 12),
                Text(
                  error is ApiException ? error.message : 'Không tải được tổng kết. Vui lòng thử lại.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(finishedConversationProvider(conversationId)),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
        data: (conv) => _SummaryBody(conversation: conv, onPracticeAgain: onPracticeAgain),
      ),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  final AiConversation conversation;
  final VoidCallback? onPracticeAgain;

  const _SummaryBody({required this.conversation, this.onPracticeAgain});

  @override
  Widget build(BuildContext context) {
    final summary = conversation.summary;
    final theme = Theme.of(context);
    final answers = conversation.messages.where((m) => !m.isAssistant).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ScoreRing(key: const Key('summary-score'), score: summary?.overallScore ?? 0, size: 88),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Điểm tổng kết', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 4),
                      Text(summary?.commentVi ?? '', key: const Key('summary-comment')),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _Stat(icon: Icons.forum_outlined, label: '${summary?.turns ?? 0} lượt'),
                          _Stat(
                            icon: Icons.check_circle_outline,
                            label: '${summary?.correctSentences ?? 0} câu đúng',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (summary != null && summary.errorCounts.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Lỗi hay gặp', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _ErrorCounts(counts: summary.errorCounts),
        ],
        if (summary != null && summary.topErrors.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Các lỗi cần lưu ý', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final e in summary.topErrors) _TopErrorTile(error: e),
        ],
        if (summary != null && summary.grammarPointsToReview.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Điểm ngữ pháp nên ôn lại', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final gp in summary.grammarPointsToReview)
                Chip(avatar: const Icon(Icons.menu_book_outlined, size: 18), label: Text(gp)),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Text('Lịch sử câu trả lời', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          'Đã lưu vào lịch sử ôn tập. Chạm vào một câu để xem phân tích chi tiết.',
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondaryLight),
        ),
        const SizedBox(height: 8),
        if (answers.isEmpty) const Text('Bạn chưa trả lời câu nào trong phiên này.'),
        for (final m in answers)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              key: Key('answer-${m.id}'),
              title: Text(m.content, style: const TextStyle(fontSize: 18, fontFamilyFallback: hanziFontFallback)),
              subtitle: m.grammarFeedback == null
                  ? const Text('Chưa có phân tích')
                  : Text(
                      m.grammarFeedback!.isCorrect
                          ? 'Chính xác'
                          : 'Sửa: ${m.grammarFeedback!.correctedSentence ?? ''}',
                    ),
              trailing: m.grammarFeedback == null
                  ? null
                  : Text(
                      '${m.grammarFeedback!.score}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: scoreColor(m.grammarFeedback!.score),
                      ),
                    ),
              onTap: m.grammarFeedback == null
                  ? null
                  : () => showGrammarAnalysisSheet(context, m.grammarFeedback!),
            ),
          ),
        const SizedBox(height: 16),
        if (onPracticeAgain != null)
          OutlinedButton.icon(
            onPressed: onPracticeAgain,
            icon: const Icon(Icons.replay),
            label: const Text('Luyện thêm một phiên'),
          ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Hoàn thành'),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Stat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondaryLight),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}

class _ErrorCounts extends StatelessWidget {
  final Map<String, int> counts;

  const _ErrorCounts({required this.counts});

  @override
  Widget build(BuildContext context) {
    final max = counts.values.fold<int>(1, (a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final entry in counts.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(width: 150, child: Text(entry.key, overflow: TextOverflow.ellipsis)),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: entry.value / max,
                      minHeight: 10,
                      color: AppColors.warningOrange,
                      backgroundColor: AppColors.dividerLight,
                    ),
                  ),
                ),
                SizedBox(width: 32, child: Text('${entry.value}', textAlign: TextAlign.end)),
              ],
            ),
          ),
      ],
    );
  }
}

class _TopErrorTile extends StatelessWidget {
  final Map<String, dynamic> error;

  const _TopErrorTile({required this.error});

  @override
  Widget build(BuildContext context) {
    const hanzi = TextStyle(fontSize: 16, fontFamilyFallback: hanziFontFallback);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (error['label_vi'] as String?) ?? 'Lỗi',
              style: const TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(error['sentence'] as String? ?? '', style: hanzi),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  error['span'] as String? ?? '',
                  style: hanzi.copyWith(color: AppColors.errorRed, decoration: TextDecoration.lineThrough),
                ),
                const Icon(Icons.arrow_forward, size: 16),
                Text(
                  error['correction'] as String? ?? '',
                  style: hanzi.copyWith(color: AppColors.jadeGreen, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if ((error['explanation_vi'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(error['explanation_vi'] as String),
            ],
          ],
        ),
      ),
    );
  }
}
