import 'package:flutter_test/flutter_test.dart';
import 'package:chailish/core/contracts/models/pronunciation.dart';
import 'package:chailish/core/contracts/pronunciation_scorer.dart';
import 'package:chailish/features/pronunciation/engine/offline_pronunciation_engine.dart';

void main() {
  group('Module Cham Phat Am Tieng Trung - Unit Test (#16)', () {
    late OfflinePronunciationEngine scorer;

    setUp(() {
      scorer = OfflinePronunciationEngine();
    });

    test('1. Tach am tiet pinyin co dau chuan xac', () {
      final haoSyl = splitPinyin('hǎo');
      expect(haoSyl.initial, 'h');
      expect(haoSyl.finalPart, 'ao');
      expect(haoSyl.tone, 3);

      final niSyl = splitPinyin('nǐ');
      expect(niSyl.initial, 'n');
      expect(niSyl.finalPart, 'i');
      expect(niSyl.tone, 3);

      final zhongSyl = splitPinyin('zhōng');
      expect(zhongSyl.initial, 'zh');
      expect(zhongSyl.finalPart, 'ong');
      expect(zhongSyl.tone, 1);
    });

    test('2. Cham diem cau doc chuan tra ve diem cao (>80)', () async {
      final res = await scorer.assess(
        referenceHanzi: '你好',
        referencePinyin: 'nǐ hǎo',
      );

      expect(res.overall, greaterThanOrEqualTo(80));
      expect(res.syllables.length, 2);
      expect(res.syllables[0].status, SyllableStatus.ok);
      expect(res.syllables[1].status, SyllableStatus.ok);
    });

    test('3. Phat hien va tinh diem phan hoi day du 4 thanh phan', () async {
      final res = await scorer.assess(
        referenceHanzi: '谢谢',
        referencePinyin: 'xiè xie',
      );

      expect(res.accuracy, greaterThan(0));
      expect(res.tone, greaterThan(0));
      expect(res.fluency, greaterThan(0));
      expect(res.completeness, 100.0);
    });

    test('4. Kiem tra bien dieu 2 thanh 3 (3+3 -> 2+3)', () {
      final p1 = splitPinyin('nǐ');
      final p2 = splitPinyin('hǎo');
      expect(p1.tone, 3);
      expect(p2.tone, 3);
    });

    test('5. Kiem tra tach thanh mau zh, ch, sh dung quy chuan', () {
      final zh = splitPinyin('zhōng');
      final ch = splitPinyin('chī');
      final sh = splitPinyin('shū');

      expect(zh.initial, 'zh');
      expect(ch.initial, 'ch');
      expect(sh.initial, 'sh');
    });

    test('6. Kiem tra am tiet thanh nhe tone = 5', () {
      final ma = splitPinyin('ma');
      final de = splitPinyin('de');

      expect(ma.tone, 5);
      expect(de.tone, 5);
    });

    test('7. Phat hien bat loi thanh dieu khi doc sai dau (ni hao, ni hao, ni hao)', () async {
      // Test ni háo: sai ca 2 thanh (thanh 5 + thanh 2 so voi thanh 3 + thanh 3)
      final resNiHao = await scorer.assess(
        referenceHanzi: '你好',
        referencePinyin: 'nǐ hǎo',
        recognizedPinyin: 'ni háo',
      );
      expect(resNiHao.overall, lessThan(80));
      expect(resNiHao.syllables[0].errors.contains(PronunciationError.tone), isTrue);
      expect(resNiHao.syllables[1].errors.contains(PronunciationError.tone), isTrue);

      // Test nĩ hào: hào sai thanh 4 so voi thanh 3
      final resNiHao4 = await scorer.assess(
        referenceHanzi: '你好',
        referencePinyin: 'nǐ hǎo',
        recognizedPinyin: 'nĩ hào',
      );
      expect(resNiHao4.syllables[1].errors.contains(PronunciationError.tone), isTrue);
      expect(resNiHao4.syllables[1].status, SyllableStatus.error);

      // Test nỉ hao: hao thieu dau (thanh 5 so voi thanh 3)
      final resNiHao5 = await scorer.assess(
        referenceHanzi: '你好',
        referencePinyin: 'nǐ hǎo',
        recognizedPinyin: 'nỉ hao',
      );
      expect(resNiHao5.syllables[1].errors.contains(PronunciationError.tone), isTrue);
      expect(resNiHao5.syllables[1].status, SyllableStatus.error);
    });
  });
}
