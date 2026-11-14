// Module M3 – Đề xuất bài tập cải thiện · Phụ trách: Đinh Thị Hoa
//
// Dựa vào các âm vị người dùng hay sai để chọn bài học / từ cần luyện thêm.

import '../../core/models/lesson.dart';
import '../../core/models/progress_models.dart';

class PhonemeRecommendation {
  const PhonemeRecommendation({
    required this.phoneme,
    required this.errorRate,
    required this.lessons,
    required this.items,
  });

  final String phoneme;
  final double errorRate;

  /// Bài học có âm này là trọng tâm.
  final List<Lesson> lessons;

  /// Các từ/câu chứa âm này (ưu tiên từ đơn, ngắn).
  final List<LessonItem> items;
}

/// Gợi ý theo lịch sử dài hạn (bảng weak_phonemes).
List<PhonemeRecommendation> recommendFromHistory(
  List<WeakPhoneme> weak,
  List<Lesson> lessons, {
  int minSamples = 3,
  double minErrorRate = 0.2,
  int maxPhonemes = 3,
  int itemsPerPhoneme = 6,
}) {
  final candidates = weak
      .where((w) => w.totalCount >= minSamples && w.errorRate >= minErrorRate)
      .toList()
    ..sort((a, b) {
      final c = b.errorRate.compareTo(a.errorRate);
      return c != 0 ? c : b.errorCount.compareTo(a.errorCount);
    });
  return [
    for (final w in candidates.take(maxPhonemes))
      _build(w.phoneme, w.errorRate, lessons, itemsPerPhoneme, const {}),
  ];
}

/// Gợi ý ngay sau một lần luyện, dựa vào các âm vừa phát âm sai.
List<PhonemeRecommendation> recommendFromErrors(
  List<String> errorPhonemes,
  List<Lesson> lessons, {
  String? excludeItemId,
  int maxPhonemes = 3,
  int itemsPerPhoneme = 5,
}) {
  return [
    for (final p in errorPhonemes.take(maxPhonemes))
      _build(p, 1, lessons, itemsPerPhoneme,
          {?excludeItemId}),
  ];
}

PhonemeRecommendation _build(String phoneme, double rate, List<Lesson> lessons,
    int maxItems, Set<String> exclude) {
  final focusLessons =
      lessons.where((l) => l.focus.contains(phoneme)).toList();
  final items = <LessonItem>[];
  final seenText = <String>{};
  // Ưu tiên: mục trong bài trọng tâm, rồi từ đơn, rồi câu.
  final pool = [
    for (final l in focusLessons) ...l.items,
    for (final l in lessons)
      for (final i in l.items)
        if (i.type == 'word') i,
    for (final l in lessons)
      for (final i in l.items)
        if (i.type != 'word') i,
  ];
  for (final i in pool) {
    if (items.length >= maxItems) break;
    if (exclude.contains(i.id)) continue;
    if (!i.phonemeSet.contains(phoneme)) continue;
    if (!seenText.add(i.text.toLowerCase())) continue;
    items.add(i);
  }
  return PhonemeRecommendation(
    phoneme: phoneme,
    errorRate: rate,
    lessons: focusLessons,
    items: items,
  );
}
