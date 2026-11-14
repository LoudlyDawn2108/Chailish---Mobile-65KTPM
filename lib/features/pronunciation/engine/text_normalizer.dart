// Module M2 – Chuẩn hoá văn bản nhận dạng · Phụ trách: Lê Tuấn Khanh
//
// Bộ nhận dạng giọng nói thường trả về số ("3", "3:00", "13th") thay vì
// chữ. Hàm ở đây đưa về dạng chữ để so sánh với câu mẫu.

const _ones = [
  'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight',
  'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen',
  'sixteen', 'seventeen', 'eighteen', 'nineteen',
];
const _tens = [
  '', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy',
  'eighty', 'ninety',
];

String numberToWords(int n) {
  if (n < 0) return 'minus ${numberToWords(-n)}';
  if (n < 20) return _ones[n];
  if (n < 100) {
    final t = _tens[n ~/ 10];
    return n % 10 == 0 ? t : '$t ${_ones[n % 10]}';
  }
  if (n < 1000) {
    final rest = n % 100;
    final h = '${_ones[n ~/ 100]} hundred';
    return rest == 0 ? h : '$h ${numberToWords(rest)}';
  }
  if (n < 1000000) {
    final rest = n % 1000;
    final th = '${numberToWords(n ~/ 1000)} thousand';
    return rest == 0 ? th : '$th ${numberToWords(rest)}';
  }
  return n.toString();
}

/// Chuẩn hoá thành danh sách từ: chữ thường, bỏ dấu câu, đổi số sang chữ.
List<String> normalizeToWords(String text) {
  var s = text.toLowerCase();
  s = s.replaceAll('’', "'");
  // 3:00 -> three o'clock, 3:30 -> three thirty
  s = s.replaceAllMapped(RegExp(r'(\d{1,2}):(\d{2})\s*(a\.?m\.?|p\.?m\.?)?'),
      (m) {
    final h = int.parse(m[1]!);
    final min = int.parse(m[2]!);
    final hour = numberToWords(h);
    if (min == 0) return " $hour o'clock ";
    return ' $hour ${min < 10 ? 'oh ${numberToWords(min)}' : numberToWords(min)} ';
  });
  s = s.replaceAll('%', ' percent ');
  s = s.replaceAll('&', ' and ');
  // Bỏ hậu tố số thứ tự đơn giản: 13th -> 13
  s = s.replaceAllMapped(RegExp(r'(\d+)(st|nd|rd|th)\b'), (m) => m[1]!);
  s = s.replaceAllMapped(RegExp(r'\d+'),
      (m) => ' ${numberToWords(int.parse(m[0]!))} ');
  final words = RegExp(r"[a-z]+(?:'[a-z]+)?")
      .allMatches(s)
      .map((m) => m[0]!)
      .toList();
  return words;
}
