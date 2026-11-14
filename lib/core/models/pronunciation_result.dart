// Model dùng chung · Phụ trách: Nguyễn Hồng Phúc
//
// Kết quả chấm phát âm – chung cho engine offline và Azure.

enum WordErrorType { none, mispronunciation, omission, insertion }

/// Ngưỡng điểm: dưới mức này âm vị bị coi là phát âm sai.
const double kPhonemeErrorThreshold = 60;

class PhonemeResult {
  const PhonemeResult({
    required this.expected,
    required this.actual,
    required this.score,
  });

  /// Âm vị chuẩn (ARPAbet, có thể kèm số trọng âm). Rỗng nếu là âm thừa.
  final String expected;

  /// Âm vị người dùng phát ra (ước lượng). null nếu bị bỏ sót.
  final String? actual;

  /// 0–100.
  final double score;

  bool get isError => score < kPhonemeErrorThreshold;
  bool get isInsertion => expected.isEmpty;

  Map<String, dynamic> toJson() =>
      {'e': expected, 'a': actual, 's': double.parse(score.toStringAsFixed(1))};

  factory PhonemeResult.fromJson(Map<String, dynamic> j) => PhonemeResult(
        expected: j['e'] as String? ?? '',
        actual: j['a'] as String?,
        score: (j['s'] as num?)?.toDouble() ?? 0,
      );
}

class WordResult {
  const WordResult({
    required this.word,
    required this.recognized,
    required this.score,
    required this.errorType,
    required this.phonemes,
  });

  final String word;
  final String? recognized;
  final double score;
  final WordErrorType errorType;
  final List<PhonemeResult> phonemes;

  bool get isError => errorType != WordErrorType.none;

  Map<String, dynamic> toJson() => {
        'w': word,
        'r': recognized,
        's': double.parse(score.toStringAsFixed(1)),
        't': errorType.name,
        'p': phonemes.map((p) => p.toJson()).toList(),
      };

  factory WordResult.fromJson(Map<String, dynamic> j) => WordResult(
        word: j['w'] as String? ?? '',
        recognized: j['r'] as String?,
        score: (j['s'] as num?)?.toDouble() ?? 0,
        errorType: WordErrorType.values.firstWhere(
          (e) => e.name == j['t'],
          orElse: () => WordErrorType.none,
        ),
        phonemes: [
          for (final p in (j['p'] as List? ?? const []))
            PhonemeResult.fromJson(Map<String, dynamic>.from(p as Map)),
        ],
      );
}

class PronunciationResult {
  const PronunciationResult({
    required this.referenceText,
    required this.recognizedText,
    required this.accuracy,
    required this.fluency,
    required this.completeness,
    required this.overall,
    required this.words,
    required this.engine,
  });

  final String referenceText;
  final String recognizedText;
  final double accuracy;
  final double fluency;
  final double completeness;
  final double overall;
  final List<WordResult> words;

  /// 'offline' hoặc 'azure'.
  final String engine;

  /// Các từ trong câu mẫu (bỏ từ thừa).
  Iterable<WordResult> get referenceWords =>
      words.where((w) => w.errorType != WordErrorType.insertion);

  /// Thống kê âm vị: base phoneme -> (số lần, số lần sai). Dùng để cập nhật
  /// bảng weak_phonemes.
  Map<String, ({int total, int errors})> phonemeStats() {
    final out = <String, ({int total, int errors})>{};
    for (final w in referenceWords) {
      for (final p in w.phonemes) {
        if (p.isInsertion) continue;
        final base = p.expected.replaceAll(RegExp(r'\d'), '');
        final cur = out[base] ?? (total: 0, errors: 0);
        out[base] =
            (total: cur.total + 1, errors: cur.errors + (p.isError ? 1 : 0));
      }
    }
    return out;
  }

  /// Danh sách âm vị (base) bị sai, sắp theo số lần sai giảm dần.
  List<String> get errorPhonemes {
    final stats = phonemeStats().entries.where((e) => e.value.errors > 0).toList()
      ..sort((a, b) => b.value.errors.compareTo(a.value.errors));
    return [for (final e in stats) e.key];
  }

  Map<String, dynamic> toJson() => {
        'ref': referenceText,
        'rec': recognizedText,
        'acc': accuracy,
        'flu': fluency,
        'com': completeness,
        'ovr': overall,
        'eng': engine,
        'words': words.map((w) => w.toJson()).toList(),
      };

  factory PronunciationResult.fromJson(Map<String, dynamic> j) =>
      PronunciationResult(
        referenceText: j['ref'] as String? ?? '',
        recognizedText: j['rec'] as String? ?? '',
        accuracy: (j['acc'] as num?)?.toDouble() ?? 0,
        fluency: (j['flu'] as num?)?.toDouble() ?? 0,
        completeness: (j['com'] as num?)?.toDouble() ?? 0,
        overall: (j['ovr'] as num?)?.toDouble() ?? 0,
        engine: j['eng'] as String? ?? 'offline',
        words: [
          for (final w in (j['words'] as List? ?? const []))
            WordResult.fromJson(Map<String, dynamic>.from(w as Map)),
        ],
      );
}
