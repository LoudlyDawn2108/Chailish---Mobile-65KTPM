// Module M5 – Trang chủ: streak, mục tiêu hôm nay, gợi ý · Phụ trách: Phạm Vũ Ngọc Bảo

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/models/lesson.dart';
import '../../core/providers.dart';
import '../../core/widgets/common_widgets.dart';
import '../history/history_screen.dart';
import '../lessons/lesson_detail_screen.dart';
import '../pronunciation/engine/phonemes.dart';
import '../recording/practice_screen.dart';
import 'streak_calculator.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onOpenTab});
  final void Function(int tab) onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(activeUserProvider);
    if (user == null) return const SizedBox.shrink();
    final streak = ref.watch(streakProvider).value ?? StreakInfo.empty;
    final today = ref.watch(todayStatProvider).value;
    final week = ref.watch(statsProvider(7)).value ?? const [];
    final recs = ref.watch(recommendationsProvider).value ?? const [];
    final lessons = ref.watch(lessonsProvider).value ?? const <Lesson>[];
    final best = ref.watch(bestScoresProvider).value ?? const {};
    final recent = ref.watch(historyProvider).value ?? const [];

    final goalSec = user.dailyGoalMinutes * 60;
    final todaySec = today?.seconds ?? 0;
    final goalProgress = goalSec == 0 ? 0.0 : (todaySec / goalSec).clamp(0.0, 1.0);
    final next = _nextLesson(lessons, best, user.level);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.read(dataVersionProvider.notifier).bump(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Xin chào, ${user.name} 👋',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text(DateFormat('EEEE, dd/MM/yyyy', 'vi').format(DateTime.now())),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 24,
                  child: Text(user.name.characters.first.toUpperCase(),
                      style: const TextStyle(fontSize: 20)),
                ),
              ]),
              const SizedBox(height: 16),

              // ---- Streak + mục tiêu ----
              Row(children: [
                Expanded(child: _StreakCard(streak: streak)),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: Stack(fit: StackFit.expand, children: [
                            CircularProgressIndicator(
                              value: goalProgress,
                              strokeWidth: 8,
                              backgroundColor: scheme.surfaceContainerHighest,
                              color: goalProgress >= 1 ? AppColors.good : scheme.primary,
                            ),
                            Center(
                              child: goalProgress >= 1
                                  ? const Icon(Icons.check, color: AppColors.good, size: 32)
                                  : Text('${(goalProgress * 100).round()}%',
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 8),
                        Text('${todaySec ~/ 60}/${user.dailyGoalMinutes} phút',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Mục tiêu hôm nay',
                            style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              // ---- 7 ngày gần nhất ----
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: Column(children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        for (final d in week)
                          Expanded(
                            child: _DayDot(
                              label: _weekdayShort(parseDateKey(d.date).weekday),
                              practiced: d.attempts > 0,
                              goalMet: d.seconds >= goalSec,
                              isToday: d.date == dateKey(DateTime.now()),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Hôm nay: ${today?.attempts ?? 0} lượt luyện · điểm TB '
                      '${(today?.avgScore ?? 0).round()}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),

              // ---- Luyện tiếp ----
              if (next != null)
                FilledButton.icon(
                  icon: const Icon(Icons.mic),
                  label: Text('Luyện tiếp: ${next.title}'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => LessonDetailScreen(lessonId: next.id))),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.menu_book),
                label: const Text('Xem tất cả bài học'),
                onPressed: () => onOpenTab(1),
              ),

              // ---- Gợi ý theo âm yếu ----
              if (recs.isNotEmpty) ...[
                const SectionTitle('Âm bạn hay phát âm sai'),
                for (final r in recs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        leading: PhonemeChip(r.phoneme, color: AppColors.bad),
                        title: Text('Sai ${(r.errorRate * 100).round()}% số lần'),
                        subtitle: Text(r.items.map((i) => i.text).take(4).join(', ')),
                        trailing: const Icon(Icons.play_circle_fill, size: 32),
                        onTap: r.items.isEmpty
                            ? null
                            : () => Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => PracticeScreen(
                                    title: 'Luyện âm /${ipaOfPhone(r.phoneme)}/',
                                    items: r.items,
                                  ),
                                )),
                      ),
                    ),
                  ),
              ],

              // ---- Gần đây ----
              if (recent.isNotEmpty) ...[
                SectionTitle('Luyện gần đây',
                    trailing: TextButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const HistoryScreen())),
                      child: const Text('Xem tất cả'),
                    )),
                for (final a in recent.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        title: Text(a.referenceText),
                        subtitle: Text(DateFormat('HH:mm dd/MM').format(a.createdAt)),
                        trailing: Text(a.overall.round().toString(),
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.forScore(a.overall))),
                      ),
                    ),
                  ),
              ],
              if (recent.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: EmptyState(
                    icon: Icons.record_voice_over_outlined,
                    text: 'Bạn chưa luyện lần nào.\nHãy bắt đầu với bài "Chào hỏi cơ bản"!',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bài tiếp theo: bài chưa luyện hết, ưu tiên đúng trình độ người dùng.
  static Lesson? _nextLesson(List<Lesson> lessons, Map<String, double> best, int level) {
    bool unfinished(Lesson l) => l.items.any((i) => !best.containsKey(i.id));
    return lessons.where((l) => l.level == level && unfinished(l)).firstOrNull ??
        lessons.where(unfinished).firstOrNull ??
        lessons.firstOrNull;
  }
}

String _weekdayShort(int weekday) =>
    weekday == DateTime.sunday ? 'CN' : 'T${weekday + 1}';

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});
  final StreakInfo streak;

  @override
  Widget build(BuildContext context) {
    final active = streak.practicedToday;
    return Card(
      color: AppColors.streak.withValues(alpha: active ? 0.15 : 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Icon(Icons.local_fire_department,
              size: 56,
              color: active ? AppColors.streak : AppColors.streak.withValues(alpha: 0.4)),
          Text('${streak.current} ngày',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(
            streak.atRisk
                ? 'Luyện ngay để giữ chuỗi!'
                : 'Kỷ lục: ${streak.longest} ngày',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: streak.atRisk ? AppColors.bad : null,
                fontWeight: streak.atRisk ? FontWeight.bold : null),
          ),
        ]),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.label,
    required this.practiced,
    required this.goalMet,
    required this.isToday,
  });
  final String label;
  final bool practiced;
  final bool goalMet;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = goalMet
        ? AppColors.good
        : practiced
            ? AppColors.streak
            : scheme.surfaceContainerHighest;
    return Column(children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isToday ? Border.all(color: scheme.primary, width: 2) : null,
        ),
        child: practiced
            ? const Icon(Icons.local_fire_department, size: 18, color: Colors.white)
            : null,
      ),
      const SizedBox(height: 4),
      FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
    ]);
  }
}
