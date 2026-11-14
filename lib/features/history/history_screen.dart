// Module M4 – Lịch sử luyện tập · Phụ trách: Chu Hữu Đệ

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/providers.dart';
import '../../core/widgets/common_widgets.dart';
import '../feedback/feedback_screen.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử luyện tập')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(e),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
                icon: Icons.history, text: 'Chưa có lần luyện nào.');
          }
          final fmtDay = DateFormat('EEEE, dd/MM/yyyy', 'vi');
          final fmtTime = DateFormat('HH:mm');
          String? lastDay;
          final children = <Widget>[];
          for (final a in list) {
            final day = fmtDay.format(a.createdAt);
            if (day != lastDay) {
              children.add(SectionTitle(day));
              lastDay = day;
            }
            children.add(Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        AppColors.forScore(a.overall).withValues(alpha: 0.15),
                    child: Text(a.overall.round().toString(),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.forScore(a.overall))),
                  ),
                  title: Text(a.referenceText,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${fmtTime.format(a.createdAt)} · nghe được: "${a.recognizedText}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  trailing: Icon(
                      a.engine == 'azure' ? Icons.cloud_done : Icons.offline_bolt,
                      size: 18),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => FeedbackScreen(
                      result: a.result,
                      audioPath: a.audioPath,
                      readOnly: true,
                    ),
                  )),
                ),
              ),
            ));
          }
          return ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: children);
        },
      ),
    );
  }
}
