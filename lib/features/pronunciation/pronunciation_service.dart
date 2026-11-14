// Module M1 – Dịch vụ chấm điểm phát âm · Phụ trách: Nguyễn Hồng Phúc

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../../core/models/pronunciation_result.dart';
import '../recording/speech_service.dart';
import 'engine/azure_parser.dart';
import 'engine/offline_scorer.dart';
import 'engine/pronouncing_dictionary.dart';

/// Nạp CMUdict (~135 nghìn từ) trong isolate riêng để không giật giao diện.
Future<PronouncingDictionary> loadPronouncingDictionary() async {
  final content = await rootBundle.loadString('assets/data/cmudict.dict');
  return compute(PronouncingDictionary.parse, content);
}

class PronunciationService {
  PronunciationService(this._dictFuture);

  final Future<PronouncingDictionary> _dictFuture;

  /// Chấm điểm bằng thuật toán so sánh âm vị (offline).
  Future<PronunciationResult> assessOffline(
      String reference, SpeechCapture capture) async {
    final dict = await _dictFuture;
    return OfflineScorer(dict).score(
      reference: reference,
      recognized: capture.text,
      confidence: capture.confidence,
      speechDuration: capture.duration,
    );
  }

  /// Chấm điểm bằng Azure Speech – Pronunciation Assessment (REST API).
  Future<PronunciationResult> assessAzure({
    required String reference,
    required String audioPath,
    required String key,
    required String region,
  }) async {
    final config = {
      'ReferenceText': reference,
      'GradingSystem': 'HundredMark',
      'Granularity': 'Phoneme',
      'Dimension': 'Comprehensive',
      'EnableMiscue': true,
      'NBestPhonemeCount': 5,
    };
    final uri = Uri.https(
      '${region.trim()}.stt.speech.microsoft.com',
      '/speech/recognition/conversation/cognitiveservices/v1',
      {'language': 'en-US', 'format': 'detailed'},
    );
    final bytes = await File(audioPath).readAsBytes();
    final http.Response res;
    try {
      res = await http
          .post(
            uri,
            headers: {
              'Ocp-Apim-Subscription-Key': key.trim(),
              'Content-Type': 'audio/wav; codecs=audio/pcm; samplerate=16000',
              'Accept': 'application/json',
              'Pronunciation-Assessment':
                  base64Encode(utf8.encode(jsonEncode(config))),
            },
            body: bytes,
          )
          .timeout(const Duration(seconds: 25));
    } on SocketException {
      throw const AzureAssessmentException(
          'Không có kết nối mạng. Hãy chuyển sang chế độ offline trong Cài đặt.');
    }
    if (res.statusCode == 401) {
      throw const AzureAssessmentException(
          'Khoá Azure không hợp lệ hoặc sai vùng (region).');
    }
    if (res.statusCode != 200) {
      throw AzureAssessmentException(
          'Azure trả về lỗi ${res.statusCode}: ${res.body}');
    }
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return parseAzureResponse(json,
        referenceText: reference, dict: await _dictFuture);
  }
}
