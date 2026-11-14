#!/usr/bin/env python3
"""Sinh file assets/data/lessons.json từ danh sách bài học bên dưới.

Phụ trách nội dung: Đinh Thị Hoa (M3). Script tra phiên âm từ CMUdict
(ARPAbet) và đổi sang IPA để hiển thị.

Chạy:  python3 tool/build_lessons.py
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DICT = os.path.join(ROOT, "assets", "data", "cmudict.dict")
OUT = os.path.join(ROOT, "assets", "data", "lessons.json")

# --- ARPAbet -> IPA (giống lib/features/pronunciation/engine/phonemes.dart) ---
IPA = {
    "AA": "ɑː", "AE": "æ", "AH": "ʌ", "AO": "ɔː", "AW": "aʊ", "AY": "aɪ",
    "B": "b", "CH": "tʃ", "D": "d", "DH": "ð", "EH": "e", "ER": "ɜːr",
    "EY": "eɪ", "F": "f", "G": "ɡ", "HH": "h", "IH": "ɪ", "IY": "iː",
    "JH": "dʒ", "K": "k", "L": "l", "M": "m", "N": "n", "NG": "ŋ",
    "OW": "oʊ", "OY": "ɔɪ", "P": "p", "R": "r", "S": "s", "SH": "ʃ",
    "T": "t", "TH": "θ", "UH": "ʊ", "UW": "uː", "V": "v", "W": "w",
    "Y": "j", "Z": "z", "ZH": "ʒ",
}


VOWELS = {"AA", "AE", "AH", "AO", "AW", "AY", "EH", "ER", "EY", "IH",
          "IY", "OW", "OY", "UH", "UW"}


def to_ipa(phones):
    """ARPAbet (có số trọng âm) -> IPA. Dấu trọng âm ˈ chỉ đặt cho từ
    nhiều âm tiết, trước phụ âm đứng ngay trước nguyên âm được nhấn."""
    syms, bases, stressed = [], [], -1
    for i, p in enumerate(phones):
        base = re.sub(r"\d", "", p)
        stress = p[-1] if p[-1].isdigit() else ""
        if base == "AH" and stress == "0":
            sym = "ə"
        elif base == "ER" and stress == "0":
            sym = "ər"
        else:
            sym = IPA[base]
        if stress == "1" and stressed < 0:
            stressed = i
        syms.append(sym)
        bases.append(base)
    n_vowels = sum(1 for b in bases if b in VOWELS)
    if n_vowels > 1 and stressed >= 0:
        pos = stressed
        if all(b not in VOWELS for b in bases[:stressed]):
            pos = 0
        elif stressed > 0 and bases[stressed - 1] not in VOWELS:
            pos = stressed - 1
        syms.insert(pos, "ˈ")
    return "".join(syms)


def load_dict():
    d = {}
    with open(DICT, encoding="utf-8") as f:
        for line in f:
            line = line.split("#")[0].strip()
            if not line:
                continue
            parts = line.split()
            word = re.sub(r"\(\d+\)$", "", parts[0])
            d.setdefault(word, parts[1:])  # chỉ lấy cách đọc đầu tiên
    return d


# (id, title, level, topic, focus phonemes, description, [(text, meaning_vi)])
LESSONS = [
    ("greetings", "Chào hỏi cơ bản", 1, "Giao tiếp", [],
     "Các câu chào hỏi thường gặp hằng ngày.",
     [("hello", "xin chào"), ("thank you", "cảm ơn bạn"),
      ("good morning", "chào buổi sáng"), ("how are you", "bạn khoẻ không"),
      ("nice to meet you", "rất vui được gặp bạn"), ("goodbye", "tạm biệt"),
      ("please", "làm ơn"), ("sorry", "xin lỗi")]),
    ("numbers", "Số đếm", 1, "Từ vựng", ["TH", "R"],
     "Các số đếm, chú ý âm /θ/ trong three, thirteen, thirty.",
     [("one", "một"), ("two", "hai"), ("three", "ba"), ("four", "bốn"),
      ("five", "năm"), ("seven", "bảy"), ("eight", "tám"),
      ("thirteen", "mười ba"), ("thirty", "ba mươi"), ("hundred", "một trăm")]),
    ("family", "Gia đình", 1, "Từ vựng", ["DH", "ER"],
     "Từ vựng về các thành viên trong gia đình.",
     [("mother", "mẹ"), ("father", "bố"), ("brother", "anh/em trai"),
      ("sister", "chị/em gái"), ("family", "gia đình"),
      ("children", "trẻ con"), ("daughter", "con gái"), ("son", "con trai")]),
    ("objects", "Đồ vật quanh ta", 1, "Từ vựng", [],
     "Đồ vật quen thuộc trong nhà và lớp học.",
     [("water", "nước"), ("table", "cái bàn"), ("phone", "điện thoại"),
      ("book", "quyển sách"), ("bag", "cái túi"), ("chair", "cái ghế"),
      ("window", "cửa sổ"), ("kitchen", "nhà bếp")]),
    ("th_sounds", "Âm /θ/ và /ð/", 2, "Âm khó", ["TH", "DH"],
     "Đặt đầu lưỡi giữa hai hàm răng rồi thổi hơi. /θ/ không rung dây thanh, /ð/ có rung.",
     [("think", "nghĩ"), ("three", "ba"), ("thank", "cảm ơn"),
      ("bath", "bồn tắm"), ("mouth", "miệng"), ("this", "cái này"),
      ("that", "cái kia"), ("they", "họ"), ("weather", "thời tiết"),
      ("brother", "anh trai")]),
    ("r_l", "Phân biệt /r/ và /l/", 2, "Âm khó", ["R", "L"],
     "/r/: cong lưỡi về sau, không chạm vòm miệng. /l/: đầu lưỡi chạm lợi trên.",
     [("right", "đúng / bên phải"), ("light", "ánh sáng"), ("rice", "cơm"),
      ("lice", "chấy"), ("red", "màu đỏ"), ("led", "đã dẫn dắt"),
      ("fry", "chiên"), ("fly", "bay"), ("road", "con đường"),
      ("load", "chất hàng"), ("grass", "cỏ"), ("glass", "cái cốc")]),
    ("long_short_i", "Nguyên âm /iː/ và /ɪ/", 2, "Âm khó", ["IY", "IH"],
     "/iː/ kéo dài, môi bành sang hai bên. /ɪ/ ngắn, thả lỏng.",
     [("sheep", "con cừu"), ("ship", "con tàu"), ("leave", "rời đi"),
      ("live", "sống"), ("seat", "chỗ ngồi"), ("sit", "ngồi"),
      ("feel", "cảm thấy"), ("fill", "làm đầy"), ("beat", "đánh"),
      ("bit", "một chút")]),
    ("s_sh_z", "Âm /s/, /ʃ/ và /z/", 2, "Âm khó", ["S", "SH", "Z"],
     "/ʃ/ chu môi về phía trước. /z/ giống /s/ nhưng rung dây thanh.",
     [("see", "nhìn"), ("she", "cô ấy"), ("sip", "nhấp môi"),
      ("ship", "con tàu"), ("sell", "bán"), ("shell", "vỏ sò"),
      ("zoo", "sở thú"), ("zero", "số không"), ("busy", "bận rộn"),
      ("lazy", "lười biếng")]),
    ("final_consonants", "Âm cuối", 2, "Âm khó", ["T", "D", "K", "S", "V"],
     "Người Việt hay nuốt âm cuối. Hãy bật rõ âm cuối của mỗi từ.",
     [("cat", "con mèo"), ("bad", "tệ"), ("book", "quyển sách"),
      ("dog", "con chó"), ("five", "năm"), ("nice", "đẹp"),
      ("hand", "bàn tay"), ("desk", "bàn học"), ("fast", "nhanh"),
      ("world", "thế giới")]),
    ("ae_e", "Nguyên âm /æ/ và /e/", 2, "Âm khó", ["AE", "EH"],
     "/æ/ mở miệng rộng, hạ hàm dưới. /e/ mở miệng vừa phải.",
     [("bad", "tệ"), ("bed", "giường"), ("man", "người đàn ông"),
      ("men", "những người đàn ông"), ("sad", "buồn"), ("said", "đã nói"),
      ("pan", "cái chảo"), ("pen", "cây bút"), ("apple", "quả táo"),
      ("happy", "vui vẻ")]),
    ("daily_sentences", "Câu giao tiếp hằng ngày", 3, "Câu", [],
     "Luyện đọc trôi chảy cả câu, chú ý nối âm và ngữ điệu.",
     [("Could you help me please", "Bạn giúp tôi được không"),
      ("I would like a cup of coffee", "Tôi muốn một tách cà phê"),
      ("What time is it now", "Bây giờ là mấy giờ"),
      ("Where is the nearest station", "Nhà ga gần nhất ở đâu"),
      ("I am learning English every day", "Tôi học tiếng Anh mỗi ngày"),
      ("Nice to meet you too", "Tôi cũng rất vui được gặp bạn")]),
    ("travel_work", "Du lịch và công việc", 3, "Câu", [],
     "Các câu thông dụng khi đi du lịch và đi làm.",
     [("Can I have the bill please", "Cho tôi xin hoá đơn"),
      ("My flight leaves at three o'clock", "Chuyến bay của tôi lúc ba giờ"),
      ("I usually work from nine to five", "Tôi thường làm từ chín giờ đến năm giờ"),
      ("Is there a restaurant near here", "Gần đây có nhà hàng không"),
      ("I need to book a room for two nights", "Tôi cần đặt phòng hai đêm"),
      ("The meeting starts tomorrow morning", "Cuộc họp bắt đầu sáng mai")]),
    ("tongue_twisters", "Câu luyện lưỡi", 3, "Câu", ["TH", "S", "SH", "R", "L"],
     "Câu khó để luyện độ chính xác và tốc độ.",
     [("She sells sea shells by the sea shore", "Cô ấy bán vỏ sò bên bờ biển"),
      ("Three thin thieves thought a thousand thoughts", "Ba tên trộm gầy nghĩ hàng nghìn ý nghĩ"),
      ("Red lorry yellow lorry", "Xe tải đỏ, xe tải vàng"),
      ("I think this is the right way", "Tôi nghĩ đây là đường đúng"),
      ("The weather is very nice today", "Hôm nay thời tiết rất đẹp"),
      ("Practice makes perfect", "Có công mài sắt có ngày nên kim")]),
]


def main():
    d = load_dict()
    lessons = []
    missing = []
    for order, (lid, title, level, topic, focus, desc, items) in enumerate(LESSONS):
        out_items = []
        for i, (text, meaning) in enumerate(items):
            words = re.findall(r"[a-zA-Z']+", text.lower())
            phon_words = []
            for w in words:
                if w not in d:
                    missing.append(w)
                    continue
                phon_words.append(d[w])
            out_items.append({
                "id": f"{lid}_{i + 1}",
                "text": text,
                "meaning": meaning,
                "type": "sentence" if len(words) > 2 else "word",
                "ipa": "/" + " ".join(to_ipa(p) for p in phon_words) + "/",
                "phonemes": " | ".join(" ".join(p) for p in phon_words),
            })
        lessons.append({
            "id": lid, "title": title, "level": level, "topic": topic,
            "focus": focus, "description": desc, "order": order,
            "items": out_items,
        })
    if missing:
        print("Từ không có trong CMUdict:", sorted(set(missing)), file=sys.stderr)
        sys.exit(1)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump({"version": 1, "lessons": lessons}, f, ensure_ascii=False, indent=1)
    print(f"Đã ghi {len(lessons)} bài học, "
          f"{sum(len(l['items']) for l in lessons)} mục -> {OUT}")


if __name__ == "__main__":
    main()
