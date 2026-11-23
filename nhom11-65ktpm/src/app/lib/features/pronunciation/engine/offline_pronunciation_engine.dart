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
    String? recognizedText,
  }) async {
    final chars = referenceHanzi.runes
        .map(String.fromCharCode)
        .where((c) => RegExp(r'[一-鿿]').hasMatch(c))
        .toList();
    final expSyls = referencePinyin.trim().split(RegExp(r'\s+'));

    // Neu ghi am qua ngan (< 0.4s), nguoi dung chua noi hoac chi cham nhe vao mic
    if (recording != null && recording.duration.inMilliseconds < 400) {
      return PronunciationResult(
        overall: 0.0,
        accuracy: 0.0,
        tone: 0.0,
        fluency: 0.0,
        completeness: 0.0,
        source: ScoringSource.offline,
        recognizedText: '',
        syllables: [
          for (var i = 0; i < chars.length; i++)
            SyllableScore(
              hanzi: chars[i],
              expected: splitPinyin(i < expSyls.length ? expSyls[i] : ''),
              actual: null,
              score: 0.0,
              status: SyllableStatus.error,
              errors: const [PronunciationError.missing],
            ),
        ],
      );
    }

    // Neu co ban ghi that ma khong nhan dien duoc am tiet nao (im lang hoac noi tieng khac)
    if (recording != null && (recognizedPinyin == null || recognizedPinyin.trim().isEmpty)) {
      return PronunciationResult(
        overall: 0.0,
        accuracy: 0.0,
        tone: 0.0,
        fluency: 0.0,
        completeness: 0.0,
        source: ScoringSource.offline,
        recognizedText: recognizedText ?? '',
        syllables: [
          for (var i = 0; i < chars.length; i++)
            SyllableScore(
              hanzi: chars[i],
              expected: splitPinyin(i < expSyls.length ? expSyls[i] : ''),
              actual: null,
              score: 0.0,
              status: SyllableStatus.error,
              errors: const [PronunciationError.missing],
            ),
        ],
      );
    }

    final actSyls = (recognizedPinyin != null && recognizedPinyin.trim().isNotEmpty)
        ? recognizedPinyin.trim().split(RegExp(r'\s+'))
        : <String>[];

    final syllablesScore = <SyllableScore>[];
    double totalScore = 0.0;
    double totalAccuracy = 0.0;
    double totalTone = 0.0;
    int recognizedCount = 0;

    for (var i = 0; i < chars.length; i++) {
      final hanzi = chars[i];
      final expPinyinStr = i < expSyls.length ? expSyls[i] : '';
      final expected = splitPinyin(expPinyinStr);

      if (expected.initial.isEmpty && expected.finalPart.isEmpty) {
        continue;
      }

      final bool isMockDefault = (recording == null && actSyls.isEmpty);
      if (!isMockDefault && i >= actSyls.length) {
        syllablesScore.add(SyllableScore(
          hanzi: hanzi,
          expected: expected,
          actual: null,
          score: 0.0,
          status: SyllableStatus.error,
          errors: const [PronunciationError.missing],
        ));
        continue;
      }

      final SyllableParts actual = isMockDefault ? expected : splitPinyin(actSyls[i]);
      recognizedCount++;

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

      double score;
      double acc;
      double toneSc;
      SyllableStatus status;

      // Neu ca thanh mau va van mau deu sai hoan toan (khong he phat am dung am tiet nay)
      if (initialPen >= 40.0 && finalPen >= 40.0) {
        score = 0.0;
        acc = 0.0;
        toneSc = 0.0;
        status = SyllableStatus.error;
      } else {
        final wordPenalty = initialPen * 0.45 + finalPen * 0.45 + tonePen * 0.30;
        score = max(0.0, 100.0 - wordPenalty);
        acc = max(0.0, 100.0 - (initialPen + finalPen));
        toneSc = max(0.0, 100.0 - tonePen * 2.0);

        if (score < 60) {
          status = SyllableStatus.error;
        } else if (score < 80) {
          status = SyllableStatus.warn;
        } else {
          status = SyllableStatus.ok;
        }
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

    final completeness = chars.isNotEmpty
        ? ((recognizedCount / chars.length) * 100.0).clamp(0.0, 100.0).roundToDouble()
        : 100.0;

    return PronunciationResult(
      overall: avgScore,
      accuracy: avgAccuracy,
      tone: avgTone,
      fluency: fluency,
      completeness: completeness,
      source: ScoringSource.offline,
      recognizedText: recognizedText ?? (actSyls.isNotEmpty ? actSyls.join(' ') : referenceHanzi),
      syllables: syllablesScore,
    );
  }
}
