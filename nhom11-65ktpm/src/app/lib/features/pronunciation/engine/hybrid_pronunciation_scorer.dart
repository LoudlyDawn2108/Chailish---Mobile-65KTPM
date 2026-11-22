import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_constants.dart';
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
    this.serverBaseUrl = AppConstants.defaultBaseUrl,
  });

  @override
  Future<PronunciationResult> assess({
    required String referenceHanzi,
    required String referencePinyin,
    Recording? recording,
  }) async {
    final mode = getScoringMode();

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

    final uri = Uri.parse('$serverBaseUrl/api/pronunciation/assess');
    final req = http.MultipartRequest('POST', uri)
      ..fields['reference_text'] = referenceHanzi
      ..files.add(await http.MultipartFile.fromPath('audio_file', audioPath));

    final streamed = await req.send().timeout(const Duration(seconds: 10));
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode == 200) {
      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      return PronunciationResult.fromJson(jsonMap);
    } else {
      debugPrint('Azure server response status code: ${resp.statusCode}');
    }
    return null;
  }
}
