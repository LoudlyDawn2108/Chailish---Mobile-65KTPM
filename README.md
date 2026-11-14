# Ailish – Học tiếng Anh với phân tích phát âm AI

Bài thực hành **TH3** – Môn Phát triển ứng dụng di động – **Nhóm 11**
Flutter · Android

| MSSV | Họ tên | Module |
|---|---|---|
| 2351170611 | Nguyễn Hồng Phúc (NT) | M1 – Kiến trúc, engine chấm điểm phát âm, Azure |
| 2351170601 | Lê Tuấn Khanh | M2 – Thu âm, nhận dạng giọng nói, TTS, từ điển phát âm |
| 2351170593 | Đinh Thị Hoa | M3 – Bài học, màn hình phản hồi, gợi ý bài tập, UI |
| 2251172273 | Chu Hữu Đệ | M4 – CSDL, hồ sơ, lịch sử, thông báo, cài đặt |
| 2251172249 | Phạm Vũ Ngọc Bảo | M5 – Streak, thống kê, mục tiêu ngày, kiểm thử |

Chi tiết phân công: [PHAN_CONG.md](PHAN_CONG.md) · Kế hoạch kiểm thử: [KIEM_THU.md](KIEM_THU.md)

---

## 1. Tính năng

### Tính kỷ luật
- **Streak**: đếm số ngày luyện liên tiếp, lưu kỷ lục, cảnh báo "sắp mất streak".
- **Mục tiêu hằng ngày** (phút/ngày), vòng tiến độ hôm nay, 7 chấm cho 7 ngày gần nhất.
- **Đo thời gian học thực tế** trên màn hình luyện tập (tự dừng khi app chạy nền).
- **Thống kê**: biểu đồ phút học và điểm trung bình (7/30 ngày), lịch heatmap 12 tuần, tổng thời gian, tổng lượt, độ chính xác theo từng âm vị.
- **Thông báo nhắc nhở**: nhắc hằng ngày theo giờ người dùng chọn và nhắc 20:00 nếu hôm nay chưa luyện. Bấm vào thông báo sẽ mở tab Bài học.

### Phân tích phát âm bằng AI
- 13 bài học / 114 từ và câu, chia 3 cấp độ, có IPA và nghĩa tiếng Việt. Có các bài riêng cho âm khó với người Việt: /θ/ /ð/, /r/–/l/, /iː/–/ɪ/, /s/–/ʃ/–/z/, âm cuối, /æ/–/e/.
- **Nghe mẫu** (TTS, tốc độ thường hoặc chậm) → **nói** → **chấm điểm**.
- Có hai engine chấm điểm:
  1. **So sánh âm vị (offline, mặc định)**: bộ nhận dạng giọng nói của Android → chuẩn hoá văn bản → tra phiên âm CMUdict (135k từ, G2P dự phòng) → căn chỉnh Levenshtein 2 cấp (từ rồi âm vị) có trọng số theo các cặp âm dễ nhầm.
  2. **Azure AI Pronunciation Assessment**: ghi âm WAV rồi gọi REST API, nhận điểm từng âm vị trực tiếp từ âm thanh. Cần nhập key trong Cài đặt.
- **Phản hồi**:
  - điểm tổng, Độ chính xác, Độ trôi chảy, Độ đầy đủ;
  - tô màu từng từ (đúng/sai/bỏ sót/thừa); bấm vào từ để xem bảng âm chuẩn và âm bạn phát ra;
  - mẹo khẩu hình cho từng âm sai, lỗi hay gặp của người Việt;
  - **bài tập gợi ý** gồm các từ chứa âm sai, bấm "Luyện ngay";
  - nghe lại bản ghi (chế độ Azure).
- Trang chủ gợi ý các âm hay sai dựa trên lịch sử dài hạn.

### Lưu trữ dữ liệu
- SQLite gồm các bảng: `users`, `lessons`, `lesson_items`, `practice_sessions`, `attempts`, `phoneme_results`, `daily_stats`, `streaks`, `weak_phonemes`. Xem `lib/core/db/app_database.dart`.
- Hỗ trợ **nhiều hồ sơ** trên một máy, mỗi hồ sơ ghi giới tính và giọng vùng miền.
- **Xuất CSV** toàn bộ kết quả để phân tích kiểm thử.

## 2. Cài đặt và chạy

Yêu cầu: Flutter 3.47 trở lên (Dart 3.13), Android SDK 37, JDK 17, thiết bị Android 7.0 (API 24) trở lên.

```bash
flutter pub get
flutter run                 # chạy trên điện thoại/emulator đã kết nối
flutter build apk --release # file: build/app/outputs/flutter-apk/app-release.apk
```

> Chế độ offline cần dịch vụ nhận dạng giọng nói của Google, thường có sẵn trên đa số máy Android. Nếu muốn nhận dạng khi không có mạng, vào *Cài đặt Android → Google → Nhận dạng giọng nói → Tải ngôn ngữ English (US)*.

### Bật chấm điểm Azure (tuỳ chọn)
1. Tạo tài nguyên **Speech** trên Azure Portal, gói **F0 miễn phí** (5 giờ âm thanh/tháng).
2. Trong app: **Cài đặt → Chấm điểm phát âm → Azure**, nhập *Key* và *Region* (ví dụ `southeastasia`).
3. Key chỉ lưu trên máy (`shared_preferences`), **không commit vào repo**.

### Sinh lại dữ liệu bài học
Sửa danh sách trong `tool/build_lessons.py` rồi chạy:
```bash
python3 tool/build_lessons.py   # tự tra IPA từ CMUdict -> assets/data/lessons.json
```
App so sánh mã băm nội dung và tự nạp lại vào CSDL ở lần khởi động sau.

## 3. Cấu trúc dự án

```
Ailish/
├── lib/                              # Mã nguồn Flutter (Dart)
│   ├── main.dart                     # Điểm khởi động: mở CSDL, nạp bài học, khởi tạo thông báo, chạy app
│   ├── app/                          # Khung ứng dụng
│   │   ├── app.dart                  # MaterialApp (tiếng Việt), 4 tab: Trang chủ · Bài học · Tiến độ · Cài đặt
│   │   └── theme.dart                # Màu sắc, theme sáng/tối, màu theo điểm (xanh/vàng/đỏ)
│   ├── core/                         # Phần dùng chung cho mọi module
│   │   ├── providers.dart            # Khai báo toàn bộ provider Riverpod (nối các service với màn hình)
│   │   ├── db/
│   │   │   ├── app_database.dart     # Lược đồ SQLite 10 bảng, tạo bảng, nâng cấp phiên bản
│   │   │   └── repositories.dart     # Đọc/ghi CSDL: người dùng, bài học, lượt đọc, thống kê, streak, âm yếu
│   │   ├── models/
│   │   │   ├── user_profile.dart     # Hồ sơ người học (trình độ, giới tính, giọng miền, mục tiêu, giờ nhắc)
│   │   │   ├── lesson.dart           # Bài học và từng từ/câu (IPA, nghĩa, âm vị)
│   │   │   ├── pronunciation_result.dart # Kết quả chấm: điểm tổng, từng từ, từng âm vị (chung cho offline và Azure)
│   │   │   └── progress_models.dart  # Thống kê theo ngày, âm hay sai, bản ghi lịch sử, tiến độ bài học
│   │   ├── services/
│   │   │   ├── settings_service.dart # Cài đặt lưu bằng SharedPreferences (engine chấm, key Azure, tốc độ đọc)
│   │   │   └── export_service.dart   # Xuất toàn bộ kết quả ra file CSV để phân tích kiểm thử
│   │   └── widgets/
│   │       └── common_widgets.dart   # Widget dùng chung: vòng điểm, thanh điểm, chip âm vị, trạng thái trống
│   └── features/                     # Mỗi thư mục là một chức năng
│       ├── auth_profile/             # Hồ sơ và cài đặt
│       │   ├── profile_select_screen.dart # Chọn / thêm người học (nhiều người trên một máy)
│       │   ├── profile_form_screen.dart   # Tạo / sửa hồ sơ, đặt mục tiêu phút/ngày và giờ nhắc
│       │   └── settings_screen.dart       # Cài đặt: mục tiêu, nhắc nhở, engine chấm, Azure, lịch sử, xuất CSV, xoá dữ liệu
│       ├── lessons/
│       │   ├── lessons_screen.dart        # Danh sách bài học theo 3 cấp độ, tiến độ từng bài
│       │   └── lesson_detail_screen.dart  # Chi tiết bài: mẹo phát âm, danh sách từ/câu
│       ├── recording/                # Thu âm và nhận dạng giọng nói
│       │   ├── practice_screen.dart       # Màn hình luyện: nghe mẫu → bấm micro → chấm điểm; đo thời gian học
│       │   ├── speech_service.dart        # Gọi API nhận dạng giọng nói Android (speech_to_text) hoặc ghi WAV cho Azure
│       │   └── tts_service.dart           # Đọc mẫu bằng Text-to-Speech (tốc độ thường / chậm)
│       ├── pronunciation/            # Chấm điểm phát âm (AI / so sánh âm vị)
│       │   ├── pronunciation_service.dart # Chọn engine: offline, hoặc gửi WAV lên REST API Azure; trả về PronunciationResult
│       │   └── engine/
│       │       ├── text_normalizer.dart       # Chuẩn hoá văn bản nhận dạng: số → chữ ("3" → three), tách từ
│       │       ├── pronouncing_dictionary.dart # Nạp từ điển CMUdict, tra phiên âm, G2P dự phòng cho từ lạ
│       │       ├── phonemes.dart              # Bảng âm vị ARPAbet ↔ IPA, nhóm âm dễ nhầm với người Việt
│       │       ├── aligner.dart               # Thuật toán Levenshtein có trọng số (căn chỉnh 2 chuỗi)
│       │       ├── offline_scorer.dart        # Chấm điểm offline: căn chỉnh 2 cấp từ → âm vị, tính các điểm
│       │       └── azure_parser.dart          # Đọc JSON kết quả Azure, đổi âm vị SAPI sang ARPAbet
│       ├── feedback/                 # Phản hồi sau khi chấm
│       │   ├── feedback_screen.dart       # Điểm số, tô màu từng từ, bảng âm vị, mẹo, bài tập gợi ý
│       │   ├── phoneme_tips.dart          # Mẹo khẩu hình và lỗi người Việt hay gặp cho từng âm
│       │   └── exercise_recommender.dart  # Chọn từ/bài cần luyện thêm dựa trên âm hay sai
│       ├── progress/                 # Tiến độ và tính kỷ luật
│       │   ├── home_screen.dart           # Trang chủ: streak, vòng mục tiêu hôm nay, 7 ngày gần nhất, âm hay sai
│       │   ├── stats_screen.dart          # Tab Tiến độ: biểu đồ phút học, điểm TB, lịch 12 tuần, độ chính xác theo âm
│       │   ├── streak_calculator.dart     # Tính streak hiện tại và kỷ lục (Dart thuần, có unit test)
│       │   └── progress_service.dart      # Sau mỗi lượt đọc: cập nhật thống kê, streak, đặt lại lịch nhắc
│       ├── notifications/
│       │   └── notification_service.dart  # Nhắc hằng ngày theo giờ chọn + nhắc 20:00 nếu sắp mất streak
│       └── history/
│           └── history_screen.dart        # Lịch sử luyện tập theo ngày, mở lại kết quả cũ
├── assets/data/
│   ├── lessons.json                  # 13 bài học / 114 từ và câu (sinh bằng tool/build_lessons.py)
│   └── cmudict.dict                  # Từ điển phát âm CMU (~135k từ, ký hiệu ARPAbet)
├── test/                             # 39 kiểm thử tự động (xem mục 4)
├── tool/build_lessons.py             # Script sinh lessons.json, tự tra IPA từ CMUdict
├── android/                          # Cấu hình Android: quyền micro/thông báo/Internet (AndroidManifest.xml),
│                                     # compileSdk 37, minSdk 24 (app/build.gradle.kts)
├── minh_chung/                       # Video và ảnh minh chứng 7 mục checklist
├── pubspec.yaml                      # Khai báo thư viện và assets
├── PHAN_CONG.md                      # Phân công công việc 5 thành viên
└── KIEM_THU.md                       # Kế hoạch và kết quả kiểm thử
```

### File nào làm phần nào của checklist

| Mục checklist | File chính | Phụ trách |
|---|---|---|
| 1. CSDL người dùng, lịch sử, kết quả phát âm | `core/db/app_database.dart`, `core/db/repositories.dart`, `core/models/*`, `features/history/history_screen.dart`, `core/services/export_service.dart` | Phúc (schema), Đệ |
| 2. Streak, thời gian học, mục tiêu ngày | `features/progress/streak_calculator.dart`, `progress_service.dart`, `home_screen.dart`, `recording/practice_screen.dart` (đo giờ học), `auth_profile/profile_form_screen.dart` (đặt mục tiêu) | Bảo, Đệ |
| 3. API nhận dạng giọng nói, thu âm | `features/recording/speech_service.dart`, `practice_screen.dart`, `tts_service.dart` | Khanh |
| 4. AI / so sánh âm vị, chấm điểm | `features/pronunciation/engine/*`, `pronunciation_service.dart` | Phúc, Khanh (từ điển, chuẩn hoá) |
| 5. Phản hồi: điểm, âm sai, bài tập | `features/feedback/*`, `core/widgets/common_widgets.dart` | Hoa |
| 6. Nhắc nhở + giao diện tiến độ | `features/notifications/notification_service.dart`, `features/progress/stats_screen.dart`, `home_screen.dart` | Đệ, Bảo |
| 7. Kiểm thử nhiều người dùng, giọng nói | `auth_profile/profile_select_screen.dart` (nhiều hồ sơ), `core/services/export_service.dart` (CSV), `test/*`, `KIEM_THU.md` | Bảo, cả nhóm |

### Luồng xử lý một lượt luyện phát âm

```
LessonsScreen → PracticeScreen
   │ bấm "Nghe mẫu"  → TtsService
   │ bấm micro       → SpeechService  (Android SpeechRecognizer → câu nhận dạng; hoặc ghi WAV cho Azure)
   ▼
PronunciationService ── offline → TextNormalizer → PronouncingDictionary → Aligner → OfflineScorer
                     └─ Azure   → REST API (trong PronunciationService) → AzureParser
   ▼ PronunciationResult
AttemptRepository (lưu attempts + phoneme_results) → ProgressService (daily_stats, streaks, weak_phonemes, lịch nhắc)
   ▼
FeedbackScreen (điểm, tô màu từ, mẹo từ PhonemeTips, bài tập từ ExerciseRecommender)
```

## 4. Kiểm thử tự động

```bash
flutter analyze   # không có lỗi
flutter test      # 39 test
```

| File | Nội dung |
|---|---|
| `test/engine/offline_scorer_test.dart` | Chấm điểm với lỗi điển hình của người Việt: think→sink, rice→lice, nice→nigh (nuốt âm cuối), sheep→ship, bỏ từ, thêm từ, số "3"/"3:00", đọc chậm |
| `test/engine/azure_parser_test.dart` | Phân tích JSON phản hồi của Azure |
| `test/progress/streak_test.dart` | Streak: ngày trống, qua tháng/năm, trùng ngày, chưa luyện hôm nay |
| `test/feedback/recommender_test.dart` | Gợi ý bài tập |
| `test/db/repositories_test.dart` | CSDL: nạp bài học, lưu kết quả, thống kê, streak, âm yếu, xoá dây chuyền |
| `test/widget/feedback_screen_test.dart` | Giao diện màn hình phản hồi |
| `test/widget/app_smoke_test.dart` | Chạy toàn app ở kích thước điện thoại (dọc và ngang): 4 tab, bài học, luyện tập, lịch sử, đổi người học; phát hiện lỗi tràn bố cục |

Kiểm thử với người dùng thật và nhiều giọng nói: xem [KIEM_THU.md](KIEM_THU.md).

## 5. Thuật toán chấm điểm offline (tóm tắt)

```
câu mẫu  ──tokenize──► [i, think, this]  ──CMUdict──► [AY] [TH IH NG K] [DH IH S]
câu nghe ──tokenize──► [i, sink, this]   ──CMUdict──► [AY] [S IH NG K]  [DH IH S]
              │
              ├─ Căn chỉnh cấp TỪ (Levenshtein, chi phí = khoảng cách âm vị giữa 2 từ)
              └─ Căn chỉnh cấp ÂM VỊ cho từng cặp từ:
                   khớp = 100 · thay bằng âm dễ nhầm (TH↔S, R↔L, IY↔IH...) = 50
                   thay bằng âm khác hẳn = 0 · bỏ sót = 0 · âm thừa: trừ điểm từ
Accuracy     = trung bình điểm âm vị (điều chỉnh theo độ tin cậy của bộ nhận dạng)
Completeness = số từ đã đọc / tổng số từ
Fluency      = tốc độ nói (từ/giây) và số từ thừa/ngập ngừng
Tổng         = (0.6·Accuracy + 0.2·Fluency)·Completeness/100 + 0.2·Completeness − 8·(số từ thừa, tối đa 40)
```

**Hạn chế**: bộ nhận dạng giọng nói luôn cố "đoán" ra một từ có thật, nên với lỗi nhỏ nó có thể vẫn trả về đúng từ mẫu. Vì vậy engine offline là phép xấp xỉ. Engine Azure chấm từng âm vị trực tiếp từ âm thanh nên chính xác hơn. Báo cáo kiểm thử cần so sánh hai engine (xem KIEM_THU.md).

chuyển thành ứng ứng dụng tiếng trung, dạy viết hán tự, # Chailish---Mobile-65KTPM
