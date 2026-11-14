// Module M4 – Repository truy cập CSDL · Phụ trách: Chu Hữu Đệ

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../features/progress/streak_calculator.dart';
import '../models/lesson.dart';
import '../models/progress_models.dart';
import '../models/pronunciation_result.dart';
import '../models/user_profile.dart';
import 'app_database.dart';

// --------------------------------------------------------------------------
// Người dùng
// --------------------------------------------------------------------------
class UserRepository {
  UserRepository(this._db);
  final AppDatabase _db;
  Database get db => _db.db;

  Future<List<UserProfile>> getAll() async {
    final rows = await db.query('users', orderBy: 'id');
    return rows.map(UserProfile.fromMap).toList();
  }

  Future<UserProfile?> getById(int id) async {
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : UserProfile.fromMap(rows.first);
  }

  Future<UserProfile> insert(UserProfile u) async {
    final id = await db.insert('users', u.toMap()..remove('id'));
    return u.copyWith(id: id);
  }

  Future<void> update(UserProfile u) =>
      db.update('users', u.toMap(), where: 'id = ?', whereArgs: [u.id]);

  /// Xoá người dùng và toàn bộ dữ liệu (ON DELETE CASCADE).
  Future<void> delete(int id) =>
      db.delete('users', where: 'id = ?', whereArgs: [id]);

  /// Xoá lịch sử luyện tập nhưng giữ hồ sơ.
  Future<void> clearHistory(int id) async {
    await db.transaction((txn) async {
      for (final t in ['attempts', 'practice_sessions', 'daily_stats', 'streaks', 'weak_phonemes']) {
        await txn.delete(t, where: 'user_id = ?', whereArgs: [id]);
      }
    });
  }
}

// --------------------------------------------------------------------------
// Bài học
// --------------------------------------------------------------------------
class LessonRepository {
  LessonRepository(this._db);
  final AppDatabase _db;
  Database get db => _db.db;

  /// Nạp dữ liệu bài học từ lessons.json vào CSDL nếu nội dung thay đổi.
  Future<void> seed(String lessonsJson) async {
    final hash = _fnv1a(lessonsJson).toString();
    final meta = await db.query('meta', where: 'key = ?', whereArgs: ['lessons_hash']);
    if (meta.isNotEmpty && meta.first['value'] == hash) return;

    final data = jsonDecode(lessonsJson) as Map<String, dynamic>;
    await db.transaction((txn) async {
      await txn.delete('lesson_items');
      await txn.delete('lessons');
      for (final l in (data['lessons'] as List)) {
        final m = Map<String, dynamic>.from(l as Map);
        await txn.insert('lessons', {
          'id': m['id'],
          'title': m['title'],
          'level': m['level'],
          'topic': m['topic'],
          'focus': (m['focus'] as List).join(','),
          'description': m['description'],
          'sort_order': m['order'],
        });
        var order = 0;
        for (final it in (m['items'] as List)) {
          final i = Map<String, dynamic>.from(it as Map);
          await txn.insert('lesson_items', {
            'id': i['id'],
            'lesson_id': m['id'],
            'text': i['text'],
            'meaning': i['meaning'],
            'type': i['type'],
            'ipa': i['ipa'],
            'phonemes': i['phonemes'],
            'sort_order': order++,
          });
        }
      }
      await txn.insert('meta', {'key': 'lessons_hash', 'value': hash},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<Lesson>> getLessons() async {
    final lessons = await db.query('lessons', orderBy: 'sort_order');
    final items = await db.query('lesson_items', orderBy: 'lesson_id, sort_order');
    final byLesson = <String, List<LessonItem>>{};
    for (final r in items) {
      final it = LessonItem.fromMap(r);
      byLesson.putIfAbsent(it.lessonId, () => []).add(it);
    }
    return [
      for (final l in lessons)
        Lesson(
          id: l['id'] as String,
          title: l['title'] as String,
          level: l['level'] as int,
          topic: l['topic'] as String? ?? '',
          focus: (l['focus'] as String? ?? '')
              .split(',')
              .where((s) => s.isNotEmpty)
              .toList(),
          description: l['description'] as String? ?? '',
          order: l['sort_order'] as int? ?? 0,
          items: byLesson[l['id']] ?? const [],
        ),
    ];
  }

  static int _fnv1a(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
  }
}

// --------------------------------------------------------------------------
// Phiên luyện tập & lần luyện
// --------------------------------------------------------------------------
class AttemptRepository {
  AttemptRepository(this._db);
  final AppDatabase _db;
  Database get db => _db.db;

  Future<int> startSession(int userId, String? lessonId, DateTime at) =>
      db.insert('practice_sessions', {
        'user_id': userId,
        'lesson_id': lessonId,
        'started_at': at.toIso8601String(),
      });

  Future<void> endSession(int sessionId, DateTime at, int durationSec) =>
      db.update(
        'practice_sessions',
        {'ended_at': at.toIso8601String(), 'duration_sec': durationSec},
        where: 'id = ?',
        whereArgs: [sessionId],
      );

  Future<int> saveAttempt({
    required int userId,
    required int? sessionId,
    required String? itemId,
    required PronunciationResult result,
    required String? audioPath,
    required DateTime at,
  }) {
    return db.transaction((txn) async {
      final id = await txn.insert('attempts', {
        'user_id': userId,
        'session_id': sessionId,
        'item_id': itemId,
        'reference_text': result.referenceText,
        'recognized_text': result.recognizedText,
        'audio_path': audioPath,
        'accuracy': result.accuracy,
        'fluency': result.fluency,
        'completeness': result.completeness,
        'overall_score': result.overall,
        'engine': result.engine,
        'result_json': jsonEncode(result.toJson()),
        'created_at': at.toIso8601String(),
      });
      final batch = txn.batch();
      var wi = 0;
      for (final w in result.words) {
        for (final p in w.phonemes) {
          batch.insert('phoneme_results', {
            'attempt_id': id,
            'word_index': wi,
            'word': w.word,
            'expected_phoneme': p.expected,
            'actual_phoneme': p.actual,
            'score': p.score,
            'is_error': p.isError ? 1 : 0,
          });
        }
        wi++;
      }
      await batch.commit(noResult: true);
      return id;
    });
  }

  Future<List<AttemptRecord>> recent(int userId, {int limit = 100, String? itemId}) async {
    final rows = await db.query(
      'attempts',
      where: itemId == null ? 'user_id = ?' : 'user_id = ? AND item_id = ?',
      whereArgs: itemId == null ? [userId] : [userId, itemId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(_toRecord).toList();
  }

  /// Mọi lần luyện của tất cả người dùng (để xuất CSV kiểm thử).
  Future<List<Map<String, Object?>>> exportRows() => db.rawQuery('''
    SELECT a.id, u.name, u.gender, u.accent, u.level, a.item_id,
           a.reference_text, a.recognized_text, a.engine, a.accuracy,
           a.fluency, a.completeness, a.overall_score, a.created_at
    FROM attempts a JOIN users u ON u.id = a.user_id
    ORDER BY a.created_at''');

  /// Điểm cao nhất của từng mục.
  Future<Map<String, double>> bestScoreByItem(int userId) async {
    final rows = await db.rawQuery(
        'SELECT item_id, MAX(overall_score) AS best FROM attempts '
        'WHERE user_id = ? AND item_id IS NOT NULL GROUP BY item_id',
        [userId]);
    return {
      for (final r in rows)
        r['item_id'] as String: (r['best'] as num?)?.toDouble() ?? 0,
    };
  }

  AttemptRecord _toRecord(Map<String, Object?> r) {
    PronunciationResult result;
    try {
      result = PronunciationResult.fromJson(
          jsonDecode(r['result_json'] as String? ?? '{}') as Map<String, dynamic>);
    } catch (_) {
      result = PronunciationResult(
        referenceText: r['reference_text'] as String? ?? '',
        recognizedText: r['recognized_text'] as String? ?? '',
        accuracy: 0, fluency: 0, completeness: 0, overall: 0,
        words: const [], engine: 'offline',
      );
    }
    double d(String k) => (r[k] as num?)?.toDouble() ?? 0;
    return AttemptRecord(
      id: r['id'] as int,
      itemId: r['item_id'] as String?,
      referenceText: r['reference_text'] as String? ?? '',
      recognizedText: r['recognized_text'] as String? ?? '',
      overall: d('overall_score'),
      accuracy: d('accuracy'),
      fluency: d('fluency'),
      completeness: d('completeness'),
      engine: r['engine'] as String? ?? 'offline',
      audioPath: r['audio_path'] as String?,
      createdAt: DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
      result: result,
    );
  }
}

// --------------------------------------------------------------------------
// Tiến độ: thống kê ngày, streak, âm yếu
// --------------------------------------------------------------------------
class ProgressRepository {
  ProgressRepository(this._db);
  final AppDatabase _db;
  Database get db => _db.db;

  Future<void> _ensureDay(DatabaseExecutor ex, int userId, String date) =>
      ex.insert('daily_stats', {'user_id': userId, 'date': date},
          conflictAlgorithm: ConflictAlgorithm.ignore);

  Future<void> addPracticeSeconds(int userId, String date, int seconds) async {
    if (seconds <= 0) return;
    await _ensureDay(db, userId, date);
    await db.rawUpdate(
        'UPDATE daily_stats SET seconds = seconds + ? WHERE user_id = ? AND date = ?',
        [seconds, userId, date]);
  }

  Future<void> addAttempt(int userId, String date, double score) async {
    await _ensureDay(db, userId, date);
    await db.rawUpdate(
        'UPDATE daily_stats SET attempts = attempts + 1, score_sum = score_sum + ? '
        'WHERE user_id = ? AND date = ?',
        [score, userId, date]);
  }

  Future<DailyStat?> day(int userId, String date) async {
    final rows = await db.query('daily_stats',
        where: 'user_id = ? AND date = ?', whereArgs: [userId, date]);
    return rows.isEmpty ? null : DailyStat.fromMap(rows.first);
  }

  /// Thống kê từ ngày [fromDate] (yyyy-MM-dd) trở đi.
  Future<List<DailyStat>> dailyStats(int userId, {String? fromDate}) async {
    final rows = await db.query('daily_stats',
        where: fromDate == null ? 'user_id = ?' : 'user_id = ? AND date >= ?',
        whereArgs: fromDate == null ? [userId] : [userId, fromDate],
        orderBy: 'date');
    return rows.map(DailyStat.fromMap).toList();
  }

  Future<List<String>> practiceDays(int userId) async {
    final rows = await db.query('daily_stats',
        columns: ['date'], where: 'user_id = ? AND attempts > 0', whereArgs: [userId]);
    return [for (final r in rows) r['date'] as String];
  }

  /// Tính lại streak từ daily_stats và lưu vào bảng streaks.
  Future<StreakInfo> refreshStreak(int userId, DateTime now) async {
    final info = computeStreak(await practiceDays(userId), now);
    final old = await db.query('streaks', where: 'user_id = ?', whereArgs: [userId]);
    final longest = [
      info.longest,
      if (old.isNotEmpty) old.first['longest_streak'] as int? ?? 0,
    ].reduce((a, b) => a > b ? a : b);
    await db.insert(
      'streaks',
      {
        'user_id': userId,
        'current_streak': info.current,
        'longest_streak': longest,
        'last_practice_date': info.lastPracticeDate,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return StreakInfo(
      current: info.current,
      longest: longest,
      practicedToday: info.practicedToday,
      lastPracticeDate: info.lastPracticeDate,
    );
  }

  Future<void> updateWeakPhonemes(int userId,
      Map<String, ({int total, int errors})> stats, DateTime at) async {
    final batch = db.batch();
    for (final e in stats.entries) {
      batch.insert('weak_phonemes', {'user_id': userId, 'phoneme': e.key},
          conflictAlgorithm: ConflictAlgorithm.ignore);
      batch.rawUpdate(
          'UPDATE weak_phonemes SET error_count = error_count + ?, '
          'total_count = total_count + ?, last_seen = ? '
          'WHERE user_id = ? AND phoneme = ?',
          [e.value.errors, e.value.total, at.toIso8601String(), userId, e.key]);
    }
    await batch.commit(noResult: true);
  }

  Future<List<WeakPhoneme>> weakPhonemes(int userId) async {
    final rows = await db.query('weak_phonemes',
        where: 'user_id = ?', whereArgs: [userId]);
    final list = rows.map(WeakPhoneme.fromMap).toList()
      ..sort((a, b) => b.errorRate.compareTo(a.errorRate));
    return list;
  }

  Future<({int seconds, int attempts, double avg})> totals(int userId) async {
    final r = (await db.rawQuery(
            'SELECT SUM(seconds) s, SUM(attempts) a, SUM(score_sum) t '
            'FROM daily_stats WHERE user_id = ?',
            [userId]))
        .first;
    final a = (r['a'] as num?)?.toInt() ?? 0;
    return (
      seconds: (r['s'] as num?)?.toInt() ?? 0,
      attempts: a,
      avg: a == 0 ? 0.0 : ((r['t'] as num?)?.toDouble() ?? 0) / a,
    );
  }
}
