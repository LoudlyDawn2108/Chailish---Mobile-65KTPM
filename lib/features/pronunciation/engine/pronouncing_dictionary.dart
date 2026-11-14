// Module M2 – G2P / từ điển phát âm · Phụ trách: Lê Tuấn Khanh
//
// Đọc CMU Pronouncing Dictionary và tra phiên âm của một từ.
// Từ không có trong từ điển -> dùng quy tắc chữ-sang-âm đơn giản (G2P).

import 'text_normalizer.dart';

class PronouncingDictionary {
  PronouncingDictionary(this._entries);

  final Map<String, List<List<String>>> _entries;

  int get size => _entries.length;

  /// Parse nội dung file cmudict.dict. Hàm top-level-friendly để chạy
  /// trong isolate qua `compute`.
  static PronouncingDictionary parse(String content) {
    final entries = <String, List<List<String>>>{};
    final intern = <String, String>{};
    for (final raw in content.split('\n')) {
      var line = raw;
      final hash = line.indexOf('#');
      if (hash >= 0) line = line.substring(0, hash);
      line = line.trim();
      if (line.isEmpty) continue;
      final parts = line.split(' ');
      var word = parts.first;
      final paren = word.indexOf('(');
      if (paren > 0) word = word.substring(0, paren);
      final phones = <String>[
        for (final p in parts.skip(1))
          if (p.isNotEmpty) intern.putIfAbsent(p, () => p),
      ];
      entries.putIfAbsent(word, () => []).add(phones);
    }
    return PronouncingDictionary(entries);
  }

  bool contains(String word) => _entries.containsKey(word.toLowerCase());

  /// Mọi cách đọc của từ (từ điển), hoặc 1 cách đọc từ G2P nếu không có.
  List<List<String>> variants(String word) {
    final w = word.toLowerCase();
    final found = _entries[w];
    if (found != null) return found;
    final g = _entries[w.replaceAll("'", '')];
    if (g != null) return g;
    return [graphemeToPhoneme(w)];
  }

  List<String> lookup(String word) => variants(word).first;
}

/// G2P dự phòng bằng quy tắc (độ chính xác vừa phải, chỉ dùng khi từ
/// không có trong CMUdict, ví dụ tên riêng).
List<String> graphemeToPhoneme(String word) {
  var w = word.toLowerCase().replaceAll(RegExp(r"[^a-z]"), '');
  if (w.isEmpty) return const [];
  if (w.length > 3 && w.endsWith('e') && !w.endsWith('ee')) {
    w = w.substring(0, w.length - 1); // e câm cuối từ
  }
  const rules = <String, List<String>>{
    'tch': ['CH'], 'igh': ['AY1'], 'tion': ['SH', 'AH0', 'N'],
    'th': ['TH'], 'sh': ['SH'], 'ch': ['CH'], 'ph': ['F'], 'ng': ['NG'],
    'ck': ['K'], 'wh': ['W'], 'qu': ['K', 'W'], 'kn': ['N'], 'wr': ['R'],
    'ee': ['IY1'], 'ea': ['IY1'], 'oo': ['UW1'], 'ai': ['EY1'],
    'ay': ['EY1'], 'oa': ['OW1'], 'ow': ['OW1'], 'ou': ['AW1'],
    'oi': ['OY1'], 'oy': ['OY1'], 'au': ['AO1'], 'aw': ['AO1'],
    'er': ['ER0'], 'ir': ['ER1'], 'ur': ['ER1'], 'ar': ['AA1', 'R'],
    'or': ['AO1', 'R'],
    'a': ['AE1'], 'e': ['EH1'], 'i': ['IH1'], 'o': ['AA1'], 'u': ['AH1'],
    'b': ['B'], 'c': ['K'], 'd': ['D'], 'f': ['F'], 'g': ['G'], 'h': ['HH'],
    'j': ['JH'], 'k': ['K'], 'l': ['L'], 'm': ['M'], 'n': ['N'], 'p': ['P'],
    'q': ['K'], 'r': ['R'], 's': ['S'], 't': ['T'], 'v': ['V'], 'w': ['W'],
    'x': ['K', 'S'], 'z': ['Z'],
  };
  final out = <String>[];
  var i = 0;
  while (i < w.length) {
    if (w[i] == 'y') {
      out.add(i == 0 ? 'Y' : 'IY0');
      i++;
      continue;
    }
    var matched = false;
    for (final len in const [4, 3, 2, 1]) {
      if (i + len > w.length) continue;
      final r = rules[w.substring(i, i + len)];
      if (r != null) {
        // Bỏ phụ âm đôi giống nhau (ll, ss, tt...).
        if (len == 1 && out.isNotEmpty && out.last == r.first && r.length == 1) {
          i++;
          matched = true;
          break;
        }
        out.addAll(r);
        i += len;
        matched = true;
        break;
      }
    }
    if (!matched) i++;
  }
  return out;
}

/// Tách câu thành các từ đã chuẩn hoá (chữ thường, số -> chữ).
List<String> tokenize(String text) => normalizeToWords(text);
