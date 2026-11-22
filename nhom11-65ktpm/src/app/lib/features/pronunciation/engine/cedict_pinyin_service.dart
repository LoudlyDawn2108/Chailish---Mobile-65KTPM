import 'dart:convert';
import 'package:flutter/services.dart';
import '../../../../core/contracts/lesson_repository.dart';
import '../../../../core/contracts/speech_services.dart';

/// Bo chuyen doi Han tu sang Pinyin va xu ly bien dieu. Chu so huu: Khanh (#12)
class CedictPinyinService implements PinyinService {
  final LessonRepository _lessons;
  Map<String, String>? _dict;

  CedictPinyinService(this._lessons);

  static const Map<String, String> _numberToHanzi = {
    '0': '零', '1': '一', '2': '二', '3': '三', '4': '四',
    '5': '五', '6': '六', '7': '七', '8': '八', '9': '九', '10': '十',
  };

  static String normalize(String input) {
    var text = input.trim();
    _numberToHanzi.forEach((digit, hanzi) {
      text = text.replaceAll(digit, hanzi);
    });
    final punctRegex = RegExp(r'[，。！？、；：“”‘’（）《》〈〉【】…—\.,!?;:\(\)\[\]"\'\-]');
    return text.replaceAll(punctRegex, '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<void> _ensureLoaded() async {
    if (_dict != null) return;
    final dict = <String, String>{};
    // Nap tu cac bai hoc san co
    final allLessons = await _lessons.lessons();
    for (final l in allLessons) {
      for (final w in l.words) {
        dict[w.hanzi] = w.pinyin.toLowerCase().trim();
      }
    }
    // Bo sung cac tu pho bien HSK1-2
    final baseDict = {
      '你好': 'nǐ hǎo', '您好': 'nín hǎo', '谢谢': 'xièxie', '不客气': 'bú kèqi',
      '再见': 'zàijiàn', '对不起': 'duìbuqǐ', '没关系': 'méi guānxi', '请问': 'qǐngwèn',
      '中国': 'zhōngguó', '北京': 'běijīng', '汉语': 'hànyǔ', '老师': 'lǎoshī',
      '学生': 'xuésheng', '朋友': 'péngyou', '爸爸': 'bàba', '妈妈': 'māma',
      '今天': 'jīntiān', '明天': 'míngtiān', '昨天': 'zuótiān', '现在': 'xiànzài',
      '喜欢': 'xǐhuan', '认识': 'rènshi', '高兴': 'gāoxìng', '喝水': 'hē shuǐ',
      '吃米饭': 'chī mǐfàn', '看书': 'kàn shū', '去学校': 'qù xuéxiào',
      '买东西': 'mǎi dōngxi', '打电话': 'dǎ diànhuà', '听音乐': 'tīng yīnyuè',
      '几': 'jǐ', '什么': 'shénme', '多少': 'duōshao', '怎么': 'zěnme',
      '一': 'yī', '二': 'èr', '三': 'sān', '四': 'sì', '五': 'wǔ',
      '六': 'liù', '七': 'qī', '八': 'bā', '九': 'jiǔ', '十': 'shí',
      '好': 'hǎo', '大': 'dà', '小': 'xiǎo', '多': 'duō', '少': 'shǎo',
      '冷': 'lěng', '热': 'rè', '快': 'kuài', '慢': 'màn',
      '我': 'wǒ', '你': 'nǐ', '他': 'tā', '她': 'tā', '我们': 'wǒmen',
      '是': 'shì', '有': 'yǒu', '在': 'zài', '不': 'bù', '没': 'méi',
      '想': 'xiǎng', '能': 'néng', '会': 'huì', '可以': 'kěyǐ', '做': 'zuò',
    };
    baseDict.forEach((k, v) {
      dict.putIfAbsent(k, () => v);
    });
    _dict = dict;
  }

  @override
  Future<String> toPinyin(String hanzi, {bool applySandhi = false}) async {
    await _ensureLoaded();
    final clean = normalize(hanzi);
    final dict = _dict!;
    final hanziList = <String>[];
    final pinyinList = <String>[];

    var i = 0;
    while (i < clean.length) {
      if (clean[i] == ' ') {
        i++;
        continue;
      }

      var matched = false;
  // Uu tien khop cum tu dai nhat truoc (4 ky tu giam dan ve 1)
      for (var len = 4; len >= 1; len--) {
        if (i + len <= clean.length) {
          final sub = clean.substring(i, i + len);
          final p = dict[sub];
          if (p != null) {
            final syls = p.split(RegExp(r'\s+'));
            for (var k = 0; k < sub.length; k++) {
              hanziList.add(sub[k]);
              pinyinList.add(k < syls.length ? syls[k] : syls.last);
            }
            i += len;
            matched = true;
            break;
          }
        }
      }

      if (!matched) {
        final ch = clean[i];
        hanziList.add(ch);
        pinyinList.add(dict[ch] ?? '?');
        i++;
      }
    }

    if (applySandhi) {
      _applySandhiRules(hanziList, pinyinList);
    }

    return pinyinList.join(' ');
  }

  void _applySandhiRules(List<String> hanziList, List<String> pinyinList) {
    if (hanziList.length != pinyinList.length) return;
    final n = hanziList.length;

    // Quy tac 1: Bien dieu 2 thanh 3 lien nhau: 3 + 3 -> 2 + 3 (nǐ hǎo -> ní hǎo)
    for (var i = 0; i < n - 1; i++) {
      final p1 = pinyinList[i];
      final p2 = pinyinList[i + 1];
      if (_hasTone3(p1) && _hasTone3(p2)) {
        pinyinList[i] = _changeToTone2(p1);
      }
    }

    // Quy tac 2: Bien dieu chu '不' (bu4): dung truoc thanh 4 bien thanh bu2 (bú)
    for (var i = 0; i < n; i++) {
      if (hanziList[i] == '不') {
        if (i < n - 1 && _hasTone4(pinyinList[i + 1])) {
          pinyinList[i] = 'bú';
        }
      }
    }

    // Quy tac 3: Bien dieu chu '一' (yi1):
    // - Truoc thanh 4 doc thanh yí (thanh 2)
    // - Truoc thanh 1, 2, 3 doc thanh yì (thanh 4)
    for (var i = 0; i < n; i++) {
      if (hanziList[i] == '一') {
        if (i < n - 1) {
          final next = pinyinList[i + 1];
          if (_hasTone4(next)) {
            pinyinList[i] = 'yí';
          } else if (_hasTone1(next) || _hasTone2(next) || _hasTone3(next)) {
            pinyinList[i] = 'yì';
          }
        }
      }
    }
  }

  bool _hasTone1(String p) => RegExp(r'[āēīōūǖ]').hasMatch(p);
  bool _hasTone2(String p) => RegExp(r'[áéíóúǘ]').hasMatch(p);
  bool _hasTone3(String p) => RegExp(r'[ǎěǐǒǔǚ]').hasMatch(p);
  bool _hasTone4(String p) => RegExp(r'[àèìòùǜ]').hasMatch(p);

  String _changeToTone2(String p) {
    return p
        .replaceAll('ǎ', 'á')
        .replaceAll('ě', 'é')
        .replaceAll('ǐ', 'í')
        .replaceAll('ǒ', 'ó')
        .replaceAll('ǔ', 'ú')
        .replaceAll('ǚ', 'ǘ');
  }
}
