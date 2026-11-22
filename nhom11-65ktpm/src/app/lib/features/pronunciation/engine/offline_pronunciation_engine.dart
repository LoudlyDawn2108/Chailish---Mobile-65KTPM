import 'dart:math';
import '../../../../core/contracts/models/pronunciation.dart';
import '../../../../core/contracts/pronunciation_scorer.dart';

/// Thuat toan can chinh am tiet va ma tran phat loi nguoi Viet.
/// Chu so huu: Khanh (#13)
class OfflinePronunciationEngine implements PronunciationScorer {
  static const Map<String, List<String>> _confusableInitials = {
    'zh': ['z', 'j'],
    'z': ['zh'],
    'ch': ['c', 'q'],
    'c': ['ch'],
    'sh': ['s', 'x'],
    's': ['sh'],
    'j': ['q', 'zh', 'z', 'x'],
    'q': ['ch', 'j', 'c'],
    'x': ['s', 'sh', 'j'],
    'l': ['n'],
    'n': ['l'],
    'h': ['k'],
    'r': ['l', 'z', 'd'],
  };

  static const Map<String, List<String>> _confusableFinals = {
    'u': ['ü', 'v', 'ou'],
    'ü': ['u', 'v'],
    'an': ['ang'],
    'ang': ['an'],
    'en': ['eng'],
    'eng': ['en'],
    'in': ['ing'],
    'ing': ['in'],
    'ian': ['iang', 'en'],
    'iang': ['ian'],
    'uan': ['uang'],
    'uang': ['uan'],
  };

  @override
  Future<PronunciationResult> assess({
    required String referenceHanzi,
    required String referencePinyin,
    Recording? recording,
    String? recognizedPinyin,
  }) async {
    final chars = referenceHanzi.runes
        .map(String.fromCharCode)
        .where((c) => RegExp(r'[一-鿿]').hasMatch(c))
        .toList();
    final expSyls = referencePinyin.trim().split(RegExp(r'\s+'));
    final actSyls = (recognizedPinyin != null && recognizedPinyin.isNotEmpty)
        ? recognizedPinyin.trim().split(RegExp(r'\s+'))
        : <String>[];

    final syllablesScore = <SyllableScore>[];
    double totalScore = 0.0;
    double totalAccuracy = 0.0;
    double totalTone = 0.0;

    for (var i = 0; i < chars.length; i++) {
      final hanzi = chars[i];
      final expPinyinStr = i < expSyls.length ? expSyls[i] : '';
      final expected = splitPinyin(expPinyinStr);

      if (expected.initial.isEmpty && expected.finalPart.isEmpty) {
        continue;
      }

      // Neu co chuoi doc that su tu nguoi hoc thi dung de can chinh
      final SyllableParts actual = (i < actSyls.length)
          ? splitPinyin(actSyls[i])
          : expected;

      final errors = <PronunciationError>[];
      double initialPen = 0.0;
      double finalPen = 0.0;
      double tonePen = 0.0;

      if (expected.initial != actual.initial) {
        errors.add(PronunciationError.initial);
        if (_confusableInitials[expected.initial]?.contains(actual.initial) == true) {
          initialPen = 15.0;
        } else {
          initialPen = 40.0;
        }
      }

      if (expected.finalPart != actual.finalPart) {
        errors.add(PronunciationError.finalPart);
        if (_confusableFinals[expected.finalPart]?.contains(actual.finalPart) == true) {
          finalPen = 15.0;
        } else {
          finalPen = 40.0;
        }
      }

      if (expected.tone != actual.tone) {
        errors.add(PronunciationError.tone);
        if ((expected.tone == 2 && actual.tone == 3) || (expected.tone == 3 && actual.tone == 2)) {
          tonePen = 15.0;
        } else {
          tonePen = 35.0;
        }
      }

      final wordPenalty = initialPen * 0.35 + finalPen * 0.35 + tonePen * 0.30;
      final score = max(0.0, 100.0 - wordPenalty);
      final acc = max(0.0, 100.0 - (initialPen + finalPen));
      final toneSc = max(0.0, 100.0 - tonePen * 2.0);

      SyllableStatus status = SyllableStatus.ok;
      if (score < 60) {
        status = SyllableStatus.error;
      } else if (score < 80) {
        status = SyllableStatus.warn;
      }

      syllablesScore.add(SyllableScore(
        hanzi: hanzi,
        expected: expected,
        actual: actual,
        score: score.roundToDouble(),
        status: status,
        errors: errors,
      ));

      totalScore += score;
      totalAccuracy += acc;
      totalTone += toneSc;
    }

    final n = chars.isEmpty ? 1 : chars.length;
    final avgScore = (totalScore / n).roundToDouble();
    final avgAccuracy = (totalAccuracy / n).roundToDouble();
    final avgTone = (totalTone / n).roundToDouble();

    double fluency = 92.0;
    if (recording != null && recording.duration.inMilliseconds > 0) {
      final expectedDurationMs = chars.length * 600;
      final actualMs = recording.duration.inMilliseconds;
      final ratio = actualMs / expectedDurationMs;
      if (ratio > 2.0 || ratio < 0.4) {
        fluency = max(60.0, 92.0 - (ratio - 1.0).abs() * 20.0).roundToDouble();
      }
    }

    return PronunciationResult(
      overall: avgScore,
      accuracy: avgAccuracy,
      tone: avgTone,
      fluency: fluency,
      completeness: (chars.isNotEmpty && expSyls.isNotEmpty) ? 100.0 : 0.0,
      source: ScoringSource.offline,
      recognizedText: referenceHanzi,
      syllables: syllablesScore,
    );
  }
}
