# PHÂN CÔNG CÔNG VIỆC – NHÓM 11

**Đề tài (TH3):** Ứng dụng học tiếng Anh với tính năng phân tích phát âm AI
**Nền tảng:** Flutter (Android)
**Tên dự án:** Ailish
**Nhóm trưởng:** Nguyễn Hồng Phúc (2351170611)

> Nguyên tắc: **ai cũng code**. Mỗi người sở hữu **1 module chính** (code + UI + test của module đó) và **1 việc phụ** hỗ trợ nhóm. Module được tách theo thư mục để hạn chế conflict khi merge.

---

> **Trạng thái (03/11/2026):** đã code xong toàn bộ 7 mục checklist. `flutter analyze` không lỗi, `flutter test` qua 39 test, đã build được APK.
> **Việc còn lại của nhóm:**
> (1) mỗi người đọc kỹ code trong thư mục mình phụ trách (mục 4) để trình bày và trả lời vấn đáp;
> (2) chạy thử trên điện thoại thật theo [KIEM_THU.md](KIEM_THU.md) mục 2;
> (3) kiểm thử với ≥ 15 người, nhiều giọng nói (KIEM_THU.md mục 3), rồi điền kết quả vào báo cáo.

---

## 1. Thành viên & vai trò

| MSSV | Họ tên | GPA | Điểm mạnh | Mục tiêu | Module chính | Việc phụ |
|---|---|---|---|---|---|---|
| 2351170611 | Nguyễn Hồng Phúc | 3.77 | Thiết kế, Tìm nội dung, Lập trình | A | **M1 – Kiến trúc + Engine chấm điểm phát âm (AI / phoneme comparison)** | Thiết kế CSDL, review code, tích hợp |
| 2351170601 | Lê Tuấn Khanh | 2.64 | Tìm nội dung, Lập trình | A | **M2 – Thu âm & Nhận dạng giọng nói (Speech Recognition)** | Hỗ trợ Phúc tích hợp API AI |
| 2351170593 | Đinh Thị Hoa | 3.28 | Thiết kế, Tìm nội dung | B | **M3 – Module phản hồi + Bài học/Bài tập** | Thiết kế UI/UX (Figma), soạn dữ liệu bài học |
| 2251172273 | Chu Hữu Đệ | 1.82 | Thiết kế, Tìm nội dung, Lập trình | B | **M4 – Cơ sở dữ liệu + Hồ sơ người dùng + Thông báo nhắc nhở** | Màn hình Cài đặt |
| 2251172249 | Phạm Vũ Ngọc Bảo | 2.15 | Thuyết trình, Thiết kế | B | **M5 – Theo dõi tiến độ: Streak, Thống kê, Mục tiêu ngày** | Trưởng nhóm kiểm thử, làm slide & thuyết trình |

**Lý do chia:**
- Phúc & Khanh (mục tiêu A, mạnh lập trình) nhận 2 phần khó nhất về kỹ thuật: AI chấm điểm và speech recognition, làm cặp với nhau vì 2 phần phụ thuộc chặt.
- Hoa mạnh thiết kế + tìm nội dung → làm UI/UX chung và màn hình phản hồi (phần “nhìn thấy” nhiều nhất), kèm soạn nội dung bài học.
- Đệ có kỹ năng lập trình → nhận phần CSDL + thông báo: rõ ràng, có tài liệu nhiều, schema đã được Phúc thiết kế sẵn nên dễ bám theo.
- Bảo mạnh thuyết trình + thiết kế → module tiến độ (nhiều UI biểu đồ, logic vừa phải), đồng thời điều phối kiểm thử và lo phần báo cáo/thuyết trình.

---

## 2. Đối chiếu Checklist yêu cầu → Người phụ trách

| # | Yêu cầu | Phụ trách chính | Hỗ trợ |
|---|---|---|---|
| 1 | Thiết kế CSDL lưu thông tin người dùng, lịch sử luyện tập, kết quả phân tích phát âm | Phúc (thiết kế schema) | Đệ (cài đặt) |
| 2 | Theo dõi tiến độ: streak, thống kê thời gian học, đặt mục tiêu hàng ngày | Bảo | Đệ |
| 3 | Tích hợp API nhận dạng giọng nói để thu âm & xử lý phát âm | Khanh | Phúc |
| 4 | Mô hình AI / thuật toán so sánh âm vị để phân tích & chấm điểm | Phúc | Khanh |
| 5 | Module phản hồi: điểm số, đánh dấu âm sai, đề xuất bài tập | Hoa | Phúc |
| 6 | Thông báo nhắc nhở hằng ngày + giao diện hiển thị tiến độ | Đệ (thông báo) + Bảo (giao diện tiến độ) | Hoa (UI) |
| 7 | Kiểm thử với nhiều người dùng & giọng nói khác nhau | Bảo (điều phối) | **Cả nhóm** |

---

## 3. Công nghệ sử dụng (đã chốt theo code thực tế)

| Hạng mục | Lựa chọn | Ghi chú |
|---|---|---|
| Framework | Flutter 3.47, Dart 3.13, Android (minSdk 24, compileSdk 37) | |
| State management | `flutter_riverpod` 3.x | Provider khai báo tập trung ở `lib/core/providers.dart` |
| Điều hướng | `Navigator` + `MaterialPageRoute`, `NavigationBar` 4 tab | Không dùng `go_router` cho gọn |
| CSDL local | `sqflite` | Lưu toàn bộ dữ liệu người dùng trên máy |
| Người dùng | Hồ sơ local, **nhiều hồ sơ trên 1 máy** | Phục vụ kiểm thử nhiều giọng nói |
| Thu âm | `record` + `permission_handler` | Ghi WAV 16 kHz mono (chế độ Azure) |
| Nhận dạng giọng nói | `speech_to_text` (Android SpeechRecognizer) | Chế độ offline (mặc định) |
| Chấm điểm AI | **Azure Speech – Pronunciation Assessment** (REST) | Tuỳ chọn, nhập key trong màn hình Cài đặt |
| Thuật toán so sánh âm vị | CMUdict (135k từ) + G2P dự phòng + Levenshtein có trọng số | Chạy offline, là chế độ mặc định |
| Phát âm mẫu | `flutter_tts` | Tốc độ thường / chậm |
| Nghe lại bản ghi | `audioplayers` | |
| Biểu đồ | `fl_chart` | Cột, đường, heatmap |
| Thông báo | `flutter_local_notifications` + `timezone` + `flutter_timezone` | Nhắc hằng ngày + nhắc giữ streak 20:00 |
| Xuất dữ liệu kiểm thử | `share_plus` (CSV) | |
| Cấu hình bí mật | Azure key nhập trong app, lưu `shared_preferences` | **Không** commit key vào repo |

---

## 4. Cấu trúc thư mục (mỗi người làm trong thư mục của mình)

```
lib/
├── main.dart                         # Phúc: khởi tạo DB, prefs, thông báo
├── app/                              # Phúc: app.dart (khung + tab), theme.dart (Hoa thiết kế)
├── core/
│   ├── providers.dart                # Phúc: khai báo Riverpod provider
│   ├── db/                           # Đệ: app_database.dart (schema), repositories.dart
│   ├── models/                       # Phúc + Đệ: lesson, user_profile, pronunciation_result, progress_models
│   ├── services/                     # Đệ: settings_service · Bảo: export_service (CSV)
│   └── widgets/                      # Hoa: ScoreRing, ScoreBar, PhonemeChip...
├── features/
│   ├── pronunciation/                # Phúc
│   │   ├── engine/                   #   phonemes, aligner, offline_scorer, azure_parser (Dart thuần)
│   │   │   ├── pronouncing_dictionary.dart   # Khanh: CMUdict + G2P
│   │   │   └── text_normalizer.dart          # Khanh: số -> chữ
│   │   └── pronunciation_service.dart
│   ├── recording/                    # Khanh: speech_service, tts_service, practice_screen
│   ├── lessons/                      # Hoa: lessons_screen, lesson_detail_screen
│   ├── feedback/                     # Hoa: feedback_screen, phoneme_tips, exercise_recommender
│   ├── auth_profile/                 # Đệ: chọn/tạo hồ sơ, cài đặt
│   ├── history/                      # Đệ: lịch sử luyện tập
│   ├── notifications/                # Đệ: notification_service
│   └── progress/                     # Bảo: streak_calculator, progress_service, home_screen, stats_screen
assets/data/
├── lessons.json                      # Hoa: 13 bài, 114 từ/câu (sinh bằng tool/build_lessons.py)
└── cmudict.dict                      # Khanh: CMU Pronouncing Dictionary
tool/build_lessons.py                 # Hoa: soạn bài học -> lessons.json (tự tra IPA)
test/                                 # engine/ (Phúc, Khanh) · progress/ (Bảo) · feedback/, widget/ (Hoa) · db/ (Đệ)
```

---

## 5. Thiết kế CSDL (đã cài đặt – `lib/core/db/app_database.dart`)

```
users            (id, name, level, accent, gender, daily_goal_minutes,
                  reminder_enabled, reminder_hour, reminder_minute, created_at)
lessons          (id, title, level, topic, focus, description, sort_order)
lesson_items     (id, lesson_id→lessons, text, meaning, type[word|sentence], ipa, phonemes, sort_order)
practice_sessions(id, user_id→users, lesson_id, started_at, ended_at, duration_sec)
attempts         (id, user_id→users, session_id→practice_sessions, item_id, reference_text,
                  recognized_text, audio_path, accuracy, fluency, completeness,
                  overall_score, engine[offline|azure], result_json, created_at)
phoneme_results  (id, attempt_id→attempts, word_index, word, expected_phoneme,
                  actual_phoneme, score, is_error)
daily_stats      (user_id, date, seconds, attempts, score_sum)       PK(user_id, date)
streaks          (user_id, current_streak, longest_streak, last_practice_date)
weak_phonemes    (user_id, phoneme, error_count, total_count, last_seen)  -- dùng để gợi ý bài tập
meta             (key, value)                                         -- mã băm lessons.json
```
Mọi khoá ngoại tới `users` có `ON DELETE CASCADE`: xoá hồ sơ thì xoá luôn dữ liệu của hồ sơ đó.

---

## 6. Chi tiết nhiệm vụ từng người

### 👤 Nguyễn Hồng Phúc – Nhóm trưởng · M1: Kiến trúc + Engine chấm điểm
**Code:**
- [ ] Khởi tạo project Flutter, cấu hình Riverpod, theme, lint (`flutter_lints`).
- [ ] Tạo repo GitHub, branch `main`/`develop`, quy tắc PR (xem mục 8).
- [ ] Định nghĩa **interface dùng chung** trong `core/services/` để mọi người code song song:
  - `PronunciationService.assess(audioPath, referenceText) → PronunciationResult`
  - `SpeechService.startRecording() / stopRecording() → audioPath`, `transcribe()`
  - `ProgressRepository`, `UserRepository`, `AttemptRepository`
- [ ] Thiết kế schema CSDL (mục 5) + model dùng chung.
- [ ] Tích hợp **Azure Pronunciation Assessment** (REST): gửi WAV + reference text, parse kết quả tới cấp âm vị.
- [ ] Viết **thuật toán so sánh âm vị offline**: text → âm vị (CMUdict) cho cả câu mẫu và câu nhận dạng → căn chỉnh Levenshtein → đánh dấu thay thế/thiếu/thừa → quy đổi điểm 0–100.
- [ ] Cập nhật bảng `weak_phonemes` sau mỗi lần chấm để Hoa làm gợi ý bài tập.
- [ ] Merge, tích hợp các module, sửa lỗi tích hợp.

**Bàn giao:** `features/pronunciation/`, `core/services/`, `core/models/`, `app/`.

---

### 👤 Lê Tuấn Khanh · M2: Thu âm & Nhận dạng giọng nói
**Code:**
- [ ] Xin quyền micro (`permission_handler`), xử lý trường hợp từ chối quyền.
- [ ] Thu âm bằng `record` (WAV 16kHz mono), lưu file vào thư mục app, hiển thị sóng âm/thời gian khi đang ghi.
- [ ] Tích hợp `speech_to_text` để lấy văn bản nhận dạng real-time (hiển thị chữ khi người dùng nói).
- [ ] Phát lại bản ghi của người dùng + phát mẫu chuẩn bằng `flutter_tts`.
- [ ] Màn hình **Luyện tập** (Practice): hiện từ/câu + IPA → nút ghi âm → gọi `PronunciationService` → chuyển sang màn hình Feedback.
- [ ] Chuẩn bị file CMUdict (`assets/data/cmudict.dict`), viết hàm tra âm vị (G2P) và chuẩn hoá số → chữ cho Phúc dùng.
- [ ] Xử lý lỗi: không có mạng, ghi âm quá ngắn/quá ồn, không nhận dạng được.

**Bàn giao:** `features/recording/`, `engine/pronouncing_dictionary.dart`, `engine/text_normalizer.dart`, `assets/data/cmudict.dict`.

---

### 👤 Đinh Thị Hoa · M3: Module phản hồi + Bài học
**Thiết kế (Tuần 1):**
- [ ] Thiết kế Figma cho toàn bộ app (màu, font, icon, ~10 màn hình chính) → cả nhóm code theo.
- [ ] Code widget dùng chung trong `core/widgets/` (button, card, vòng điểm số, chip âm vị).

**Code:**
- [ ] Soạn `lessons.json`: tối thiểu **10 bài / 3 cấp độ**, mỗi bài 8–10 từ/câu, có IPA. Có bài tập riêng cho các âm khó (/θ/, /ð/, /r/–/l/, /ʃ/–/s/, /iː/–/ɪ/, âm cuối…).
- [ ] Màn hình danh sách bài học + chi tiết bài.
- [ ] Màn hình **Feedback**:
  - Hiển thị điểm tổng + Accuracy/Fluency/Completeness.
  - Tô màu từng từ (xanh/vàng/đỏ), bấm vào từ → xem âm vị đúng vs âm vị người dùng phát ra.
  - Mẹo phát âm cho từng âm sai (vị trí lưỡi, môi…).
- [ ] **Đề xuất bài tập cải thiện**: dựa trên `weak_phonemes`, gợi ý bài học chứa các âm hay sai.

**Bàn giao:** `features/lessons/`, `features/feedback/`, `core/widgets/`, `assets/data/lessons.json`, file Figma.

---

### 👤 Chu Hữu Đệ · M4: CSDL + Hồ sơ + Thông báo
**Code:**
- [ ] Cài đặt CSDL `sqflite` theo schema của Phúc: tạo bảng, migration, seed dữ liệu bài học từ `lessons.json`.
- [ ] Viết các Repository/DAO: `UserRepository`, `AttemptRepository`, `SessionRepository` (CRUD + truy vấn lịch sử).
- [ ] Màn hình **Onboarding/Hồ sơ**: tạo hồ sơ (tên, trình độ, mục tiêu phút/ngày, giờ nhắc), sửa hồ sơ, hỗ trợ **nhiều người dùng trên 1 máy** (phục vụ kiểm thử).
- [ ] Màn hình **Lịch sử luyện tập**: danh sách các lần luyện, bấm vào xem lại kết quả.
- [ ] **Thông báo nhắc nhở** (`flutter_local_notifications`): nhắc theo giờ người dùng chọn, nhắc khi sắp mất streak (ví dụ 20h chưa luyện), xử lý quyền thông báo Android 13+, bấm thông báo → mở màn hình luyện tập.
- [ ] Màn hình **Cài đặt**: bật/tắt nhắc nhở, đổi giờ nhắc, xoá dữ liệu.

**Bàn giao:** `core/db/`, `features/auth_profile/`, `features/history/`, `features/notifications/`.

> Phúc sẽ pair-programming với Đệ buổi đầu khi dựng database để thống nhất cách viết repository.

---

### 👤 Phạm Vũ Ngọc Bảo · M5: Theo dõi tiến độ + Kiểm thử + Thuyết trình
**Code:**
- [ ] Logic **streak**: +1 khi có luyện tập trong ngày, reset khi bỏ 1 ngày, lưu streak dài nhất.
- [ ] Ghi nhận **thời gian học** mỗi phiên (start/end session) → cộng dồn vào `daily_stats`.
- [ ] **Mục tiêu hằng ngày**: thanh tiến độ phút/ngày, đánh dấu hoàn thành mục tiêu.
- [ ] Màn hình **Dashboard/Home**: streak (icon lửa), mục tiêu hôm nay, nút “Luyện ngay”.
- [ ] Màn hình **Thống kê** (`fl_chart`): phút học theo tuần/tháng, điểm trung bình theo thời gian, lịch heatmap các ngày đã luyện, top âm hay sai.
- [ ] Unit test cho logic streak (các trường hợp qua ngày, bỏ ngày, đổi múi giờ).

**Kiểm thử (Tuần 4):**
- [ ] Lập kế hoạch & biểu mẫu kiểm thử (Google Sheet): người nói, giới tính, giọng vùng miền, môi trường (yên tĩnh/ồn), câu đọc, điểm app chấm, nhận xét.
- [ ] Điều phối cả nhóm thu thập dữ liệu kiểm thử (mục 7).

**Báo cáo & thuyết trình:**
- [ ] Tổng hợp báo cáo, làm slide, kịch bản demo, quay video demo.

**Bàn giao:** `features/progress/`, file kết quả kiểm thử, slide.

---

## 7. Kế hoạch kiểm thử (bắt buộc – cả nhóm)

- Mỗi thành viên tìm **ít nhất 2 người bên ngoài** đọc thử → tổng **≥ 15 người**, đa dạng: nam/nữ, giọng Bắc/Trung/Nam, trình độ tiếng Anh khác nhau.
- Mỗi người đọc **cùng một bộ 10 câu/từ** (Hoa chọn), ở 2 môi trường: yên tĩnh và có tiếng ồn.
- Có ít nhất 1–2 mẫu “chuẩn” (người phát âm tốt hoặc audio native) để so sánh điểm.
- Ghi vào sheet chung → Bảo tổng hợp: điểm trung bình theo nhóm, các trường hợp app chấm sai, so sánh Azure vs thuật toán offline.
- Mỗi người tự viết **unit test / widget test** cho module mình phụ trách.

---

## 8. Quy tắc làm việc

- **Git:** `main` (bản ổn định) ← `develop` ← `feature/<tên-module>` (vd `feature/progress-streak`). Không push thẳng `main`.
- **Pull Request:** mỗi PR cần ít nhất 1 người review (Phúc hoặc thành viên cùng cặp). Chạy `flutter analyze` và `flutter test` trước khi tạo PR.
- **Commit:** ghi rõ ràng, ví dụ `feat(progress): add streak calculation`.
- **Không commit** API key Azure (nhập trong app), file ghi âm.
- **Họp nhóm:** 2 lần/tuần (15–30 phút), mỗi người báo cáo: đã làm gì – sắp làm gì – đang vướng gì.
- **Cặp hỗ trợ:** Phúc ↔ Khanh (AI + giọng nói), Phúc ↔ Đệ (CSDL), Hoa ↔ Bảo (UI tiến độ & phản hồi).
- Chưa có module thật thì dùng **mock** theo interface của Phúc để không phải chờ nhau.

---

## 9. Tiến độ dự kiến (5 tuần – điều chỉnh theo hạn nộp thực tế)

| Tuần | Phúc | Khanh | Hoa | Đệ | Bảo |
|---|---|---|---|---|---|
| **1** – Chuẩn bị | Tạo repo, khung project, interface, chốt schema | Nghiên cứu `record`, `speech_to_text`, Azure | Figma toàn bộ màn hình, cấu trúc `lessons.json` | Dựng DB + seed dữ liệu mẫu | Phác UI dashboard/thống kê, nghiên cứu `fl_chart` |
| **2** – Chức năng lõi | Tích hợp Azure Pronunciation Assessment | Thu âm + STT + màn hình Practice | Widget chung + màn hình bài học | Repository + màn hình Hồ sơ/Onboarding | Logic streak + thời gian học + mục tiêu ngày |
| **3** – Hoàn thiện | Thuật toán so sánh âm vị offline, `weak_phonemes` | Phát lại, TTS, xử lý lỗi, G2P | Màn hình Feedback + gợi ý bài tập | Thông báo nhắc nhở + Lịch sử + Cài đặt | Dashboard + màn hình Thống kê |
| **4** – Tích hợp & Test | Tích hợp toàn app, fix bug | Test nhận dạng nhiều giọng | Hoàn thiện nội dung, chỉnh UI | Test DB, thông báo trên nhiều máy | **Điều phối kiểm thử nhiều người dùng** |
| **5** – Nộp bài | Build APK release, review cuối | Hỗ trợ fix bug | Ảnh chụp màn hình cho báo cáo | Hỗ trợ fix bug | Báo cáo, slide, video demo |

**Mốc kiểm tra:**
- Cuối Tuần 2: chạy được luồng **chọn bài → ghi âm → có điểm** (dù UI còn thô).
- Cuối Tuần 3: đủ 7 mục checklist ở mức chạy được.
- Cuối Tuần 4: có file kết quả kiểm thử ≥ 15 người.

---

## 10. Sản phẩm nộp cuối

- [ ] Source code (GitHub) + file `README.md` hướng dẫn chạy.
- [ ] File APK Android (release).
- [ ] Báo cáo: phân tích yêu cầu, thiết kế CSDL, kiến trúc, thuật toán chấm điểm, kết quả kiểm thử, bảng phân công & đóng góp.
- [ ] Slide thuyết trình + video demo.
