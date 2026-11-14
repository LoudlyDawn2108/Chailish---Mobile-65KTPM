// Module M3 – Mẹo phát âm cho từng âm vị · Phụ trách: Đinh Thị Hoa
//
// Nội dung tham khảo: bảng IPA tiếng Anh-Mỹ và các lỗi phổ biến của người
// Việt khi học tiếng Anh.

class PhonemeTip {
  const PhonemeTip(this.howTo, this.examples, [this.commonMistake]);
  final String howTo;
  final List<String> examples;
  final String? commonMistake;
}

const Map<String, PhonemeTip> kPhonemeTips = {
  // ---- Nguyên âm ----
  'IY': PhonemeTip('Kéo dài âm "i", môi bành sang hai bên như đang cười.',
      ['see', 'sheep', 'tea'], 'Đọc ngắn thành /ɪ/ (sheep → ship).'),
  'IH': PhonemeTip('Âm "i" ngắn, thả lỏng miệng, lưỡi hơi hạ thấp.',
      ['sit', 'ship', 'big'], 'Kéo dài thành /iː/ (ship → sheep).'),
  'EH': PhonemeTip('Mở miệng vừa phải, giống "e" trong tiếng Việt.',
      ['bed', 'pen', 'red'], 'Nhầm với /æ/ hoặc /eɪ/.'),
  'AE': PhonemeTip(
      'Mở miệng rộng, hạ hàm dưới, âm nằm giữa "a" và "e".',
      ['cat', 'bad', 'apple'],
      'Đọc thành "e" (bad → bed).'),
  'AA': PhonemeTip('Mở miệng thật rộng, lưỡi hạ thấp, âm "a" dài.',
      ['car', 'father', 'hot']),
  'AO': PhonemeTip('Tròn môi, âm "o" dài, phát ra từ sâu trong họng.',
      ['saw', 'law', 'thought']),
  'AH': PhonemeTip('Âm "ơ/ă" ngắn, miệng thả lỏng, không tròn môi.',
      ['cup', 'love', 'about']),
  'UH': PhonemeTip('Âm "u" ngắn, môi tròn nhẹ và thả lỏng.',
      ['book', 'good', 'foot'], 'Kéo dài thành /uː/.'),
  'UW': PhonemeTip('Âm "u" dài, chu môi tròn về phía trước.',
      ['food', 'two', 'blue']),
  'ER': PhonemeTip('Âm "ơ" kèm cong lưỡi lên (âm r của Mỹ).',
      ['bird', 'work', 'learn'], 'Bỏ mất phần cong lưỡi.'),
  'EY': PhonemeTip('Nguyên âm đôi: bắt đầu từ "e" rồi trượt sang "i".',
      ['day', 'name', 'eight'], 'Chỉ đọc "e" mà không trượt sang "i".'),
  'AY': PhonemeTip('Nguyên âm đôi: từ "a" trượt sang "i" ("ai").',
      ['my', 'time', 'five']),
  'OY': PhonemeTip('Nguyên âm đôi: từ "o" trượt sang "i" ("oi").',
      ['boy', 'toy', 'voice']),
  'AW': PhonemeTip('Nguyên âm đôi: từ "a" trượt sang "u" ("ao").',
      ['now', 'house', 'mouth']),
  'OW': PhonemeTip('Nguyên âm đôi: từ "ô" trượt sang "u", môi tròn dần.',
      ['go', 'phone', 'know'], 'Chỉ đọc "ô" mà không trượt.'),
  // ---- Phụ âm ----
  'TH': PhonemeTip(
      'Đặt đầu lưỡi giữa hai hàm răng, thổi hơi ra. Không rung dây thanh.',
      ['think', 'three', 'bath'],
      'Đọc thành /t/, /s/ hoặc "th" tiếng Việt (think → tink/sink).'),
  'DH': PhonemeTip(
      'Đặt đầu lưỡi giữa hai hàm răng như /θ/ nhưng RUNG dây thanh.',
      ['this', 'that', 'mother'],
      'Đọc thành /d/ hoặc /z/ (this → dis).'),
  'R': PhonemeTip(
      'Cong lưỡi về phía sau, KHÔNG chạm vòm miệng, môi hơi tròn.',
      ['red', 'right', 'rice'],
      'Đọc thành /l/ hoặc "r" rung của tiếng Việt.'),
  'L': PhonemeTip('Đầu lưỡi chạm vào lợi phía sau răng cửa trên.',
      ['light', 'love', 'feel'],
      'Bỏ âm /l/ cuối từ (feel → fee) hoặc nhầm với /r/, /n/.'),
  'S': PhonemeTip('Răng gần khít, đầu lưỡi gần lợi trên, thổi hơi "xì".',
      ['see', 'bus', 'nice'], 'Bỏ âm /s/ cuối từ (nice → nai).'),
  'Z': PhonemeTip('Giống /s/ nhưng rung dây thanh ("dz" nhẹ).',
      ['zoo', 'busy', 'is'], 'Đọc thành /s/ hoặc "d" tiếng Việt.'),
  'SH': PhonemeTip('Chu môi về phía trước, thổi hơi "suỵt".',
      ['she', 'ship', 'wash'], 'Đọc thành /s/ (she → see).'),
  'ZH': PhonemeTip('Giống /ʃ/ nhưng rung dây thanh.',
      ['usually', 'vision', 'measure']),
  'CH': PhonemeTip('Bắt đầu như /t/ rồi bật ra /ʃ/, môi chu ra.',
      ['chair', 'teacher', 'watch'], 'Đọc thành "ch" tiếng Việt (không bật hơi).'),
  'JH': PhonemeTip('Giống /tʃ/ nhưng rung dây thanh ("dj").',
      ['job', 'orange', 'bridge'], 'Đọc thành "gi/d" tiếng Việt.'),
  'T': PhonemeTip('Đầu lưỡi chạm lợi trên rồi bật hơi mạnh.',
      ['top', 'cat', 'eight'], 'Nuốt âm /t/ cuối từ (cat → ca).'),
  'D': PhonemeTip('Giống /t/ nhưng rung dây thanh, bật nhẹ hơn.',
      ['dog', 'bad', 'red'], 'Bỏ âm /d/ cuối từ.'),
  'K': PhonemeTip('Cuống lưỡi chạm vòm mềm rồi bật hơi.',
      ['cat', 'book', 'desk'], 'Nuốt âm /k/ cuối từ.'),
  'G': PhonemeTip('Giống /k/ nhưng rung dây thanh.',
      ['go', 'dog', 'bag']),
  'P': PhonemeTip('Mím hai môi rồi bật hơi mạnh.',
      ['pen', 'cup', 'happy'], 'Không bật hơi hoặc bỏ âm cuối.'),
  'B': PhonemeTip('Mím hai môi rồi bật ra, có rung dây thanh.',
      ['bad', 'job', 'baby']),
  'F': PhonemeTip('Răng trên chạm nhẹ môi dưới, thổi hơi.',
      ['five', 'phone', 'coffee']),
  'V': PhonemeTip('Răng trên chạm môi dưới như /f/ nhưng rung dây thanh.',
      ['very', 'five', 'live'], 'Bỏ âm /v/ cuối từ (five → fai).'),
  'M': PhonemeTip('Mím môi, đẩy hơi qua mũi.', ['man', 'time', 'mother']),
  'N': PhonemeTip('Đầu lưỡi chạm lợi trên, đẩy hơi qua mũi.',
      ['nine', 'man', 'phone']),
  'NG': PhonemeTip('Cuống lưỡi chạm vòm mềm, đẩy hơi qua mũi ("ng").',
      ['sing', 'thinking', 'long'], 'Thêm âm /g/ hoặc đọc thành /n/.'),
  'HH': PhonemeTip('Thở hơi nhẹ ra từ cổ họng.', ['hello', 'house', 'happy'],
      'Bỏ mất âm /h/ đầu từ.'),
  'W': PhonemeTip('Chu tròn môi rồi mở nhanh ("qu").',
      ['water', 'way', 'world'], 'Đọc thành /v/.'),
  'Y': PhonemeTip('Giống "d" miền Nam / "gi" nhẹ: lưỡi nâng gần vòm cứng.',
      ['yes', 'you', 'yellow']),
};

PhonemeTip tipFor(String phoneme) =>
    kPhonemeTips[phoneme.replaceAll(RegExp(r'\d'), '')] ??
    const PhonemeTip('Nghe mẫu nhiều lần và bắt chước khẩu hình.', []);
