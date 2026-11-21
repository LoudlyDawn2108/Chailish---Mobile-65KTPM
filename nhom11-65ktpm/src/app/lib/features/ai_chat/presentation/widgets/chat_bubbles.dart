import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/ai_chat_controller.dart';
import 'typing_indicator.dart';

const hanziFontFallback = ['Noto Sans SC', 'PingFang SC', 'Roboto'];

Color scoreColor(int score) {
  if (score >= 85) return AppColors.jadeGreen;
  if (score >= 60) return AppColors.warningOrange;
  return AppColors.errorRed;
}

/// Bong bóng câu nói của trợ lý AI: Hán tự, pinyin, nút nghe, nút bật/tắt nghĩa.
class AssistantBubble extends StatelessWidget {
  final ChatBubble bubble;
  final bool showTranslation;
  final VoidCallback onToggleTranslation;
  final VoidCallback onSpeak;
  final VoidCallback onSpeakSlow;

  const AssistantBubble({
    super.key,
    required this.bubble,
    required this.showTranslation,
    required this.onToggleTranslation,
    required this.onSpeak,
    required this.onSpeakSlow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final waiting = bubble.isStreaming && bubble.text.isEmpty;

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: const Icon(Icons.smart_toy_outlined, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  topLeft: Radius.circular(4),
                ),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
              ),
              child: waiting
                  ? const TypingIndicator(key: Key('ai-typing'))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            text: bubble.text,
                            children: [
                              if (bubble.isStreaming)
                                const TextSpan(
                                  text: ' ▍',
                                  style: TextStyle(color: AppColors.primary),
                                ),
                            ],
                          ),
                          key: Key('ai-hanzi-${bubble.id}'),
                          style: const TextStyle(
                            fontSize: 22,
                            height: 1.4,
                            fontFamilyFallback: hanziFontFallback,
                          ),
                        ),
                        if (!bubble.isStreaming && (bubble.pinyin ?? '').isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            bubble.pinyin!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.primaryDark,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        if (!bubble.isStreaming && showTranslation && bubble.translationVi != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            bubble.translationVi!,
                            key: Key('ai-translation-${bubble.id}'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                        if (!bubble.isStreaming)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _SmallIconButton(
                                key: Key('speak-${bubble.id}'),
                                icon: Icons.volume_up_outlined,
                                tooltip: 'Nghe mẫu',
                                onPressed: onSpeak,
                              ),
                              _SmallIconButton(
                                icon: Icons.slow_motion_video_outlined,
                                tooltip: 'Nghe chậm',
                                onPressed: onSpeakSlow,
                              ),
                              _SmallIconButton(
                                key: Key('translate-${bubble.id}'),
                                icon: showTranslation ? Icons.translate : Icons.g_translate_outlined,
                                tooltip: showTranslation ? 'Ẩn nghĩa tiếng Việt' : 'Hiện nghĩa tiếng Việt',
                                color: showTranslation ? AppColors.primary : null,
                                onPressed: onToggleTranslation,
                              ),
                            ],
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bong bóng câu trả lời của người học kèm kết quả chấm ngữ pháp.
class UserBubble extends StatelessWidget {
  final ChatBubble bubble;
  final VoidCallback? onOpenGrammar;

  const UserBubble({super.key, required this.bubble, this.onOpenGrammar});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (bubble.inputMethod == 'voice') ...[
                  const Icon(Icons.mic, size: 16, color: Colors.white70),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    bubble.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontFamilyFallback: hanziFontFallback,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          GrammarChip(bubble: bubble, onTap: onOpenGrammar),
        ],
      ),
    );
  }
}

/// Nhãn nhỏ dưới câu của người học: đang chấm / điểm ngữ pháp / lỗi.
class GrammarChip extends StatelessWidget {
  final ChatBubble bubble;
  final VoidCallback? onTap;

  const GrammarChip({super.key, required this.bubble, this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium;
    switch (bubble.grammarStatus) {
      case GrammarStatus.none:
        return const SizedBox.shrink();
      case GrammarStatus.pending:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 6),
            Text('Đang phân tích ngữ pháp...', style: style),
          ],
        );
      case GrammarStatus.failed:
        return Text(
          'Chưa phân tích được ngữ pháp câu này',
          style: style?.copyWith(color: AppColors.textSecondaryLight),
        );
      case GrammarStatus.done:
        final g = bubble.grammar!;
        final color = scoreColor(g.score);
        final label = g.isCorrect ? 'Chính xác · ${g.score} điểm' : '${g.errors.length} lỗi · ${g.score} điểm';
        return ActionChip(
          key: Key('grammar-chip-${bubble.id}'),
          avatar: Icon(g.isCorrect ? Icons.check_circle : Icons.error_outline, size: 18, color: color),
          label: Text(label, style: style?.copyWith(color: color, fontWeight: FontWeight.w600)),
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          backgroundColor: color.withValues(alpha: 0.08),
          visualDensity: VisualDensity.compact,
          onPressed: onTap,
        );
    }
  }
}

class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  const _SmallIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20, color: color ?? AppColors.textSecondaryLight),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }
}
