// Module M3 – Chi tiết bài học · Phụ trách: Đinh Thị Hoa

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models/lesson.dart';
import '../../core/providers.dart';
import '../../core/widgets/common_widgets.dart';
import '../feedback/phoneme_tips.dart';
import '../recording/practice_screen.dart';

class LessonDetailScreen extends ConsumerWidget {
  const LessonDetailScreen({super.key, required this.lessonId});
  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessons = ref.watch(lessonsProvider).value ?? const [];
    final lesson = lessons.where((l) => l.id == lessonId).firstOrNull;
    final best = ref.watch(bestScoresProvider).value ?? const {};
    if (lesson == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    void practice(int start) => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PracticeScreen(
            title: lesson.title,
            items: lesson.items,
            startIndex: start,
            lessonId: lesson.id,
          ),
        ));

    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.mic),
        label: const Text('Bắt đầu luyện'),
        onPressed: () {
          // Bắt đầu từ mục đầu tiên chưa luyện.
          final i = lesson.items.indexWhere((it) => !best.containsKey(it.id));
          practice(i < 0 ? 0 : i);
        },
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${Lesson.levelName(lesson.level)} · ${lesson.topic}',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Text(lesson.description),
                  for (final f in lesson.focus) ...[
                    const SizedBox(height: 10),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      PhonemeChip(f),
                      const SizedBox(width: 10),
                      Expanded(child: Text(tipFor(f).howTo)),
                    ]),
                  ],
                ],
              ),
            ),
          ),
          const SectionTitle('Danh sách từ / câu'),
          for (final (i, it) in lesson.items.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  onTap: () => practice(i),
                  title: Text(it.text,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 17)),
                  subtitle: Text('${it.ipa}\n${it.meaning}'),
                  isThreeLine: true,
                  trailing: best.containsKey(it.id)
                      ? CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              AppColors.forScore(best[it.id]!).withValues(alpha: 0.15),
                          child: Text(best[it.id]!.round().toString(),
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.forScore(best[it.id]!))),
                        )
                      : const Icon(Icons.mic_none),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
