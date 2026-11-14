import 'package:ailish/core/models/pronunciation_result.dart';
import 'package:ailish/features/pronunciation/engine/azure_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Mẫu rút gọn theo tài liệu Azure Pronunciation Assessment (format=detailed).
  final sample = {
    'RecognitionStatus': 'Success',
    'NBest': [
      {
        'Lexical': 'i sink so',
        'Display': 'I sink so.',
        'PronunciationAssessment': {
          'AccuracyScore': 72.0,
          'FluencyScore': 90.0,
          'CompletenessScore': 100.0,
          'PronScore': 78.5,
        },
        'Words': [
          {
            'Word': 'I',
            'PronunciationAssessment': {'AccuracyScore': 98.0, 'ErrorType': 'None'},
            'Phonemes': [
              {'Phoneme': 'ay', 'PronunciationAssessment': {'AccuracyScore': 98.0}},
            ],
          },
          {
            'Word': 'think',
            'PronunciationAssessment': {'AccuracyScore': 45.0, 'ErrorType': 'Mispronunciation'},
            'Phonemes': [
              {
                'Phoneme': 'th',
                'PronunciationAssessment': {
                  'AccuracyScore': 10.0,
                  'NBestPhonemes': [
                    {'Phoneme': 's', 'Score': 90.0},
                    {'Phoneme': 'th', 'Score': 10.0},
                  ],
                },
              },
              {'Phoneme': 'ih', 'PronunciationAssessment': {'AccuracyScore': 90.0}},
              {'Phoneme': 'ng', 'PronunciationAssessment': {'AccuracyScore': 85.0}},
              {'Phoneme': 'k', 'PronunciationAssessment': {'AccuracyScore': 80.0}},
            ],
          },
          {
            'Word': 'so',
            'PronunciationAssessment': {'AccuracyScore': 0.0, 'ErrorType': 'Omission'},
          },
        ],
      }
    ],
  };

  test('parses scores, phonemes and error types', () {
    final r = parseAzureResponse(sample, referenceText: 'I think so');
    expect(r.engine, 'azure');
    expect(r.overall, 78.5);
    expect(r.accuracy, 72);
    expect(r.recognizedText, 'I sink so.');
    expect(r.words.map((w) => w.errorType), [
      WordErrorType.none,
      WordErrorType.mispronunciation,
      WordErrorType.omission,
    ]);
    final th = r.words[1].phonemes.first;
    expect(th.expected, 'TH');
    expect(th.actual, 'S');
    expect(th.isError, isTrue);
    expect(r.errorPhonemes, ['TH']);
  });

  test('throws on failed recognition', () {
    expect(
      () => parseAzureResponse({'RecognitionStatus': 'NoMatch'}, referenceText: 'x'),
      throwsA(isA<AzureAssessmentException>()),
    );
  });

  test('sapi mapping', () {
    expect(sapiToArpabet('ax'), 'AH0');
    expect(sapiToArpabet('h'), 'HH');
    expect(sapiToArpabet('dh'), 'DH');
  });
}
