// Module M4 – Thông báo nhắc nhở luyện tập · Phụ trách: Chu Hữu Đệ
//
//  * Nhắc hằng ngày theo giờ người dùng chọn (lặp lại mỗi ngày).
//  * Nhắc "sắp mất streak" lúc 20:00 nếu hôm nay chưa luyện.

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/models/user_profile.dart';
import '../progress/streak_calculator.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _dailyId = 1;
  static const _streakId = 2;
  static const streakReminderHour = 20;

  /// Được gọi khi người dùng bấm vào thông báo.
  final ValueNotifier<String?> tappedPayload = ValueNotifier(null);

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (r) => tappedPayload.value = r.payload,
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      tappedPayload.value = launch!.notificationResponse?.payload;
    }
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  Future<bool> requestPermission() async =>
      await _android?.requestNotificationsPermission() ?? true;

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          'practice_reminder',
          'Nhắc nhở luyện tập',
          channelDescription: 'Nhắc bạn luyện phát âm mỗi ngày',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );

  tz.TZDateTime _next(int hour, int minute, {bool allowToday = true}) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!allowToday || !t.isAfter(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  /// Đặt lại toàn bộ lịch nhắc cho người dùng.
  Future<void> reschedule(UserProfile user, StreakInfo streak) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      if (!user.reminderEnabled) return;
      await _plugin.zonedSchedule(
        id: _dailyId,
        scheduledDate: _next(user.reminderHour, user.reminderMinute),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: 'Đến giờ luyện phát âm rồi, ${user.name}!',
        body: 'Dành ${user.dailyGoalMinutes} phút hôm nay để nói tiếng Anh hay hơn nhé.',
        payload: 'practice',
        matchDateTimeComponents: DateTimeComponents.time,
      );
      await _scheduleStreakReminder(user, streak);
    } catch (e) {
      debugPrint('Không đặt được thông báo: $e');
    }
  }

  Future<void> _scheduleStreakReminder(UserProfile user, StreakInfo s) async {
    // Hôm nay đã luyện -> nhắc vào tối mai; chưa luyện -> tối nay.
    final at = _next(streakReminderHour, 0, allowToday: !s.practicedToday);
    final streakText = s.current;
    await _plugin.zonedSchedule(
      id: _streakId,
      scheduledDate: at,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: streakText > 0
          ? '🔥 Đừng để mất chuỗi $streakText ngày!'
          : 'Bắt đầu chuỗi ngày luyện tập nào!',
      body: 'Chỉ cần luyện 1 từ hôm nay để giữ streak.',
      payload: 'practice',
    );
  }

  Future<void> showTest() => _plugin.show(
        id: 99,
        title: 'Ailish',
        body: 'Thông báo hoạt động bình thường 🎉',
        notificationDetails: _details,
      );

  Future<void> cancelAll() => _plugin.cancelAll();
}
