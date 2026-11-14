// Model dùng chung · Phụ trách: Nguyễn Hồng Phúc / Đinh Thị Hoa

class LessonItem {
  const LessonItem({
    required this.id,
    required this.lessonId,
    required this.text,
    required this.meaning,
    required this.type,
    required this.ipa,
    required this.phonemes,
    required this.order,
  });

  final String id;
  final String lessonId;
  final String text;
  final String meaning;

  /// 'word' hoặc 'sentence'.
  final String type;
  final String ipa;

  /// ARPAbet, các từ cách nhau bởi " | ".
  final String phonemes;
  final int order;

  /// Tập âm vị (base, không số trọng âm) xuất hiện trong mục này.
  Set<String> get phonemeSet => phonemes
      .split(RegExp(r'[\s|]+'))
      .where((p) => p.isNotEmpty)
      .map((p) => p.replaceAll(RegExp(r'\d'), ''))
      .toSet();

  factory LessonItem.fromMap(Map<String, Object?> m) => LessonItem(
        id: m['id'] as String,
        lessonId: m['lesson_id'] as String,
        text: m['text'] as String,
        meaning: m['meaning'] as String? ?? '',
        type: m['type'] as String? ?? 'word',
        ipa: m['ipa'] as String? ?? '',
        phonemes: m['phonemes'] as String? ?? '',
        order: m['sort_order'] as int? ?? 0,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'lesson_id': lessonId,
        'text': text,
        'meaning': meaning,
        'type': type,
        'ipa': ipa,
        'phonemes': phonemes,
        'sort_order': order,
      };
}

class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.level,
    required this.topic,
    required this.focus,
    required this.description,
    required this.order,
    required this.items,
  });

  final String id;
  final String title;

  /// 1 = Cơ bản, 2 = Trung cấp, 3 = Nâng cao.
  final int level;
  final String topic;

  /// Các âm vị trọng tâm của bài (ARPAbet base).
  final List<String> focus;
  final String description;
  final int order;
  final List<LessonItem> items;

  static String levelName(int level) => switch (level) {
        1 => 'Cơ bản',
        2 => 'Trung cấp',
        _ => 'Nâng cao',
      };
}
