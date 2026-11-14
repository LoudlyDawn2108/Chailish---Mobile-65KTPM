// Ailish – Ứng dụng học tiếng Anh với phân tích phát âm AI
// Nhóm 11 – Môn Phát triển ứng dụng di động
//
// Khởi tạo: SharedPreferences, CSDL SQLite (+ nạp bài học), thông báo.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/db/app_database.dart';
import 'core/db/repositories.dart';
import 'core/models/user_profile.dart';
import 'core/providers.dart';
import 'core/services/settings_service.dart';
import 'features/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi');

  final prefs = await SharedPreferences.getInstance();
  final db = await AppDatabase.open();
  await LessonRepository(db)
      .seed(await rootBundle.loadString('assets/data/lessons.json'));

  final notifications = NotificationService();
  await notifications.init();

  UserProfile? user;
  final activeId = SettingsStore(prefs).load().activeUserId;
  if (activeId != null) user = await UserRepository(db).getById(activeId);

  runApp(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(db),
      notificationServiceProvider.overrideWithValue(notifications),
      initialUserProvider.overrideWithValue(user),
    ],
    child: const AilishApp(),
  ));
}
