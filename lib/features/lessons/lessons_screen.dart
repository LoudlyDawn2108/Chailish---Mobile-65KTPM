// Module M3 – Danh sách bài học · Phụ trách: Đinh Thị Hoa

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models/lesson.dart';
import '../../core/providers.dart';
import '../../core/widgets/common_widgets.dart';
import 'lesson_detail_screen.dart';

class LessonsScreen extends ConsumerWidget {
  const LessonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessons = ref.watch(lessonsProvider);
    final best = ref.watch(bestScoresProvider).value ?? const {};
    return Scaffold(
      appBar: AppBar(title: const Text('Bài học')),
      body: lessons.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(e),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            for (final level in [1, 2, 3]) ...[
              SectionTitle('Cấp độ ${Lesson.levelName(level)}'),
              for (final l in list.where((l) => l.level == level))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: LessonCard(lesson: l, best: best),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class LessonCard extends StatelessWidget {
  const LessonCard({super.key, required this.lesson, required this.best});
  final Lesson lesson;
  final Map<String, double> best;

  @override
  Widget build(BuildContext context) {
    final done = lesson.items.where((i) => best.containsKey(i.id)).toList();
    final progress = lesson.items.isEmpty ? 0.0 : done.length / lesson.items.length;
    final avg = done.isEmpty
        ? null
        : done.map((i) => best[i.id]!).reduce((a, b) => a + b) / done.length;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => LessonDetailScreen(lessonId: lesson.id))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(_iconFor(lesson), color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lesson.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${lesson.topic} · ${lesson.items.length} mục',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                if (avg != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.forScore(avg).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(avg.round().toString(),
                        style: TextStyle(
                            color: AppColors.forScore(avg),
                            fontWeight: FontWeight.bold)),
                  ),
              ]),
              if (lesson.focus.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final f in lesson.focus) PhonemeChip(f),
                ]),
              ],
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: progress, minHeight: 6),
              ),
              const SizedBox(height: 4),
              Text('Đã luyện ${done.length}/${lesson.items.length}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(Lesson l) => switch (l.topic) {
        'Giao tiếp' => Icons.waving_hand,
        'Âm khó' => Icons.graphic_eq,
        'Câu' => Icons.short_text,
        _ => Icons.abc,
      };
}
