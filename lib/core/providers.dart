// Khai báo provider (Riverpod) dùng chung · Phụ trách: Nguyễn Hồng Phúc

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/feedback/exercise_recommender.dart';
import '../features/notifications/notification_service.dart';
import '../features/progress/progress_service.dart';
import '../features/progress/streak_calculator.dart';
import '../features/pronunciation/engine/pronouncing_dictionary.dart';
import '../features/pronunciation/pronunciation_service.dart';
import '../features/recording/speech_service.dart';
import '../features/recording/tts_service.dart';
import 'db/app_database.dart';
import 'db/repositories.dart';
import 'models/lesson.dart';
import 'models/progress_models.dart';
import 'models/user_profile.dart';
import 'services/settings_service.dart';

// ---- Hạ tầng (được override trong main.dart sau khi khởi tạo) ----
final sharedPrefsProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError());
final databaseProvider =
    Provider<AppDatabase>((ref) => throw UnimplementedError());
final notificationServiceProvider =
    Provider<NotificationService>((ref) => throw UnimplementedError());
final initialUserProvider = Provider<UserProfile?>((ref) => null);

// ---- Repository ----
final userRepoProvider =
    Provider((ref) => UserRepository(ref.watch(databaseProvider)));
final lessonRepoProvider =
    Provider((ref) => LessonRepository(ref.watch(databaseProvider)));
final attemptRepoProvider =
    Provider((ref) => AttemptRepository(ref.watch(databaseProvider)));
final progressRepoProvider =
    Provider((ref) => ProgressRepository(ref.watch(databaseProvider)));

// ---- Cài đặt ----
class SettingsNotifier extends Notifier<AppSettings> {
  late SettingsStore _store;

  @override
  AppSettings build() {
    _store = SettingsStore(ref.watch(sharedPrefsProvider));
    return _store.load();
  }

  Future<void> update(AppSettings s) async {
    state = s;
    await _store.save(s);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// ---- Người dùng đang hoạt động ----
class ActiveUserNotifier extends Notifier<UserProfile?> {
  @override
  UserProfile? build() => ref.read(initialUserProvider);

  Future<void> select(UserProfile user) async {
    state = user;
    final s = ref.read(settingsProvider);
    await ref.read(settingsProvider.notifier).update(s.copyWith(activeUserId: user.id));
    await ref.read(progressServiceProvider).rescheduleReminders(user);
    ref.read(dataVersionProvider.notifier).bump();
  }

  Future<void> save(UserProfile user) async {
    await ref.read(userRepoProvider).update(user);
    state = user;
    await ref.read(progressServiceProvider).rescheduleReminders(user);
  }

  Future<void> signOut() async {
    state = null;
    final s = ref.read(settingsProvider);
    await ref.read(settingsProvider.notifier).update(s.copyWith(clearUser: true));
  }
}

final activeUserProvider =
    NotifierProvider<ActiveUserNotifier, UserProfile?>(ActiveUserNotifier.new);

/// Tăng mỗi khi dữ liệu luyện tập thay đổi -> các màn hình thống kê tải lại.
class DataVersion extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final dataVersionProvider = NotifierProvider<DataVersion, int>(DataVersion.new);

// ---- Dịch vụ ----
final dictionaryProvider = FutureProvider<PronouncingDictionary>(
    (ref) => loadPronouncingDictionary());

final pronunciationServiceProvider = Provider((ref) =>
    PronunciationService(ref.watch(dictionaryProvider.future)));

final speechServiceProvider = Provider((ref) {
  final s = SpeechService();
  ref.onDispose(s.dispose);
  return s;
});

final ttsServiceProvider = Provider((ref) => TtsService());

final progressServiceProvider = Provider((ref) => ProgressService(
      attempts: ref.watch(attemptRepoProvider),
      progress: ref.watch(progressRepoProvider),
      notifications: ref.watch(notificationServiceProvider),
    ));

// ---- Dữ liệu cho giao diện ----
final usersProvider = FutureProvider<List<UserProfile>>((ref) {
  ref.watch(dataVersionProvider);
  return ref.watch(userRepoProvider).getAll();
});

final lessonsProvider = FutureProvider<List<Lesson>>(
    (ref) => ref.watch(lessonRepoProvider).getLessons());

final bestScoresProvider = FutureProvider<Map<String, double>>((ref) async {
  ref.watch(dataVersionProvider);
  final user = ref.watch(activeUserProvider);
  if (user == null) return {};
  return ref.watch(attemptRepoProvider).bestScoreByItem(user.id!);
});

final streakProvider = FutureProvider<StreakInfo>((ref) async {
  ref.watch(dataVersionProvider);
  final user = ref.watch(activeUserProvider);
  if (user == null) return StreakInfo.empty;
  return ref.watch(progressRepoProvider).refreshStreak(user.id!, DateTime.now());
});

final todayStatProvider = FutureProvider<DailyStat?>((ref) async {
  ref.watch(dataVersionProvider);
  final user = ref.watch(activeUserProvider);
  if (user == null) return null;
  return ref.watch(progressRepoProvider).day(user.id!, dateKey(DateTime.now()));
});

final weakPhonemesProvider = FutureProvider<List<WeakPhoneme>>((ref) async {
  ref.watch(dataVersionProvider);
  final user = ref.watch(activeUserProvider);
  if (user == null) return [];
  return ref.watch(progressRepoProvider).weakPhonemes(user.id!);
});

final recommendationsProvider =
    FutureProvider<List<PhonemeRecommendation>>((ref) async {
  final weak = await ref.watch(weakPhonemesProvider.future);
  final lessons = await ref.watch(lessonsProvider.future);
  return recommendFromHistory(weak, lessons);
});

/// Thống kê theo ngày trong [days] ngày gần nhất (đủ cả ngày không luyện).
final statsProvider =
    FutureProvider.family<List<DailyStat>, int>((ref, days) async {
  ref.watch(dataVersionProvider);
  final user = ref.watch(activeUserProvider);
  if (user == null) return [];
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day - (days - 1));
  final rows = await ref
      .watch(progressRepoProvider)
      .dailyStats(user.id!, fromDate: dateKey(from));
  final byDate = {for (final r in rows) r.date: r};
  return [
    for (var i = 0; i < days; i++)
      byDate[dateKey(DateTime(from.year, from.month, from.day + i))] ??
          DailyStat(
            date: dateKey(DateTime(from.year, from.month, from.day + i)),
            seconds: 0,
            attempts: 0,
            scoreSum: 0,
          ),
  ];
});

final totalsProvider =
    FutureProvider<({int seconds, int attempts, double avg})>((ref) async {
  ref.watch(dataVersionProvider);
  final user = ref.watch(activeUserProvider);
  if (user == null) return (seconds: 0, attempts: 0, avg: 0.0);
  return ref.watch(progressRepoProvider).totals(user.id!);
});

final historyProvider = FutureProvider<List<AttemptRecord>>((ref) async {
  ref.watch(dataVersionProvider);
  final user = ref.watch(activeUserProvider);
  if (user == null) return [];
  return ref.watch(attemptRepoProvider).recent(user.id!, limit: 200);
});
