// Smoke test toàn ứng dụng: dựng app với CSDL thật (SQLite in-memory), đi qua
// 4 tab, mở bài học, màn hình luyện tập, rồi đổi người học. Kích thước màn
// hình điện thoại để phát hiện lỗi tràn bố cục (overflow).
import 'dart:io';

import 'package:ailish/app/app.dart';
import 'package:ailish/core/db/app_database.dart';
import 'package:ailish/core/db/repositories.dart';
import 'package:ailish/core/models/user_profile.dart';
import 'package:ailish/core/providers.dart';
import 'package:ailish/features/notifications/notification_service.dart';
import 'package:ailish/features/progress/streak_calculator.dart';
import 'package:ailish/features/pronunciation/engine/offline_scorer.dart';
import 'package:ailish/features/pronunciation/engine/pronouncing_dictionary.dart';
import 'package:ailish/features/recording/tts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeTts extends TtsService {
  @override
  Future<void> speak(String text, {double rate = 0.45}) async {}
  @override
  Future<void> stop() async {}
}

void main() {
  late PronouncingDictionary dict;

  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('vi');
    dict = PronouncingDictionary.parse(
        File('assets/data/cmudict.dict').readAsStringSync());
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Finder navItem(String label) => find.descendant(
      of: find.byType(NavigationBar), matching: find.text(label));

  Future<void> runFlow(WidgetTester tester,
      {required bool withData, bool landscape = false}) async {
    tester.view.physicalSize =
        landscape ? const Size(2400, 1080) : const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final setup = await tester.runAsync(() async {
      final db = await AppDatabase.open(
          factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      await LessonRepository(db)
          .seed(File('assets/data/lessons.json').readAsStringSync());
      final user = await UserRepository(db).insert(
          UserProfile(name: 'Lan', accent: 'Miền Trung', createdAt: DateTime(2026)));
      if (withData) {
        final scorer = OfflineScorer(dict);
        final attempts = AttemptRepository(db);
        final progress = ProgressRepository(db);
        final now = DateTime.now();
        for (var d = 0; d < 10; d++) {
          final at = now.subtract(Duration(days: d * 2));
          for (final said in ['sink', 'think', 'tink']) {
            final r = scorer.score(reference: 'think', recognized: said);
            await attempts.saveAttempt(
                userId: user.id!, sessionId: null, itemId: 'th_sounds_1',
                result: r, audioPath: null, at: at);
            await progress.addAttempt(user.id!, dateKey(at), r.overall);
            await progress.updateWeakPhonemes(user.id!, r.phonemeStats(), at);
          }
          await progress.addPracticeSeconds(user.id!, dateKey(at), 300 + d * 60);
        }
      }
      return (db, user);
    });
    final (db, user) = setup!;
    addTearDown(() => tester.runAsync(db.close));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(NotificationService()),
        initialUserProvider.overrideWithValue(user),
        dictionaryProvider.overrideWith((ref) async => dict),
        ttsServiceProvider.overrideWithValue(_FakeTts()),
      ],
      child: const AilishApp(),
    ));
    await settle(tester);

    expect(find.text('Xin chào, Lan 👋'), findsOneWidget);
    if (withData) {
      await tester.scrollUntilVisible(find.text('Âm bạn hay phát âm sai'), 300,
          scrollable: find.byType(Scrollable).hitTestable().first);
      expect(find.text('Âm bạn hay phát âm sai'), findsOneWidget);
    }

    await tester.tap(navItem('Bài học'));
    await settle(tester);
    expect(find.text('Cấp độ Cơ bản'), findsOneWidget);

    await tester.tap(navItem('Tiến độ'));
    await settle(tester);
    expect(find.text('Tiến độ học tập'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -1500));
    await settle(tester);

    await tester.tap(navItem('Cài đặt'));
    await settle(tester);
    expect(find.text('Đổi người học'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -2500));
    await settle(tester);

    // Bài học -> chi tiết -> luyện tập
    await tester.tap(navItem('Bài học'));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Âm /θ/ và /ð/'), 300,
        scrollable: find.byType(Scrollable).hitTestable().first);
    await tester.tap(find.text('Âm /θ/ và /ð/'));
    await settle(tester);
    expect(find.text('Bắt đầu luyện'), findsOneWidget);
    await tester.tap(find.text('Bắt đầu luyện'));
    await settle(tester);
    expect(find.text('Bấm micro rồi đọc to từ/câu trên'), findsOneWidget);
    expect(find.text('Nghe mẫu'), findsOneWidget);
    await tester.tap(find.text('Bỏ qua'));
    await settle(tester);
    await tester.tap(find.byType(BackButton).last);
    await settle(tester);
    await tester.tap(find.byType(BackButton).last);
    await settle(tester);

    // Lịch sử (từ tab Tiến độ)
    await tester.tap(navItem('Tiến độ'));
    await settle(tester);
    await tester.tap(find.byTooltip('Lịch sử luyện tập'));
    await settle(tester);
    expect(find.text(withData ? 'think' : 'Chưa có lần luyện nào.'),
        withData ? findsWidgets : findsOneWidget);
    await tester.tap(find.byType(BackButton).last);
    await settle(tester);

    // Đổi người học -> màn hình chọn hồ sơ
    await tester.tap(navItem('Cài đặt'));
    await settle(tester);
    await tester.drag(find.byType(ListView).last, const Offset(0, 2500));
    await settle(tester);
    final switchUser = find.text('Đổi người học');
    await tester.tap(switchUser);
    await settle(tester);
    expect(find.text('Chọn người học'), findsOneWidget);
    expect(find.text('Lan'), findsOneWidget);
  }

  testWidgets('app smoke test – no data', (t) => runFlow(t, withData: false));
  testWidgets('app smoke test – with history', (t) => runFlow(t, withData: true));
  testWidgets('app smoke test – landscape',
      (t) => runFlow(t, withData: true, landscape: true));
}
