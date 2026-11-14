// Module M1 – Engine chấm điểm phát âm · Phụ trách: Nguyễn Hồng Phúc
//
// Bảng âm vị ARPAbet (CMUdict) <-> IPA và độ "gần nhau" giữa các âm vị.
// File này là Dart thuần (không import Flutter) để có thể unit test.

/// 39 âm vị ARPAbet dùng trong CMUdict (không kèm số trọng âm).
const Map<String, String> kArpabetToIpa = {
  'AA': 'ɑː', 'AE': 'æ', 'AH': 'ʌ', 'AO': 'ɔː', 'AW': 'aʊ', 'AY': 'aɪ',
  'B': 'b', 'CH': 'tʃ', 'D': 'd', 'DH': 'ð', 'EH': 'e', 'ER': 'ɜːr',
  'EY': 'eɪ', 'F': 'f', 'G': 'ɡ', 'HH': 'h', 'IH': 'ɪ', 'IY': 'iː',
  'JH': 'dʒ', 'K': 'k', 'L': 'l', 'M': 'm', 'N': 'n', 'NG': 'ŋ',
  'OW': 'oʊ', 'OY': 'ɔɪ', 'P': 'p', 'R': 'r', 'S': 's', 'SH': 'ʃ',
  'T': 't', 'TH': 'θ', 'UH': 'ʊ', 'UW': 'uː', 'V': 'v', 'W': 'w',
  'Y': 'j', 'Z': 'z', 'ZH': 'ʒ',
};

const Set<String> kVowels = {
  'AA', 'AE', 'AH', 'AO', 'AW', 'AY', 'EH', 'ER', 'EY', 'IH', 'IY', 'OW',
  'OY', 'UH', 'UW',
};

/// Bỏ số trọng âm: "AH0" -> "AH".
String baseOf(String phone) {
  final last = phone.codeUnitAt(phone.length - 1);
  if (last >= 48 && last <= 57) return phone.substring(0, phone.length - 1);
  return phone;
}

bool isVowel(String phone) => kVowels.contains(baseOf(phone));

/// IPA của một âm vị (có xét trọng âm cho AH/ER).
String ipaOfPhone(String phone) {
  final base = baseOf(phone);
  if (phone == 'AH0') return 'ə';
  if (phone == 'ER0') return 'ər';
  return kArpabetToIpa[base] ?? base.toLowerCase();
}

/// Chuyển phiên âm một từ sang IPA. Dấu trọng âm ˈ chỉ đặt cho từ nhiều
/// âm tiết (cùng quy tắc với tool/build_lessons.py).
String wordToIpa(List<String> phones) {
  final syms = <String>[];
  final bases = <String>[];
  var stressed = -1;
  for (var i = 0; i < phones.length; i++) {
    final p = phones[i];
    syms.add(ipaOfPhone(p));
    bases.add(baseOf(p));
    if (p.endsWith('1') && stressed < 0) stressed = i;
  }
  final vowelCount = bases.where(kVowels.contains).length;
  if (vowelCount > 1 && stressed >= 0) {
    var pos = stressed;
    if (bases.take(stressed).every((b) => !kVowels.contains(b))) {
      pos = 0;
    } else if (stressed > 0 && !kVowels.contains(bases[stressed - 1])) {
      pos = stressed - 1;
    }
    syms.insert(pos, 'ˈ');
  }
  return syms.join();
}

/// Các nhóm âm dễ nhầm với nhau (đặc biệt với người Việt). Âm thay thế
/// nằm cùng nhóm được tính "gần đúng" (một nửa số điểm).
const List<Set<String>> _confusableGroups = [
  {'TH', 'T', 'S', 'F'}, // think -> tink / sink / fink
  {'DH', 'D', 'Z', 'V'}, // this -> dis / zis
  {'IY', 'IH'}, // sheep / ship
  {'AE', 'EH'}, // bad / bed
  {'R', 'L'}, // rice / lice
  {'S', 'SH', 'Z', 'ZH'}, // see / she / zoo
  {'CH', 'SH', 'JH'},
  {'UW', 'UH'}, // food / foot
  {'AA', 'AO', 'AH', 'OW'},
  {'ER', 'AH'},
  {'N', 'NG', 'M'},
  {'P', 'B'},
  {'T', 'D'},
  {'K', 'G'},
  {'F', 'V'},
  {'V', 'W'},
  {'EY', 'EH'},
  {'AY', 'AA'},
  {'OW', 'AW'},
];

/// Độ giống nhau giữa 2 âm vị: 1 = trùng, 0.5 = dễ nhầm, 0 = khác hẳn.
double phonemeSimilarity(String a, String b) {
  final x = baseOf(a), y = baseOf(b);
  if (x == y) return 1;
  for (final g in _confusableGroups) {
    if (g.contains(x) && g.contains(y)) return 0.5;
  }
  return 0;
}
