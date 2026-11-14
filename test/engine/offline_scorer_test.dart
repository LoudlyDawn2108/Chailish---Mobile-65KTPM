// Kiểm thử engine chấm điểm offline với các lỗi phát âm điển hình của
// người Việt (mô phỏng bằng câu nhận dạng sai).
import 'dart:io';

import 'package:ailish/core/models/pronunciation_result.dart';
import 'package:ailish/features/pronunciation/engine/offline_scorer.dart';
import 'package:ailish/features/pronunciation/engine/phonemes.dart';
import 'package:ailish/features/pronunciation/engine/pronouncing_dictionary.dart';
import 'package:ailish/features/pronunciation/engine/text_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late OfflineScorer scorer;
  late PronouncingDictionary dict;

  setUpAll(() {
    dict = PronouncingDictionary.parse(
        File('assets/data/cmudict.dict').readAsStringSync());
    scorer = OfflineScorer(dict);
  });

  test('dictionary loads and looks up words', () {
    expect(dict.size, greaterThan(100000));
    expect(dict.lookup('think'), ['TH', 'IH1', 'NG', 'K']);
    expect(dict.variants('the').length, greaterThan(1));
  });

  test('perfect pronunciation scores 100', () {
    final r = scorer.score(reference: 'think', recognized: 'think');
    expect(r.overall, 100);
    expect(r.words.single.errorType, WordErrorType.none);
    expect(r.errorPhonemes, isEmpty);
  });

  test('think -> sink : TH substituted by S, partial credit', () {
    final r = scorer.score(reference: 'think', recognized: 'sink');
    final w = r.words.single;
    expect(w.errorType, WordErrorType.mispronunciation);
    final th = w.phonemes.first;
    expect(th.expected, 'TH');
    expect(th.actual, 'S');
    expect(th.score, 50);
    expect(th.isError, isTrue);
    expect(r.errorPhonemes, ['TH']);
    expect(r.overall, lessThan(100));
    expect(r.overall, greaterThan(70));
  });

  test('rice -> lice : R/L confusion detected', () {
    final r = scorer.score(reference: 'rice', recognized: 'lice');
    expect(r.errorPhonemes, ['R']);
    expect(r.words.single.phonemes.first.actual, 'L');
  });

  test('final consonant dropped: nice -> nigh', () {
    final r = scorer.score(reference: 'nice', recognized: 'nigh');
    final last = r.words.single.phonemes.last;
    expect(last.expected, 'S');
    expect(last.actual, isNull);
    expect(last.score, 0);
    expect(r.errorPhonemes, contains('S'));
  });

  test('sheep -> ship : long/short vowel', () {
    final r = scorer.score(reference: 'sheep', recognized: 'ship');
    expect(r.errorPhonemes, ['IY']);
  });

  test('reading only one word of a sentence gives a low score', () {
    // Lỗi tìm thấy khi QA trên thiết bị: "I" / 7 từ trước đây được 81 điểm.
    final r = scorer.score(
        reference: 'I think this is the right way', recognized: 'I');
    expect(r.completeness, closeTo(14.3, 0.1));
    expect(r.overall, lessThan(30));
    final one = scorer.score(
        reference: 'I think this is the right way',
        recognized: 'I think this is the way');
    expect(one.overall, inInclusiveRange(80, 90));
  });

  test('sentence with omitted word lowers completeness only', () {
    final r = scorer.score(
        reference: 'I would like a cup of coffee',
        recognized: 'I would like cup of coffee');
    expect(r.completeness, closeTo(85.7, 0.1));
    expect(r.accuracy, 100);
    final omitted = r.words.firstWhere((w) => w.word == 'a');
    expect(omitted.errorType, WordErrorType.omission);
  });

  test('sentence with substitution keeps word alignment', () {
    final r = scorer.score(
        reference: 'I think this is the right way',
        recognized: 'I sink dis is the light way');
    expect(r.completeness, 100);
    expect(r.errorPhonemes.toSet(), {'TH', 'DH', 'R'});
    final words = r.referenceWords.map((w) => w.word).toList();
    expect(words, ['i', 'think', 'this', 'is', 'the', 'right', 'way']);
  });

  test('extra words are insertions and reduce fluency', () {
    final r = scorer.score(
        reference: 'nice to meet you', recognized: 'nice um to meet you');
    expect(r.words.where((w) => w.errorType == WordErrorType.insertion),
        hasLength(1));
    expect(r.fluency, lessThan(100));
    expect(r.completeness, 100);
  });

  test('reading a whole sentence for a single-word item is penalized', () {
    // Lỗi tìm thấy khi QA trên thiết bị: trước đây vẫn được 88 điểm.
    final r = scorer.score(
        reference: 'think', recognized: 'I think this is the right way');
    expect(r.words.where((w) => w.errorType == WordErrorType.insertion),
        hasLength(6));
    expect(r.overall, lessThan(60));
    final rep = scorer.score(reference: 'think', recognized: 'think think');
    expect(rep.overall, inInclusiveRange(80, 95));
  });

  test('digits from speech recognizer are normalized', () {
    final r = scorer.score(reference: 'three', recognized: '3');
    expect(r.overall, 100);
    final s = scorer.score(
        reference: 'My flight leaves at three o\'clock',
        recognized: 'my flight leaves at 3:00');
    expect(s.overall, 100);
  });

  test('nothing recognized gives zero', () {
    final r = scorer.score(reference: 'hello', recognized: '');
    expect(r.overall, 0);
    expect(r.words.single.errorType, WordErrorType.omission);
  });

  test('low confidence lowers accuracy', () {
    final hi = scorer.score(reference: 'hello', recognized: 'hello', confidence: 1);
    final lo = scorer.score(reference: 'hello', recognized: 'hello', confidence: 0.2);
    expect(lo.accuracy, lessThan(hi.accuracy));
  });

  test('zero / missing confidence does not penalize', () {
    final none = scorer.score(reference: 'hello', recognized: 'hello');
    final zero = scorer.score(reference: 'hello', recognized: 'hello', confidence: 0);
    expect(none.overall, 100);
    expect(zero.overall, 100);
  });

  test('very slow reading lowers fluency', () {
    final r = scorer.score(
        reference: 'I am learning English every day',
        recognized: 'I am learning English every day',
        speechDuration: const Duration(seconds: 12));
    expect(r.fluency, lessThan(60));
  });

  test('result survives json round trip', () {
    final r = scorer.score(reference: 'think', recognized: 'sink');
    final back = PronunciationResult.fromJson(r.toJson());
    expect(back.overall, r.overall);
    expect(back.words.single.phonemes.first.actual, 'S');
  });

  test('ipa conversion', () {
    expect(wordToIpa(['TH', 'IH1', 'NG', 'K']), 'θɪŋk');
    expect(wordToIpa(['K', 'AA1', 'F', 'IY0']), 'ˈkɑːfiː');
    expect(wordToIpa(['W', 'EH1', 'DH', 'ER0']), 'ˈweðər');
  });

  test('number to words', () {
    expect(numberToWords(13), 'thirteen');
    expect(numberToWords(105), 'one hundred five');
    expect(normalizeToWords('It\'s 9:30 now!'), ['it\'s', 'nine', 'thirty', 'now']);
  });

  test('g2p fallback for unknown words', () {
    expect(graphemeToPhoneme('thamp'), ['TH', 'AE1', 'M', 'P']);
    expect(dict.lookup('zzxqtest').isNotEmpty, isTrue);
  });
}
