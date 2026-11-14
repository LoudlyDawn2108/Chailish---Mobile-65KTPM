// Module M5 – Theo dõi tiến độ · Phụ trách: Phạm Vũ Ngọc Bảo
//
// Tính chuỗi ngày luyện tập liên tiếp (streak). Dart thuần để unit test.

/// Khoá ngày dạng yyyy-MM-dd theo giờ địa phương.
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Đổi khoá ngày về DateTime UTC (tránh lỗi đổi giờ mùa hè khi cộng ngày).
DateTime parseDateKey(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime.utc(p[0], p[1], p[2]);
}

DateTime _utcDay(DateTime local) =>
    DateTime.utc(local.year, local.month, local.day);

class StreakInfo {
  const StreakInfo({
    required this.current,
    required this.longest,
    required this.practicedToday,
    required this.lastPracticeDate,
  });

  final int current;
  final int longest;
  final bool practicedToday;
  final String? lastPracticeDate;

  /// Có streak nhưng hôm nay chưa luyện -> sắp mất streak.
  bool get atRisk => current > 0 && !practicedToday;

  static const empty = StreakInfo(
      current: 0, longest: 0, practicedToday: false, lastPracticeDate: null);
}

/// [practiceDays]: tập khoá ngày (yyyy-MM-dd) có ít nhất 1 lần luyện.
/// Streak hiện tại vẫn được giữ nếu hôm qua có luyện mà hôm nay chưa.
StreakInfo computeStreak(Iterable<String> practiceDays, DateTime now) {
  final days = practiceDays.map(parseDateKey).toSet().toList()..sort();
  if (days.isEmpty) return StreakInfo.empty;

  // Chuỗi dài nhất.
  var longest = 1, run = 1;
  for (var i = 1; i < days.length; i++) {
    final gap = days[i].difference(days[i - 1]).inDays;
    run = gap == 1 ? run + 1 : 1;
    if (run > longest) longest = run;
  }

  final today = _utcDay(now);
  final set = days.toSet();
  final practicedToday = set.contains(today);
  var cursor = practicedToday ? today : today.subtract(const Duration(days: 1));
  var current = 0;
  while (set.contains(cursor)) {
    current++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return StreakInfo(
    current: current,
    longest: longest < current ? current : longest,
    practicedToday: practicedToday,
    lastPracticeDate: dateKey(days.last),
  );
}
