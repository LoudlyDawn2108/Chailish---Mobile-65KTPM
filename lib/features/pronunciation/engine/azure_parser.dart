// Module M1 – Tích hợp Azure Pronunciation Assessment · Phụ trách: Nguyễn Hồng Phúc
//
// Chuyển JSON trả về của Azure Speech (format=detailed, Granularity=Phoneme,
// PhonemeAlphabet=SAPI) thành PronunciationResult. Parse "phòng thủ" vì các
// trường có thể thiếu.

import '../../../core/models/pronunciation_result.dart';
import 'pronouncing_dictionary.dart';

/// SAPI (Azure, chữ thường) -> ARPAbet (CMUdict).
String sapiToArpabet(String p) {
  final up = p.trim().toUpperCase();
  switch (up) {
    case 'AX':
      return 'AH0';
    case 'H':
      return 'HH';
    default:
      return up;
  }
}

double _num(Object? v) => v is num ? v.toDouble() : 0;

PronunciationResult parseAzureResponse(
  Map<String, dynamic> json, {
  required String referenceText,
  PronouncingDictionary? dict,
}) {
  final status = json['RecognitionStatus'];
  if (status != null && status != 'Success') {
    throw AzureAssessmentException('Azure không nhận dạng được: $status');
  }
  final nbest = json['NBest'];
  if (nbest is! List || nbest.isEmpty) {
    throw const AzureAssessmentException('Phản hồi Azure không có NBest');
  }
  final top = Map<String, dynamic>.from(nbest.first as Map);
  final pa = top['PronunciationAssessment'] is Map
      ? Map<String, dynamic>.from(top['PronunciationAssessment'] as Map)
      : top; // một số phiên bản đặt điểm trực tiếp trong NBest[0]

  final words = <WordResult>[];
  for (final raw in (top['Words'] as List? ?? const [])) {
    final w = Map<String, dynamic>.from(raw as Map);
    final wpa = w['PronunciationAssessment'] is Map
        ? Map<String, dynamic>.from(w['PronunciationAssessment'] as Map)
        : w;
    final errorType = switch (wpa['ErrorType']) {
      'Omission' => WordErrorType.omission,
      'Insertion' => WordErrorType.insertion,
      'Mispronunciation' => WordErrorType.mispronunciation,
      _ => WordErrorType.none,
    };
    final text = (w['Word'] as String? ?? '').toLowerCase();
    final phonemes = <PhonemeResult>[];
    for (final rp in (w['Phonemes'] as List? ?? const [])) {
      final p = Map<String, dynamic>.from(rp as Map);
      final ppa = p['PronunciationAssessment'] is Map
          ? Map<String, dynamic>.from(p['PronunciationAssessment'] as Map)
          : p;
      final expected = sapiToArpabet(p['Phoneme'] as String? ?? '');
      final score = _num(ppa['AccuracyScore']);
      String? actual = expected;
      final nb = ppa['NBestPhonemes'];
      if (nb is List && nb.isNotEmpty) {
        final first = Map<String, dynamic>.from(nb.first as Map);
        final cand = first['Phoneme'] as String?;
        if (cand != null && cand.isNotEmpty) actual = sapiToArpabet(cand);
      }
      phonemes.add(PhonemeResult(
          expected: expected, actual: actual, score: score));
    }
    if (phonemes.isEmpty && errorType == WordErrorType.omission && dict != null) {
      for (final p in dict.lookup(text)) {
        phonemes.add(PhonemeResult(expected: p, actual: null, score: 0));
      }
    }
    words.add(WordResult(
      word: text,
      recognized: errorType == WordErrorType.omission ? null : text,
      score: _num(wpa['AccuracyScore']),
      // Azure chỉ báo lỗi cấp từ khi điểm rất thấp; đánh dấu thêm nếu có âm sai.
      errorType: errorType == WordErrorType.none &&
              phonemes.any((p) => p.isError)
          ? WordErrorType.mispronunciation
          : errorType,
      phonemes: phonemes,
    ));
  }

  return PronunciationResult(
    referenceText: referenceText,
    recognizedText: (top['Display'] ?? top['Lexical'] ?? '') as String,
    accuracy: _num(pa['AccuracyScore']),
    fluency: _num(pa['FluencyScore']),
    completeness: _num(pa['CompletenessScore']),
    overall: _num(pa['PronScore']),
    words: words,
    engine: 'azure',
  );
}

class AzureAssessmentException implements Exception {
  const AzureAssessmentException(this.message);
  final String message;
  @override
  String toString() => message;
}
