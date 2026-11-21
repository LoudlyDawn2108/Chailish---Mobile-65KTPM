import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/ai_chat_controller.dart';
import '../../data/chat_voice_services.dart';
import '../widgets/chat_bubbles.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/grammar_analysis_view.dart';
import 'ai_chat_summary_screen.dart';

/// Màn hình trò chuyện ôn bài cùng trợ lý AI sau mỗi bài học.
class AiChatScreen extends ConsumerStatefulWidget {
  final int lessonId;
  final String? lessonTitle;

  const AiChatScreen({super.key, required this.lessonId, this.lessonTitle});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _listening = false;
  bool _usedVoice = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(aiChatControllerProvider.notifier).start(widget.lessonId));
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    if (_listening) await _toggleMic();
    final method = _usedVoice ? 'voice' : 'text';
    _input.clear();
    _usedVoice = false;
    await ref.read(aiChatControllerProvider.notifier).send(text, inputMethod: method);
  }

  Future<void> _toggleMic() async {
    final speech = ref.read(chatSpeechInputProvider);
    if (_listening) {
      await speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!await speech.initialize()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không dùng được micro. Hãy cấp quyền ghi âm cho ứng dụng.')),
      );
      return;
    }
    setState(() => _listening = true);
    await speech.listen(onResult: (text, isFinal) {
      if (!mounted) return;
      _input.text = text;
      _input.selection = TextSelection.collapsed(offset: text.length);
      _usedVoice = true;
      if (isFinal) setState(() => _listening = false);
    });
  }

  Future<void> _openSummary() async {
    final conversationId = ref.read(aiChatControllerProvider).conversationId;
    if (conversationId == null) return;
    final controller = ref.read(aiChatControllerProvider.notifier);
    controller.markFinished();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AiChatSummaryScreen(
          conversationId: conversationId,
          onPracticeAgain: () {
            Navigator.of(context).pop();
            controller.start(widget.lessonId);
          },
        ),
      ),
    );
  }

  Future<void> _confirmFinishEarly() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kết thúc phiên?'),
        content: const Text('Bạn muốn dừng trò chuyện và xem tổng kết ngay bây giờ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Tiếp tục')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kết thúc')),
        ],
      ),
    );
    if (ok == true) await _openSummary();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiChatControllerProvider);
    final controller = ref.read(aiChatControllerProvider.notifier);
    final tts = ref.read(chatTtsProvider);

    ref.listen(aiChatControllerProvider, (prev, next) {
      if (prev?.bubbles.length != next.bubbles.length ||
          (next.bubbles.isNotEmpty && prev?.bubbles.last.text != next.bubbles.last.text)) {
        _scrollToBottom();
      }
      final error = next.errorMessage;
      if (error != null && error != prev?.errorMessage && next.phase != ChatPhase.startFailed) {
        if (next.failedInput != null && _input.text.isEmpty) {
          _input.text = next.failedInput!;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        controller.clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('Ôn bài cùng AI'),
            if (widget.lessonTitle != null)
              Text(widget.lessonTitle!, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
        actions: [
          if (state.phase == ChatPhase.ready && state.turnCount > 0)
            IconButton(
              key: const Key('finish-early'),
              tooltip: 'Kết thúc & tổng kết',
              icon: const Icon(Icons.flag_outlined),
              onPressed: _confirmFinishEarly,
            ),
        ],
        bottom: state.conversationId == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: _TurnProgress(turnCount: state.turnCount, maxTurns: state.maxTurns),
              ),
      ),
      body: switch (state.phase) {
        ChatPhase.starting => const _CenteredStatus(
            key: Key('chat-starting'),
            icon: Icons.smart_toy_outlined,
            message: 'Trợ lý AI đang chuẩn bị cuộc trò chuyện theo bài học...',
            loading: true,
          ),
        ChatPhase.startFailed => _CenteredStatus(
            key: const Key('chat-start-failed'),
            icon: Icons.cloud_off_outlined,
            message: state.errorMessage ?? 'Không bắt đầu được phiên trò chuyện.',
            actionLabel: 'Thử lại',
            onAction: controller.retryStart,
          ),
        _ => Column(
            children: [
              if (state.disclaimer.isNotEmpty) _Disclaimer(text: state.disclaimer),
              Expanded(
                child: ListView.separated(
                  key: const Key('chat-list'),
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: state.bubbles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final bubble = state.bubbles[index];
                    if (bubble.isAssistant) {
                      return AssistantBubble(
                        bubble: bubble,
                        showTranslation: state.revealedTranslations.contains(bubble.id),
                        onToggleTranslation: () => controller.toggleTranslation(bubble.id),
                        onSpeak: () => tts.speak(bubble.text),
                        onSpeakSlow: () => tts.speak(bubble.text, slow: true),
                      );
                    }
                    return UserBubble(
                      bubble: bubble,
                      onOpenGrammar: bubble.grammar == null
                          ? null
                          : () => showGrammarAnalysisSheet(context, bubble.grammar!),
                    );
                  },
                ),
              ),
              if (state.phase == ChatPhase.finished)
                _FinishedBanner(onViewSummary: _openSummary)
              else ...[
                SuggestedRepliesBar(
                  suggestions: state.suggestions,
                  onSelected: (s) {
                    _input.text = s.hanzi;
                    _input.selection = TextSelection.collapsed(offset: s.hanzi.length);
                    _usedVoice = false;
                  },
                ),
                ChatInputBar(
                  controller: _input,
                  enabled: state.canSend,
                  isListening: _listening,
                  onSend: _send,
                  onMicPressed: _toggleMic,
                ),
              ],
            ],
          ),
      },
    );
  }
}

class _TurnProgress extends StatelessWidget {
  final int turnCount;
  final int maxTurns;

  const _TurnProgress({required this.turnCount, required this.maxTurns});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Text('Lượt $turnCount/$maxTurns', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: maxTurns == 0 ? 0 : turnCount / maxTurns,
                minHeight: 6,
                color: AppColors.primary,
                backgroundColor: AppColors.dividerLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  final String text;

  const _Disclaimer({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.secondaryLight.withValues(alpha: 0.18),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.secondaryDark),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.labelSmall)),
        ],
      ),
    );
  }
}

class _FinishedBanner extends StatelessWidget {
  final VoidCallback onViewSummary;

  const _FinishedBanner({required this.onViewSummary});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        key: const Key('chat-finished'),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: AppColors.jadeGreen.withValues(alpha: 0.1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Bạn đã hoàn thành phiên trò chuyện! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.jadeGreen),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              key: const Key('view-summary'),
              onPressed: onViewSummary,
              icon: const Icon(Icons.insights_outlined),
              label: const Text('Xem tổng kết'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenteredStatus extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _CenteredStatus({
    super.key,
    required this.icon,
    required this.message,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (loading) const CircularProgressIndicator(),
            if (actionLabel != null)
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel!),
              ),
          ],
        ),
      ),
    );
  }
}
