// Widget test: màn hình phản hồi hiển thị điểm, từ sai, mẹo và gợi ý.
import 'dart:io';

import 'package:ailish/core/models/lesson.dart';
import 'package:ailish/core/providers.dart';
import 'package:ailish/features/feedback/feedback_screen.dart';
import 'package:ailish/features/progress/streak_calculator.dart';
import 'package:ailish/features/pronunciation/engine/offline_scorer.dart';
import 'package:ailish/features/pronunciation/engine/pronouncing_dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late OfflineScorer scorer;

  setUpAll(() async {
    await initializeDateFormatting('vi');
    scorer = OfflineScorer(PronouncingDictionary.parse(
        File('assets/data/cmudict.dict').readAsStringSync()));
  });

  testWidgets('feedback shows score, wrong word, tips and exercises',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final lessons = [
      Lesson(id: 'th', title: 'TH', level: 2, topic: 'Âm khó', focus: const ['TH'],
          description: '', order: 0, items: const [
        LessonItem(id: 'a', lessonId: 'th', text: 'three', meaning: '', type: 'word',
            ipa: '', phonemes: 'TH R IY1', order: 0),
      ]),
    ];
    final result = scorer.score(
        reference: 'I think this is right', recognized: 'I sink this is right');

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        lessonsProvider.overrideWith((ref) async => lessons),
      ],
      child: MaterialApp(
        home: FeedbackScreen(
          result: result,
          hasNext: true,
          streak: const StreakInfo(
              current: 3, longest: 5, practicedToday: true, lastPracticeDate: null),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Chuỗi 3 ngày luyện tập!'), findsOneWidget);
    expect(find.text('think'), findsOneWidget);
    expect(find.text('Tiếp theo'), findsOneWidget);

    // Mở chi tiết từ bị sai.
    await tester.tap(find.text('think'));
    await tester.pumpAndSettle();
    expect(find.text('Âm chuẩn'), findsOneWidget);
    expect(find.text('/s/'), findsWidgets);
    Navigator.of(tester.element(find.text('Âm chuẩn'))).pop();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Âm cần cải thiện'), 200);
    expect(find.text('Âm cần cải thiện'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Luyện ngay'), 200);
    expect(find.text('three'), findsWidgets);
  });
}
