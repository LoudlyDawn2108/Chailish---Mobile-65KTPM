// Model dùng chung cho tiến độ · Phụ trách: Phạm Vũ Ngọc Bảo / Chu Hữu Đệ

import 'pronunciation_result.dart';

class DailyStat {
  const DailyStat({
    required this.date,
    required this.seconds,
    required this.attempts,
    required this.scoreSum,
  });

  /// yyyy-MM-dd
  final String date;
  final int seconds;
  final int attempts;
  final double scoreSum;

  double get minutes => seconds / 60;
  double get avgScore => attempts == 0 ? 0 : scoreSum / attempts;

  factory DailyStat.fromMap(Map<String, Object?> m) => DailyStat(
        date: m['date'] as String,
        seconds: m['seconds'] as int? ?? 0,
        attempts: m['attempts'] as int? ?? 0,
        scoreSum: (m['score_sum'] as num?)?.toDouble() ?? 0,
      );
}

class WeakPhoneme {
  const WeakPhoneme({
    required this.phoneme,
    required this.errorCount,
    required this.totalCount,
    required this.lastSeen,
  });

  final String phoneme;
  final int errorCount;
  final int totalCount;
  final DateTime lastSeen;

  double get errorRate => totalCount == 0 ? 0 : errorCount / totalCount;

  factory WeakPhoneme.fromMap(Map<String, Object?> m) => WeakPhoneme(
        phoneme: m['phoneme'] as String,
        errorCount: m['error_count'] as int? ?? 0,
        totalCount: m['total_count'] as int? ?? 0,
        lastSeen: DateTime.tryParse(m['last_seen'] as String? ?? '') ??
            DateTime.now(),
      );
}

class AttemptRecord {
  const AttemptRecord({
    required this.id,
    required this.itemId,
    required this.referenceText,
    required this.recognizedText,
    required this.overall,
    required this.accuracy,
    required this.fluency,
    required this.completeness,
    required this.engine,
    required this.audioPath,
    required this.createdAt,
    required this.result,
  });

  final int id;
  final String? itemId;
  final String referenceText;
  final String recognizedText;
  final double overall;
  final double accuracy;
  final double fluency;
  final double completeness;
  final String engine;
  final String? audioPath;
  final DateTime createdAt;
  final PronunciationResult result;
}

/// Tiến độ một bài học của người dùng.
class LessonProgress {
  const LessonProgress({required this.practicedItems, required this.bestAvg});
  final int practicedItems;
  final double bestAvg;
}
