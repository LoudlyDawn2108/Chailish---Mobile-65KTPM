import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/ai_chat_models.dart';
import 'chat_bubbles.dart' show hanziFontFallback, scoreColor;

/// Nhãn tiếng Việt cho loại lỗi ngữ pháp (khớp `error_type` của server).
const grammarErrorLabels = {
  'word_order': 'Sai trật tự từ',
  'measure_word': 'Sai / thiếu lượng từ',
  'missing_le': 'Thiếu 了',
  'bu_mei_confusion': 'Nhầm 不 / 没',
  'missing_particle': 'Thiếu trợ từ',
  'wrong_word': 'Dùng sai từ',
  'verb_usage': 'Dùng sai động từ',
  'adverb_usage': 'Dùng sai phó từ',
  'missing_component': 'Thiếu thành phần câu',
  'redundant_word': 'Thừa từ',
  'other': 'Lỗi khác',
};

/// Màu cho từng thành phần câu để người học nhận ra cấu trúc.
const componentColors = {
  'subject': Color(0xFF1565C0), // chủ ngữ - xanh dương
  'predicate': Color(0xFFD32F2F), // vị ngữ - đỏ
  'object': Color(0xFF2E7D32), // tân ngữ - xanh lá
  'adverbial': Color(0xFF6A1B9A), // trạng ngữ - tím
  'attributive': Color(0xFF00838F), // định ngữ
  'complement': Color(0xFFEF6C00), // bổ ngữ
  'measure_word': Color(0xFFAD1457), // lượng từ
  'particle': Color(0xFF5D4037), // trợ từ
  'other': Color(0xFF616161),
};

/// Mở bảng phân tích ngữ pháp chi tiết của một câu trả lời.
Future<void> showGrammarAnalysisSheet(BuildContext context, GrammarFeedback feedback) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => GrammarAnalysisView(
        feedback: feedback,
        scrollController: scrollController,
      ),
    ),
  );
}

class GrammarAnalysisView extends StatelessWidget {
  final GrammarFeedback feedback;
  final ScrollController? scrollController;

  const GrammarAnalysisView({super.key, required this.feedback, this.scrollController});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text('Phân tích ngữ pháp', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _ScoreHeader(feedback: feedback),
        const SizedBox(height: 20),
        _SectionTitle('So sánh câu', icon: Icons.compare_arrows),
        _SentenceComparison(feedback: feedback),
        if (feedback.components.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionTitle('Thành phần câu', icon: Icons.account_tree_outlined),
          _ComponentBreakdown(components: feedback.components),
        ],
        const SizedBox(height: 20),
        _SectionTitle(
          feedback.errors.isEmpty ? 'Không có lỗi' : 'Lỗi cần sửa (${feedback.errors.length})',
          icon: feedback.errors.isEmpty ? Icons.verified_outlined : Icons.rule,
        ),
        if (feedback.errors.isEmpty)
          const Text('Câu của bạn đúng ngữ pháp. Tuyệt vời! 🎉')
        else
          for (var i = 0; i < feedback.errors.length; i++)
            _ErrorCard(key: Key('grammar-error-$i'), error: feedback.errors[i]),
        const SizedBox(height: 16),
        Text(
          'Phân tích do AI tạo ra và có thể chưa hoàn toàn chính xác.',
          style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondaryLight),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final IconData icon;

  const _SectionTitle(this.text, {required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class ScoreRing extends StatelessWidget {
  final double score;
  final double size;

  const ScoreRing({super.key, required this.score, this.size = 72});

  @override
  Widget build(BuildContext context) {
    final color = scoreColor(score.round());
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: (score / 100).clamp(0, 1),
              strokeWidth: size / 10,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
          Text(
            score.toStringAsFixed(score.truncateToDouble() == score ? 0 : 1),
            style: TextStyle(fontSize: size / 3.2, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  final GrammarFeedback feedback;

  const _ScoreHeader({required this.feedback});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ScoreRing(score: feedback.score.toDouble()),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                feedback.isCorrect ? 'Câu chính xác' : 'Cần chỉnh sửa',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: scoreColor(feedback.score),
                ),
              ),
              if ((feedback.overallCommentVi ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(feedback.overallCommentVi!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Đặt câu của người học (tô đỏ đoạn sai) cạnh câu chuẩn do AI đề xuất.
class _SentenceComparison extends StatelessWidget {
  final GrammarFeedback feedback;

  const _SentenceComparison({required this.feedback});

  List<TextSpan> _highlight(String sentence, List<String> spans) {
    final ranges = <(int, int)>[];
    for (final span in spans.where((s) => s.isNotEmpty)) {
      final start = sentence.indexOf(span);
      if (start >= 0) ranges.add((start, start + span.length));
    }
    ranges.sort((a, b) => a.$1.compareTo(b.$1));

    final result = <TextSpan>[];
    var cursor = 0;
    for (final (start, end) in ranges) {
      if (start < cursor) continue; // bỏ đoạn chồng lấn
      if (start > cursor) result.add(TextSpan(text: sentence.substring(cursor, start)));
      result.add(TextSpan(
        text: sentence.substring(start, end),
        style: const TextStyle(
          color: AppColors.errorRed,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.errorRed,
          decorationStyle: TextDecorationStyle.wavy,
        ),
      ));
      cursor = end;
    }
    if (cursor < sentence.length) result.add(TextSpan(text: sentence.substring(cursor)));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    const hanzi = TextStyle(fontSize: 22, fontFamilyFallback: hanziFontFallback, color: AppColors.textPrimaryLight);
    return Column(
      children: [
        _ComparisonRow(
          label: 'Câu của bạn',
          color: feedback.isCorrect ? AppColors.jadeGreen : AppColors.errorRed,
          icon: feedback.isCorrect ? Icons.check : Icons.close,
          child: Text.rich(
            TextSpan(style: hanzi, children: _highlight(feedback.originalSentence, [for (final e in feedback.errors) e.span])),
            key: const Key('original-sentence'),
          ),
        ),
        const SizedBox(height: 8),
        _ComparisonRow(
          label: 'Câu chuẩn',
          color: AppColors.jadeGreen,
          icon: Icons.check,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(feedback.correctedSentence ?? feedback.originalSentence, key: const Key('corrected-sentence'), style: hanzi),
              if ((feedback.correctedPinyin ?? '').isNotEmpty)
                Text(
                  feedback.correctedPinyin!,
                  style: const TextStyle(fontStyle: FontStyle.italic, color: AppColors.primaryDark),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final Widget child;

  const _ComparisonRow({required this.label, required this.color, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

/// Bóc tách câu thành các khối màu: Hán tự + pinyin + tên thành phần.
class _ComponentBreakdown extends StatelessWidget {
  final List<SentenceComponent> components;

  const _ComponentBreakdown({required this.components});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 8,
      children: [
        for (final c in components)
          Container(
            key: Key('component-${c.role}-${c.text}'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (componentColors[c.role] ?? componentColors['other']!).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border(
                bottom: BorderSide(color: componentColors[c.role] ?? componentColors['other']!, width: 3),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(c.pinyin, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                Text(c.text, style: const TextStyle(fontSize: 20, fontFamilyFallback: hanziFontFallback)),
                Text(
                  c.labelVi,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: componentColors[c.role] ?? componentColors['other'],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final GrammarErrorItem error;

  const _ErrorCard({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    const hanzi = TextStyle(fontSize: 18, fontFamilyFallback: hanziFontFallback);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(grammarErrorLabels[error.errorType] ?? grammarErrorLabels['other']!),
                  labelStyle: const TextStyle(color: AppColors.errorRed, fontSize: 12, fontWeight: FontWeight.w600),
                  backgroundColor: AppColors.errorRed.withValues(alpha: 0.08),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                if (error.grammarPointId != null)
                  Text(
                    'Điểm NP: ${error.grammarPointId}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondaryLight),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                  error.span,
                  style: hanzi.copyWith(
                    color: AppColors.errorRed,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const Icon(Icons.arrow_forward, size: 18, color: AppColors.textSecondaryLight),
                Text(error.correction, style: hanzi.copyWith(color: AppColors.jadeGreen, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            Text(error.explanationVi),
          ],
        ),
      ),
    );
  }
}
