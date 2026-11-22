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
      final hǎo = splitPinyin('hǎo');
      expect(hǎo.initial, 'h');
      expect(hǎo.finalPart, 'ao');
      expect(hǎo.tone, 3);

      final nǐ = splitPinyin('nǐ');
      expect(nǐ.initial, 'n');
      expect(nǐ.finalPart, 'i');
      expect(nǐ.tone, 3);

      final zhōng = splitPinyin('zhōng');
      expect(zhōng.initial, 'zh');
      expect(zhōng.finalPart, 'ong');
      expect(zhōng.tone, 1);
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
  });
}
