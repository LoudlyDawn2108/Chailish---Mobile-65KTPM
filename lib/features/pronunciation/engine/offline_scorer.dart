// Module M1 – Engine chấm điểm phát âm (offline) · Phụ trách: Nguyễn Hồng Phúc
//
// Thuật toán so sánh âm vị (phoneme comparison):
//   1. Chuẩn hoá câu mẫu và câu nhận dạng thành danh sách từ.
//   2. Tra phiên âm ARPAbet của từng từ (CMUdict, G2P dự phòng).
//   3. Căn chỉnh cấp TỪ bằng Levenshtein, chi phí thay thế = độ khác nhau
//      về âm vị giữa 2 từ -> tìm từ người dùng nói ứng với từ mẫu nào.
//   4. Với mỗi cặp từ, căn chỉnh cấp ÂM VỊ -> đánh dấu âm đúng / âm bị
//      thay thế (gần đúng hoặc sai hẳn) / âm bị bỏ sót / âm thừa.
//   5. Quy đổi ra điểm Accuracy, Fluency, Completeness và điểm tổng:
//      Tổng = (0.6·Acc + 0.2·Flu)·Com/100 + 0.2·Com − phạt từ thừa.
//
// Hạn chế (ghi trong báo cáo): bộ nhận dạng giọng nói luôn "đoán" thành
// từ có thật, nên đây là phép xấp xỉ. Engine Azure cho điểm âm vị trực tiếp
// từ âm thanh, chính xác hơn.

import 'dart:math' as math;

import '../../../core/models/pronunciation_result.dart';
import 'aligner.dart';
import 'phonemes.dart';
import 'pronouncing_dictionary.dart';

class OfflineScorer {
  OfflineScorer(this.dict);

  final PronouncingDictionary dict;

  /// [confidence] (0–1; <= 0 nghĩa là không có) và [speechDuration] lấy từ bộ
  /// nhận dạng giọng nói, dùng để tinh chỉnh điểm.
  PronunciationResult score({
    required String reference,
    required String recognized,
    double confidence = -1,
    Duration? speechDuration,
  }) {
    final refWords = tokenize(reference);
    final hypWords = tokenize(recognized);
    final refVariants = [for (final w in refWords) dict.variants(w)];
    final hypVariants = [for (final w in hypWords) dict.variants(w)];

    // ---- Căn chỉnh cấp từ ----
    final pairCache = <String, _PhoneAlignment>{};
    _PhoneAlignment best(int i, int j) => pairCache.putIfAbsent(
        '$i:$j', () => _bestPhoneAlignment(refVariants[i], hypVariants[j]));

    final wordAlign = align<int>(
      List.generate(refWords.length, (i) => i),
      List.generate(hypWords.length, (j) => j),
      subCost: (i, j) {
        if (refWords[i] == hypWords[j]) return 0;
        return best(i, j).normalizedCost.clamp(0.0, 1.0);
      },
      // Bỏ sót 1 từ đắt hơn đọc sai 1 từ một chút -> ưu tiên ghép cặp.
      deleteCost: 1.05,
      insertCost: 1.0,
    );

    final words = <WordResult>[];
    var insertedWords = 0;
    for (final step in wordAlign.steps) {
      switch (step.type) {
        case AlignType.match:
        case AlignType.substitute:
          words.add(_scoreWord(
            refWords[step.refIndex],
            hypWords[step.hypIndex],
            best(step.refIndex, step.hypIndex),
          ));
        case AlignType.delete:
          final phones = refVariants[step.refIndex].first;
          words.add(WordResult(
            word: refWords[step.refIndex],
            recognized: null,
            score: 0,
            errorType: WordErrorType.omission,
            phonemes: [
              for (final p in phones)
                PhonemeResult(expected: p, actual: null, score: 0),
            ],
          ));
        case AlignType.insert:
          insertedWords++;
          words.add(WordResult(
            word: hypWords[step.hypIndex],
            recognized: hypWords[step.hypIndex],
            score: 0,
            errorType: WordErrorType.insertion,
            phonemes: const [],
          ));
      }
    }

    // ---- Tổng hợp điểm ----
    final spoken = words
        .where((w) =>
            w.errorType != WordErrorType.insertion &&
            w.errorType != WordErrorType.omission)
        .toList();
    final refCount = refWords.length;
    final completeness =
        refCount == 0 ? 0.0 : spoken.length / refCount * 100;

    var accuracy = 0.0;
    final phoneScores = [
      for (final w in spoken)
        for (final p in w.phonemes)
          if (!p.isInsertion) p.score,
    ];
    if (phoneScores.isNotEmpty) {
      accuracy = phoneScores.reduce((a, b) => a + b) / phoneScores.length;
      // Phạt nhẹ âm thừa trong từ.
      final extra = spoken.fold<int>(
          0, (s, w) => s + w.phonemes.where((p) => p.isInsertion).length);
      accuracy -= extra * 3;
      if (confidence > 0 && confidence <= 1) {
        accuracy *= 0.8 + 0.2 * confidence;
      }
    }
    accuracy = accuracy.clamp(0, 100).toDouble();

    final fluency = hypWords.isEmpty
        ? 0.0
        : _fluency(hypWords.length, refCount, insertedWords, speechDuration);

    // Nói thừa từ (lặp lại, đọc cả câu khi bài chỉ yêu cầu 1 từ) bị trừ
    // thêm vào điểm tổng, tối đa 40 điểm.
    final insertionPenalty = math.min(40, insertedWords * 8).toDouble();
    final overall = completeness == 0
        ? 0.0
        // Accuracy/Fluency chỉ tính trên các từ đã đọc, nên nhân với tỉ lệ
        // đầy đủ: đọc 1/7 từ không thể được điểm cao (lỗi tìm thấy khi QA
        // trên thiết bị: trước đây vẫn được 81 điểm).
        : ((accuracy * 0.6 + fluency * 0.2) * (completeness / 100) +
                completeness * 0.2 -
                insertionPenalty)
            .clamp(0, 100)
            .toDouble();

    return PronunciationResult(
      referenceText: reference,
      recognizedText: recognized,
      accuracy: _round(accuracy),
      fluency: _round(fluency),
      completeness: _round(completeness),
      overall: _round(overall),
      words: words,
      engine: 'offline',
    );
  }

  WordResult _scoreWord(String ref, String hyp, _PhoneAlignment pa) {
    final phonemes = <PhonemeResult>[];
    if (ref == hyp) {
      for (final p in pa.ref) {
        phonemes.add(PhonemeResult(expected: p, actual: p, score: 100));
      }
    } else {
      for (final s in pa.alignment.steps) {
        switch (s.type) {
          case AlignType.match:
            phonemes.add(PhonemeResult(
                expected: pa.ref[s.refIndex],
                actual: pa.hyp[s.hypIndex],
                score: 100));
          case AlignType.substitute:
            final sim =
                phonemeSimilarity(pa.ref[s.refIndex], pa.hyp[s.hypIndex]);
            phonemes.add(PhonemeResult(
                expected: pa.ref[s.refIndex],
                actual: pa.hyp[s.hypIndex],
                score: sim * 100));
          case AlignType.delete:
            phonemes.add(PhonemeResult(
                expected: pa.ref[s.refIndex], actual: null, score: 0));
          case AlignType.insert:
            phonemes.add(PhonemeResult(
                expected: '', actual: pa.hyp[s.hypIndex], score: 0));
        }
      }
    }
    final refPhones = phonemes.where((p) => !p.isInsertion).toList();
    final inserted = phonemes.length - refPhones.length;
    var wordScore = refPhones.isEmpty
        ? 0.0
        : refPhones.map((p) => p.score).reduce((a, b) => a + b) /
            refPhones.length;
    wordScore = (wordScore * (1 - 0.1 * inserted)).clamp(0, 100).toDouble();
    final hasError = refPhones.any((p) => p.isError) || inserted > 0;
    return WordResult(
      word: ref,
      recognized: hyp,
      score: _round(wordScore),
      errorType: hasError ? WordErrorType.mispronunciation : WordErrorType.none,
      phonemes: phonemes,
    );
  }

  /// Chọn cặp cách đọc (từ mẫu, từ nhận dạng) giống nhau nhất.
  _PhoneAlignment _bestPhoneAlignment(
      List<List<String>> refVars, List<List<String>> hypVars) {
    _PhoneAlignment? best;
    for (final r in refVars) {
      for (final h in hypVars) {
        final a = align<String>(r, h,
            subCost: (x, y) => 1 - phonemeSimilarity(x, y));
        final norm = a.cost / math.max(1, math.max(r.length, h.length));
        if (best == null || norm < best.normalizedCost) {
          best = _PhoneAlignment(r, h, a, norm);
        }
      }
    }
    return best!;
  }

  double _fluency(
      int hypCount, int refCount, int insertedWords, Duration? duration) {
    var f = 100.0;
    if (duration != null && refCount >= 3 && duration.inMilliseconds > 0) {
      final wps = hypCount / (duration.inMilliseconds / 1000);
      if (wps < 1.6) {
        f = math.max(30, 100 * wps / 1.6);
      } else if (wps > 3.8) {
        f = math.max(40, 100 - (wps - 3.8) * 20);
      }
    }
    f -= insertedWords * 10; // ngập ngừng / lặp từ
    return f.clamp(0, 100).toDouble();
  }

  static double _round(double v) => (v * 10).roundToDouble() / 10;
}

class _PhoneAlignment {
  _PhoneAlignment(this.ref, this.hyp, this.alignment, this.normalizedCost);
  final List<String> ref;
  final List<String> hyp;
  final Alignment alignment;
  final double normalizedCost;
}
