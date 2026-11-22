import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/contracts/models/pronunciation.dart';
import '../../../../core/contracts/pronunciation_scorer.dart';
import 'offline_pronunciation_engine.dart';

/// Bo cham ket hop Online Azure va tu dong Fallback Offline. Chu so huu: Khanh (#14)
class HybridPronunciationScorer implements PronunciationScorer {
  final ScoringMode Function() getScoringMode;
  final String serverBaseUrl;
  final OfflinePronunciationEngine _offlineEngine = OfflinePronunciationEngine();

  HybridPronunciationScorer({
    required this.getScoringMode,
    this.serverBaseUrl = 'http://10.0.2.2:8000',
  });

  @override
  Future<PronunciationResult> assess({
    required String referenceHanzi,
    required String referencePinyin,
    Recording? recording,
  }) async {
    final mode = getScoringMode();

    // 1. Neu cai dat uu tien online va co file ghi am that
    if (mode == ScoringMode.preferOnline && recording?.path != null) {
      try {
        final result = await _callOnlineAssessment(
          referenceHanzi: referenceHanzi,
          referencePinyin: referencePinyin,
          audioPath: recording!.path!,
        );
        if (result != null) {
          return result;
        }
      } catch (e) {
        debugPrint('Online Azure gap loi -> fallback sang offline: $e');
      }
    }

    // 2. Fallback tu dong ve engine offline
    return _offlineEngine.assess(
      referenceHanzi: referenceHanzi,
      referencePinyin: referencePinyin,
      recording: recording,
    );
  }

  Future<PronunciationResult?> _callOnlineAssessment({
    required String referenceHanzi,
    required String referencePinyin,
    required String audioPath,
  }) async {
    final file = File(audioPath);
    if (!await file.exists()) return null;

    final uri = Uri.parse('$serverBaseUrl/api/v1/pronunciation/assess');
    final req = http.MultipartRequest('POST', uri)
      ..fields['reference_text'] = referenceHanzi
      ..files.add(await http.MultipartFile.fromPath('audio_file', audioPath));

    final streamed = await req.send().timeout(const Duration(seconds: 8));
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode == 200) {
      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      // Chuan hoa ket qua tu Azure REST API
      final nbest = jsonMap['NBest'] as List? ?? [];
      if (nbest.isNotEmpty) {
        final first = nbest[0] as Map<String, dynamic>;
        final pron = first['PronunciationAssessment'] as Map<String, dynamic>? ?? {};
        final overall = (pron['PronScore'] as num?)?.toDouble() ?? 85.0;
        final accuracy = (pron['AccuracyScore'] as num?)?.toDouble() ?? 85.0;
        final fluency = (pron['FluencyScore'] as num?)?.toDouble() ?? 85.0;
        final completeness = (pron['CompletenessScore'] as num?)?.toDouble() ?? 100.0;

        final chars = referenceHanzi.runes.map(String.fromCharCode).where((c) => RegExp(r'[一-鿿]').hasMatch(c)).toList();
        final syls = referencePinyin.trim().split(RegExp(r'\s+'));
        final sylScoreList = <SyllableScore>[];

        for (var i = 0; i < chars.length; i++) {
          final exp = splitPinyin(i < syls.length ? syls[i] : '');
          sylScoreList.add(SyllableScore(
            hanzi: chars[i],
            expected: exp,
            actual: exp,
            score: accuracy,
            status: accuracy >= 80 ? SyllableStatus.ok : (accuracy >= 60 ? SyllableStatus.warn : SyllableStatus.error),
          ));
        }

        return PronunciationResult(
          overall: overall,
          accuracy: accuracy,
          tone: accuracy,
          fluency: fluency,
          completeness: completeness,
          source: ScoringSource.online,
          recognizedText: referenceHanzi,
          syllables: sylScoreList,
        );
      }
    }
    return null;
  }
}
