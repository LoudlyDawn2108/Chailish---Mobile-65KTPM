# KẾ HOẠCH & BÁO CÁO KIỂM THỬ – Ailish (Nhóm 11)

Điều phối: **Phạm Vũ Ngọc Bảo**. Tất cả thành viên cùng tham gia.

Mục tiêu (checklist 7): kiểm thử ứng dụng với **nhiều người dùng** và **nhiều giọng nói khác nhau** để đánh giá độ chính xác của AI chấm điểm phát âm.

---

## 1. Kiểm thử tự động (đã có)

`flutter test` có **39 test**, chạy được trên máy tính, không cần điện thoại:
- Engine offline mô phỏng các lỗi phát âm phổ biến của người Việt: /θ/→/s/, /r/→/l/, nuốt âm cuối, /iː/→/ɪ/, bỏ từ, thêm từ ngập ngừng, đọc chậm.
- Parser Azure, logic streak, gợi ý bài tập, CSDL, giao diện màn hình phản hồi.

## 2. Kiểm thử thủ công các chức năng (trên điện thoại thật)

| # | Kịch bản | Kết quả mong đợi | Đạt? | Người test |
|---|---|---|---|---|
| F1 | Cài APK, mở app lần đầu | Hiện màn hình chào, tạo hồ sơ được | | |
| F2 | Tạo 2 hồ sơ, chuyển qua lại | Dữ liệu mỗi hồ sơ tách biệt | | |
| F3 | Từ chối quyền micro rồi bấm micro | Báo lỗi + nút "Mở cài đặt" | | |
| F4 | Luyện từ "think" đọc đúng | Điểm ≥ 80, từ màu xanh | | |
| F5 | Cố ý đọc "think" thành "sink" | Âm /θ/ bị đánh dấu đỏ, có mẹo, có bài tập gợi ý | | |
| F6 | Đọc câu nhưng bỏ 1 từ | Từ bị gạch "bỏ sót", Độ đầy đủ < 100 | | |
| F7 | Bấm "Nghe mẫu" / "Chậm" | Đọc mẫu đúng tốc độ | | |
| F8 | Luyện xong 1 bài | Hộp thoại tổng kết, tiến độ bài học tăng | | |
| F9 | Luyện ngày đầu tiên | Streak = 1, chấm hôm nay màu cam | | |
| F10 | Luyện 2 ngày liên tiếp | Streak = 2 | | |
| F11 | Học đủ số phút mục tiêu | Vòng mục tiêu có dấu ✓, chấm màu xanh | | |
| F12 | Đặt giờ nhắc sau 2 phút, tắt app | Có thông báo; bấm vào thì mở tab Bài học | | |
| F13 | Cài đặt → Gửi thử thông báo | Thông báo hiện ngay | | |
| F14 | Tab Tiến độ | Biểu đồ, heatmap, độ chính xác theo âm hiển thị đúng | | |
| F15 | Lịch sử → bấm 1 lần luyện | Mở lại đúng kết quả cũ | | |
| F16 | Bật Azure (nhập key) và luyện | Chấm bởi Azure, nghe lại được bản ghi | | |
| F17 | Bật Azure, tắt mạng, luyện | Báo lỗi mạng rõ ràng, không treo app | | |
| F18 | Xuất CSV | Mở được bằng Excel/Google Sheets, đúng tiếng Việt | | |
| F19 | Xoá lịch sử / xoá hồ sơ | Dữ liệu bị xoá, app không lỗi | | |
| F20 | Khởi động lại máy | Nhắc nhở vẫn hoạt động | | |

## 2b. Kết quả QA trên thiết bị thật (03/11/2026)

**Thiết bị:** Xiaomi Redmi Note 11T 5G, Android 13 (API 33), MIUI. Nhận dạng giọng nói: Google SODA offline (en-US). TTS: Google.
**Cách làm:** cài APK release, điều khiển qua `adb` (wireless debugging), giọng nói phát từ **loa laptop** bằng file giọng Google (đúng và cố ý sai), quan sát `logcat`.

| # | Kết quả | Ghi chú |
|---|---|---|
| F1 | ✅ Đạt | Màn hình chào → tạo hồ sơ; kiểm tra nhập tên rỗng có báo lỗi |
| F2 | ✅ Đạt | Hồ sơ "Hoa" (Nữ, Miền Nam, Cơ bản) có dữ liệu riêng, gợi ý đúng bài theo trình độ |
| F3 | ✅ Đạt | Từ chối quyền micro → "Ứng dụng cần quyền micro để chấm phát âm."; cho phép lại được |
| F4 | ✅ Đạt | "think" đúng → 98–100 điểm; câu "I think this is the right way" đúng → 100 |
| F5 | ⚠️ Một phần | Bỏ sót từ: phát hiện đúng ("right" bỏ sót). Thay âm (sink/tink → think): **bộ nhận dạng Google tự sửa thành "think" nên engine offline không bắt được** – hạn chế đã biết, cần Azure |
| F6 | ✅ Đạt | Từ bị gạch "bỏ sót", Độ đầy đủ 86 |
| F7 | ✅ Đạt | Gọi Google TTS en-US (log `GoogleTTSServiceImpl`) |
| F8 | ✅ Đạt | Hộp thoại tổng kết; khi bỏ qua hết hiển thị "Đã xem hết bài" (đã sửa) |
| F9 | ✅ Đạt | Streak = 1 sau lần luyện đầu tiên |
| F10 | ⏭️ Chưa test trên máy | Cần 2 ngày thật; logic đã có unit test (`streak_test.dart`) |
| F11 | ✅ Đạt | Vòng mục tiêu ✓, ô heatmap xanh đậm |
| F12 | ✅ Đạt | Đặt 22:12 → thông báo hiện 22:13:16 (inexact). Bấm thông báo mở lại app |
| F13 | ✅ Đạt | Thông báo heads-up hiện ngay |
| F14 | ✅ Đạt | Biểu đồ, heatmap, độ chính xác theo âm; đã sửa nhãn trục |
| F15 | ✅ Đạt | Mở lại kết quả cũ ở chế độ chỉ xem |
| F16 | ⚠️ Một phần | Ghi âm WAV + gửi Azure chạy; dùng key giả nên nhận 401 → báo "Khoá Azure không hợp lệ…". **Cần key thật để kiểm tra điểm Azure** |
| F17 | ⏭️ Bỏ qua | Tắt mạng sẽ ngắt wireless debugging |
| F18 | ✅ Đạt | Mở bảng chia sẻ CSV (không gửi đi) |
| F19 | ✅ Đạt | Xoá lịch sử → thống kê về 0; xoá hồ sơ → quay về chọn người học |
| F20 | ⏭️ Bỏ qua | Không khởi động lại máy cá nhân; alarm đã đăng ký `ScheduledNotificationBootReceiver` |
| Ngang | ✅ (widget test) | Không xoay được máy qua adb; đã thêm test màn hình ngang 2400×1080 |

### Lỗi tìm thấy khi QA và đã sửa
1. **Bị cắt khi nói chậm**: plugin `speech_to_text` chỉ đặt lại bộ đếm `pauseFor` khi có chữ nhận dạng, mà SODA offline không gửi kết quả tạm, nên app tự dừng 3 giây sau khi bấm micro (thấy rõ trong log: `stopListening` đúng +3,0 s). Bỏ hẳn `pauseFor` thì SODA chuyển sang chế độ "oneshot" và trả kết quả rỗng. **Cách sửa:** giữ `pauseFor` 3,5 s (thành `EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS`), sau khi `listen()` trả về thì nới bộ đếm phía Dart bằng `changePauseFor(15s)`. Thêm gợi ý "nói xong bấm ■ để chấm ngay".
2. **Điểm quá cao khi đọc thiếu**: đọc 1/7 từ vẫn được 81 "Rất tốt"; thiếu 1 từ được 97 "Xuất sắc". Đã sửa công thức: `(0.6·Acc + 0.2·Flu)·Com/100 + 0.2·Com`.
3. **Nói thừa không bị trừ**: đọc cả câu khi bài chỉ yêu cầu 1 từ vẫn được 88. Đã trừ 8 điểm cho mỗi từ thừa (tối đa 40).
4. **Tính giờ học cả khi để yên màn hình**: đã ngừng tính sau 2 phút không thao tác.
5. Bộ chọn giờ hiện tiếng Anh → đã thêm `flutter_localizations` (vi).
6. Lỗi "Hãy nhập tên" không tự mất → `autovalidateMode`.
7. Biểu đồ: nhãn "31.4" đè "30", nhãn "Mục tiêu" bị cột che → trục chia bước chẵn, nhãn sang trái.
8. Bỏ qua hết bài vẫn chúc mừng "Hoàn thành bài!" → "Đã xem hết bài".

### Hạn chế còn lại (ghi vào báo cáo)
- Engine offline **không phát hiện được lỗi thay âm** khi Google tự "sửa" về từ đúng (sink/tink → think). Phát hiện tốt lỗi bỏ sót và thừa từ. Muốn chấm từng âm thực sự thì dùng Azure.
- Âm thanh phát qua loa: từ đơn ngắn hay không được nhận dạng; câu dài nhận dạng tốt. Cần kiểm thử với **người nói thật** (mục 3).
- Biểu tượng app vẫn là logo Flutter mặc định.

## 3. Kiểm thử độ chính xác AI với nhiều giọng nói

### 3.1 Người tham gia (tối thiểu 15 người)
Mỗi thành viên tìm ít nhất 2 người bên ngoài. Cần đa dạng về:
- **Giới tính**: Nam / Nữ
- **Giọng vùng miền**: Bắc / Trung / Nam (+ người nước ngoài hoặc audio native nếu có)
- **Trình độ**: Cơ bản / Trung cấp / Nâng cao

Mỗi người **tạo hồ sơ riêng** trong app (khai đúng giới tính và giọng), để file CSV xuất ra tự có các cột này.

### 3.2 Bộ câu kiểm thử (giống nhau cho mọi người)

| # | Câu/từ | Âm trọng tâm |
|---|---|---|
| 1 | think | /θ/ |
| 2 | this | /ð/ |
| 3 | rice | /r/ |
| 4 | light | /l/ |
| 5 | sheep | /iː/ |
| 6 | ship | /ɪ/ |
| 7 | she | /ʃ/ |
| 8 | five | âm cuối /v/ |
| 9 | I think this is the right way | câu |
| 10 | She sells sea shells by the sea shore | câu |

### 3.3 Quy trình
1. Đọc 10 mục ở **phòng yên tĩnh**, sau đó đọc lại ở **nơi có tiếng ồn** (quán cà phê, bật nhạc nhỏ).
2. Mỗi mục đọc **2 lần**: lần 1 cố gắng đọc đúng, lần 2 **cố ý đọc sai** âm trọng tâm (ví dụ think → "tink"). Lần cố ý đọc sai dùng để đo xem AI có phát hiện được lỗi không.
3. Người quan sát ghi lại cảm nhận "đúng/sai" của mình vào cột *Đánh giá của người nghe*.
4. Nếu có key Azure: lặp lại các bước trên với chế độ Azure để so sánh hai engine.
5. Cuối buổi: **Cài đặt → Xuất dữ liệu kiểm thử (CSV)** → gửi file cho Bảo.

### 3.4 Chỉ số cần tính (Bảo tổng hợp)
- **Tỉ lệ phát hiện lỗi** = số lần cố ý đọc sai mà app đánh dấu âm trọng tâm là sai / tổng số lần cố ý đọc sai.
- **Tỉ lệ báo nhầm** = số lần đọc đúng (theo người nghe) mà app chấm < 60 / tổng số lần đọc đúng.
- Điểm trung bình theo **vùng miền**, **giới tính**, **môi trường** (yên tĩnh/ồn).
- So sánh **offline với Azure** trên cùng bộ câu.

### 3.5 Bảng kết quả (điền sau khi kiểm thử)

| Nhóm | Số người | Điểm TB (đọc đúng) | Điểm TB (cố ý sai) | Tỉ lệ phát hiện lỗi | Tỉ lệ báo nhầm |
|---|---|---|---|---|---|
| Miền Bắc | | | | | |
| Miền Trung | | | | | |
| Miền Nam | | | | | |
| Nam | | | | | |
| Nữ | | | | | |
| Yên tĩnh | | | | | |
| Có tiếng ồn | | | | | |
| **Offline** | | | | | |
| **Azure** | | | | | |

### 3.6 Nhận xét & hướng cải thiện (điền sau khi kiểm thử)
- Các âm engine offline hay bỏ sót lỗi: …
- Ảnh hưởng của tiếng ồn: …
- Đề xuất: …
