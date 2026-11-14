// Module M5 – Thống kê tiến độ học tập · Phụ trách: Phạm Vũ Ngọc Bảo

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models/progress_models.dart';
import '../../core/providers.dart';
import '../../core/widgets/common_widgets.dart';
import '../history/history_screen.dart';
import 'streak_calculator.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(activeUserProvider);
    if (user == null) return const SizedBox.shrink();
    final stats = ref.watch(statsProvider(_days)).value ?? const <DailyStat>[];
    final heat = ref.watch(statsProvider(84)).value ?? const <DailyStat>[];
    final totals = ref.watch(totalsProvider).value;
    final streak = ref.watch(streakProvider).value ?? StreakInfo.empty;
    final weak = ref.watch(weakPhonemesProvider).value ?? const <WeakPhoneme>[];
    final periodSec = stats.fold<int>(0, (s, d) => s + d.seconds);
    final periodDays = stats.where((d) => d.attempts > 0).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tiến độ học tập'),
        actions: [
          IconButton(
            tooltip: 'Lịch sử luyện tập',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.9,
            children: [
              _Tile(Icons.timer, 'Tổng thời gian',
                  formatMinutes(totals?.seconds ?? 0)),
              _Tile(Icons.mic, 'Tổng lượt luyện', '${totals?.attempts ?? 0}'),
              _Tile(Icons.star, 'Điểm trung bình',
                  (totals?.avg ?? 0).round().toString()),
              _Tile(Icons.local_fire_department, 'Streak / kỷ lục',
                  '${streak.current} / ${streak.longest} ngày'),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7 ngày')),
                ButtonSegment(value: 30, label: Text('30 ngày')),
              ],
              selected: {_days},
              onSelectionChanged: (s) => setState(() => _days = s.first),
            ),
          ),
          SectionTitle('Thời gian học (phút)',
              trailing: Text('${formatMinutes(periodSec)} · $periodDays ngày học',
                  style: Theme.of(context).textTheme.bodySmall)),
          _ChartCard(child: _MinutesChart(stats: stats, goal: user.dailyGoalMinutes)),
          const SectionTitle('Điểm phát âm trung bình'),
          _ChartCard(child: _ScoreChart(stats: stats)),
          const SectionTitle('Lịch luyện tập (12 tuần)'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: _Heatmap(stats: heat, goalSec: user.dailyGoalMinutes * 60),
            ),
          ),
          const SectionTitle('Độ chính xác theo âm'),
          if (weak.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Chưa có dữ liệu. Hãy luyện vài bài để xem thống kê.'),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  for (final w in weak.take(10))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        SizedBox(width: 64, child: PhonemeChip(w.phoneme,
                            color: AppColors.forScore(100 - w.errorRate * 100))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: 1 - w.errorRate,
                              minHeight: 10,
                              color: AppColors.forScore(100 - w.errorRate * 100),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 72,
                          child: Text(
                              '${((1 - w.errorRate) * 100).round()}% · ${w.totalCount}',
                              textAlign: TextAlign.right,
                              style: Theme.of(context).textTheme.bodySmall),
                        ),
                      ]),
                    ),
                  const SizedBox(height: 4),
                  Text('Cột phải: tỉ lệ phát âm đúng · số lần gặp âm',
                      style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(value,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ]),
        ),
      );
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
          child: SizedBox(height: 180, child: child),
        ),
      );
}

String _dayLabel(String key, int total) {
  final d = parseDateKey(key);
  return total <= 7 ? '${d.day}/${d.month}' : '${d.day}';
}

class _MinutesChart extends StatelessWidget {
  const _MinutesChart({required this.stats, required this.goal});
  final List<DailyStat> stats;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Trục Y làm tròn theo bước chẵn để không hiện nhãn lẻ như "31.4"
    // đè lên "30" (lỗi tìm thấy khi QA trên thiết bị).
    final raw = [
      goal.toDouble(),
      ...stats.map((s) => s.minutes),
    ].reduce((a, b) => a > b ? a : b) * 1.15;
    final interval = raw <= 20 ? 5.0 : (raw <= 60 ? 10.0 : 30.0);
    final maxY = ((raw / interval).ceil() * interval).clamp(interval, double.infinity);
    final step = stats.length <= 7 ? 1 : 5;
    return BarChart(
      BarChartData(
        maxY: maxY.toDouble(),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(horizontalLines: [
          HorizontalLine(
            y: goal.toDouble(),
            color: AppColors.good,
            strokeWidth: 1.5,
            dashArray: [6, 4],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topLeft,
              style: const TextStyle(color: AppColors.good, fontSize: 11),
              labelResolver: (_) => 'Mục tiêu',
            ),
          ),
        ]),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  interval: interval,
                  getTitlesWidget: (v, meta) => Text(v.toInt().toString(),
                      style: const TextStyle(fontSize: 11)))),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= stats.length || i % step != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_dayLabel(stats[i].date, stats.length),
                      style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (final (i, s) in stats.indexed)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: s.minutes,
                width: stats.length <= 7 ? 18 : 6,
                color: s.minutes >= goal ? AppColors.good : scheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ]),
        ],
      ),
    );
  }
}

class _ScoreChart extends StatelessWidget {
  const _ScoreChart({required this.stats});
  final List<DailyStat> stats;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (final (i, s) in stats.indexed)
        if (s.attempts > 0) FlSpot(i.toDouble(), s.avgScore),
    ];
    if (spots.isEmpty) {
      return const Center(child: Text('Chưa có dữ liệu trong khoảng này'));
    }
    final scheme = Theme.of(context).colorScheme;
    final step = stats.length <= 7 ? 1 : 5;
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        minX: 0,
        maxX: (stats.length - 1).toDouble(),
        gridData: const FlGridData(drawVerticalLine: false, horizontalInterval: 25),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 32, interval: 25)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= stats.length || i % step != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_dayLabel(stats[i].date, stats.length),
                      style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: scheme.primary,
            barWidth: 3,
            belowBarData: BarAreaData(
                show: true, color: scheme.primary.withValues(alpha: 0.12)),
          ),
        ],
      ),
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.stats, required this.goalSec});
  final List<DailyStat> stats;
  final int goalSec;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox(height: 80);
    final scheme = Theme.of(context).colorScheme;
    // Căn cột theo tuần: cột = tuần, hàng = thứ (T2..CN).
    final first = parseDateKey(stats.first.date);
    final offset = first.weekday - 1;
    final cells = <DailyStat?>[...List.filled(offset, null), ...stats];
    final weeks = (cells.length / 7).ceil();
    Color colorFor(DailyStat? s) {
      if (s == null) return Colors.transparent;
      if (s.attempts == 0) return scheme.surfaceContainerHighest;
      if (s.seconds >= goalSec) return AppColors.good;
      return AppColors.good.withValues(alpha: 0.45);
    }

    return Column(children: [
      LayoutBuilder(builder: (context, c) {
        final size = ((c.maxWidth - 24) / weeks).clamp(8.0, 22.0) - 3;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(children: [
              for (final d in ['T2', '', 'T4', '', 'T6', '', 'CN'])
                SizedBox(
                    height: size + 3,
                    width: 24,
                    child: Text(d, style: const TextStyle(fontSize: 9))),
            ]),
            for (var w = 0; w < weeks; w++)
              Column(children: [
                for (var d = 0; d < 7; d++)
                  Container(
                    margin: const EdgeInsets.all(1.5),
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: colorFor(w * 7 + d < cells.length ? cells[w * 7 + d] : null),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ]),
          ],
        );
      }),
      const SizedBox(height: 8),
      Wrap(alignment: WrapAlignment.end, runSpacing: 4, children: [
        _legend(scheme.surfaceContainerHighest, 'Không học'),
        _legend(AppColors.good.withValues(alpha: 0.45), 'Có học'),
        _legend(AppColors.good, 'Đạt mục tiêu'),
      ]),
    ]);
  }

  Widget _legend(Color c, String t) => Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          Text(t, style: const TextStyle(fontSize: 11)),
        ]),
      );
}
