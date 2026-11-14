// Module M4 – Cơ sở dữ liệu · Phụ trách: Chu Hữu Đệ (schema: Nguyễn Hồng Phúc)
//
// SQLite (sqflite). Toàn bộ dữ liệu người dùng được lưu trên máy.

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const _version = 1;

  /// [factory] và [path] dùng cho unit test (sqflite_common_ffi, in-memory).
  static Future<AppDatabase> open({DatabaseFactory? factory, String? path}) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), 'ailish.db');
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          final batch = db.batch();
          for (final sql in schema) {
            batch.execute(sql);
          }
          await batch.commit(noResult: true);
        },
      ),
    );
    return AppDatabase._(db);
  }

  Future<void> close() => db.close();

  /// Lược đồ CSDL (xem thêm PHAN_CONG.md mục 5).
  static const schema = <String>[
    '''CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)''',
    '''CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      level INTEGER NOT NULL DEFAULT 1,
      accent TEXT,
      gender TEXT,
      daily_goal_minutes INTEGER NOT NULL DEFAULT 10,
      reminder_enabled INTEGER NOT NULL DEFAULT 1,
      reminder_hour INTEGER NOT NULL DEFAULT 19,
      reminder_minute INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    )''',
    '''CREATE TABLE lessons (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      level INTEGER NOT NULL,
      topic TEXT,
      focus TEXT,
      description TEXT,
      sort_order INTEGER NOT NULL DEFAULT 0
    )''',
    '''CREATE TABLE lesson_items (
      id TEXT PRIMARY KEY,
      lesson_id TEXT NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
      text TEXT NOT NULL,
      meaning TEXT,
      type TEXT NOT NULL,
      ipa TEXT,
      phonemes TEXT,
      sort_order INTEGER NOT NULL DEFAULT 0
    )''',
    '''CREATE TABLE practice_sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      lesson_id TEXT,
      started_at TEXT NOT NULL,
      ended_at TEXT,
      duration_sec INTEGER NOT NULL DEFAULT 0
    )''',
    '''CREATE TABLE attempts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      session_id INTEGER REFERENCES practice_sessions(id) ON DELETE SET NULL,
      item_id TEXT,
      reference_text TEXT NOT NULL,
      recognized_text TEXT,
      audio_path TEXT,
      accuracy REAL, fluency REAL, completeness REAL, overall_score REAL,
      engine TEXT,
      result_json TEXT,
      created_at TEXT NOT NULL
    )''',
    'CREATE INDEX idx_attempts_user ON attempts(user_id, created_at)',
    '''CREATE TABLE phoneme_results (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      attempt_id INTEGER NOT NULL REFERENCES attempts(id) ON DELETE CASCADE,
      word_index INTEGER NOT NULL,
      word TEXT NOT NULL,
      expected_phoneme TEXT,
      actual_phoneme TEXT,
      score REAL,
      is_error INTEGER NOT NULL DEFAULT 0
    )''',
    '''CREATE TABLE daily_stats (
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      date TEXT NOT NULL,
      seconds INTEGER NOT NULL DEFAULT 0,
      attempts INTEGER NOT NULL DEFAULT 0,
      score_sum REAL NOT NULL DEFAULT 0,
      PRIMARY KEY (user_id, date)
    )''',
    '''CREATE TABLE streaks (
      user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      current_streak INTEGER NOT NULL DEFAULT 0,
      longest_streak INTEGER NOT NULL DEFAULT 0,
      last_practice_date TEXT
    )''',
    '''CREATE TABLE weak_phonemes (
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      phoneme TEXT NOT NULL,
      error_count INTEGER NOT NULL DEFAULT 0,
      total_count INTEGER NOT NULL DEFAULT 0,
      last_seen TEXT,
      PRIMARY KEY (user_id, phoneme)
    )''',
  ];
}
