import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/ai_chat_models.dart';
import 'chat_bubbles.dart' show hanziFontFallback;

/// Hàng câu trả lời mẫu do AI gợi ý; chạm để điền vào ô nhập.
class SuggestedRepliesBar extends StatelessWidget {
  final List<SuggestedReply> suggestions;
  final ValueChanged<SuggestedReply> onSelected;

  const SuggestedRepliesBar({super.key, required this.suggestions, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 64,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Center(
              child: Tooltip(
                message: 'Câu trả lời mẫu',
                child: Icon(Icons.lightbulb_outline, color: AppColors.secondaryDark),
              ),
            );
          }
          final s = suggestions[index - 1];
          return Tooltip(
            message: s.translationVi,
            child: InkWell(
              key: Key('suggestion-${index - 1}'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelected(s),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.secondary.withValues(alpha: 0.6)),
                  color: AppColors.secondaryLight.withValues(alpha: 0.15),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.hanzi,
                      style: const TextStyle(fontSize: 16, fontFamilyFallback: hanziFontFallback),
                    ),
                    Text(
                      s.pinyin,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondaryLight,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Ô nhập câu trả lời: gõ phím hoặc bấm micro để nói tiếng Trung.
class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool isListening;
  final VoidCallback onSend;
  final VoidCallback onMicPressed;
  final int maxLength;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.enabled,
    required this.isListening,
    required this.onSend,
    required this.onMicPressed,
    this.maxLength = 120,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4))),
        ),
        child: Row(
          children: [
            IconButton.filledTonal(
              key: const Key('mic-button'),
              tooltip: isListening ? 'Dừng nghe' : 'Nói câu trả lời (tiếng Trung)',
              onPressed: enabled ? onMicPressed : null,
              style: isListening
                  ? IconButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white)
                  : null,
              icon: Icon(isListening ? Icons.stop : Icons.mic_none),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const Key('chat-input'),
                controller: controller,
                enabled: enabled,
                maxLength: maxLength,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: const TextStyle(fontSize: 18, fontFamilyFallback: hanziFontFallback),
                decoration: InputDecoration(
                  hintText: isListening ? 'Đang nghe... hãy nói tiếng Trung' : 'Trả lời bằng tiếng Trung...',
                  counterText: '',
                  filled: true,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => IconButton.filled(
                key: const Key('send-button'),
                tooltip: 'Gửi',
                onPressed: enabled && value.text.trim().isNotEmpty ? onSend : null,
                icon: const Icon(Icons.send),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
