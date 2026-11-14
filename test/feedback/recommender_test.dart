import 'package:ailish/core/models/lesson.dart';
import 'package:ailish/core/models/progress_models.dart';
import 'package:ailish/features/feedback/exercise_recommender.dart';
import 'package:flutter_test/flutter_test.dart';

LessonItem _item(String id, String text, String phonemes, {String type = 'word'}) =>
    LessonItem(id: id, lessonId: 'l', text: text, meaning: '', type: type,
        ipa: '', phonemes: phonemes, order: 0);

void main() {
  final lessons = [
    Lesson(id: 'th', title: 'TH', level: 2, topic: 'Âm khó', focus: const ['TH'],
        description: '', order: 0, items: [
      _item('th1', 'think', 'TH IH1 NG K'),
      _item('th2', 'three', 'TH R IY1'),
    ]),
    Lesson(id: 'misc', title: 'Misc', level: 1, topic: 'x', focus: const [],
        description: '', order: 1, items: [
      _item('m1', 'bath', 'B AE1 TH'),
      _item('m2', 'rice', 'R AY1 S'),
      _item('m3', 'I think so', 'AY1 | TH IH1 NG K | S OW1', type: 'sentence'),
    ]),
  ];

  test('history: picks phonemes with enough samples and high error rate', () {
    final weak = [
      WeakPhoneme(phoneme: 'TH', errorCount: 6, totalCount: 10, lastSeen: DateTime(2026)),
      WeakPhoneme(phoneme: 'R', errorCount: 1, totalCount: 10, lastSeen: DateTime(2026)),
      WeakPhoneme(phoneme: 'S', errorCount: 2, totalCount: 2, lastSeen: DateTime(2026)),
    ];
    final recs = recommendFromHistory(weak, lessons);
    expect(recs.map((r) => r.phoneme), ['TH']);
    expect(recs.first.lessons.single.id, 'th');
    // focus lesson first, then words, then sentences
    expect(recs.first.items.map((i) => i.id), ['th1', 'th2', 'm1', 'm3']);
  });

  test('errors: excludes current item', () {
    final recs = recommendFromErrors(['R'], lessons, excludeItemId: 'th2');
    expect(recs.single.items.map((i) => i.id), ['m2']);
  });
}
