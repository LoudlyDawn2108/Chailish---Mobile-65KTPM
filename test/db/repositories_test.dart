// Kiểm thử tích hợp CSDL (SQLite chạy trên máy tính qua sqflite_common_ffi).
import 'dart:io';

import 'package:ailish/core/db/app_database.dart';
import 'package:ailish/core/db/repositories.dart';
import 'package:ailish/core/models/user_profile.dart';
import 'package:ailish/features/pronunciation/engine/offline_scorer.dart';
import 'package:ailish/features/pronunciation/engine/pronouncing_dictionary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late OfflineScorer scorer;

  setUpAll(() {
    scorer = OfflineScorer(PronouncingDictionary.parse(
        File('assets/data/cmudict.dict').readAsStringSync()));
  });

  setUp(() async {
    db = await AppDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
  });
  tearDown(() => db.close());

  test('seeds lessons from json only once', () async {
    final repo = LessonRepository(db);
    final json = File('assets/data/lessons.json').readAsStringSync();
    await repo.seed(json);
    await repo.seed(json);
    final lessons = await repo.getLessons();
    expect(lessons.length, 13);
    expect(lessons.expand((l) => l.items).length, 114);
    expect(lessons.firstWhere((l) => l.id == 'th_sounds').focus, ['TH', 'DH']);
  });

  test('full attempt flow updates stats, streak and weak phonemes', () async {
    final users = UserRepository(db);
    final attempts = AttemptRepository(db);
    final progress = ProgressRepository(db);
    final lessonRepo = LessonRepository(db);
    await lessonRepo.seed(File('assets/data/lessons.json').readAsStringSync());
    final item = (await lessonRepo.getLessons())
        .expand((l) => l.items)
        .firstWhere((i) => i.text == 'think');

    final u = await users.insert(UserProfile(name: 'Test', createdAt: DateTime(2026)));
    final day1 = DateTime(2026, 11, 2, 10);
    final day2 = DateTime(2026, 11, 3, 10);
    final sid = await attempts.startSession(u.id!, 'th_sounds', day1);

    for (final (at, said) in [(day1, 'sink'), (day2, 'think'), (day2, 'tink')]) {
      final r = scorer.score(reference: 'think', recognized: said);
      await attempts.saveAttempt(
          userId: u.id!, sessionId: sid, itemId: item.id, result: r, audioPath: null, at: at);
      await progress.addAttempt(u.id!, '${at.year}-${at.month}-0${at.day}', r.overall);
      await progress.updateWeakPhonemes(u.id!, r.phonemeStats(), at);
    }
    await progress.addPracticeSeconds(u.id!, '2026-11-03', 125);
    await attempts.endSession(sid, day2, 300);

    final streak = await progress.refreshStreak(u.id!, DateTime(2026, 11, 3, 20));
    expect(streak.current, 2);
    expect(streak.practicedToday, isTrue);

    final today = await progress.day(u.id!, '2026-11-03');
    expect(today!.attempts, 2);
    expect(today.seconds, 125);

    final weak = await progress.weakPhonemes(u.id!);
    final th = weak.firstWhere((w) => w.phoneme == 'TH');
    expect(th.totalCount, 3);
    expect(th.errorCount, 2);
    expect(weak.first.phoneme, 'TH');

    final hist = await attempts.recent(u.id!);
    expect(hist.length, 3);
    expect(hist.first.result.words.single.word, 'think');
    expect((await attempts.bestScoreByItem(u.id!))[item.id], 100);

    final totals = await progress.totals(u.id!);
    expect(totals.attempts, 3);

    final rows = await attempts.exportRows();
    expect(rows.first['name'], 'Test');

    // Xoá người dùng -> dữ liệu liên quan bị xoá theo (cascade).
    await users.delete(u.id!);
    expect(await attempts.recent(u.id!), isEmpty);
    expect(await progress.weakPhonemes(u.id!), isEmpty);
  });
}
