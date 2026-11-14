// Module M5 – Ghi nhận tiến độ sau mỗi lần luyện · Phụ trách: Phạm Vũ Ngọc Bảo

import '../../core/db/repositories.dart';
import '../../core/models/lesson.dart';
import '../../core/models/pronunciation_result.dart';
import '../../core/models/user_profile.dart';
import '../notifications/notification_service.dart';
import 'streak_calculator.dart';

class ProgressService {
  ProgressService({
    required this.attempts,
    required this.progress,
    required this.notifications,
  });

  final AttemptRepository attempts;
  final ProgressRepository progress;
  final NotificationService notifications;

  /// Lưu kết quả 1 lần luyện và cập nhật thống kê ngày, âm yếu, streak.
  Future<({int attemptId, StreakInfo streak})> recordAttempt({
    required UserProfile user,
    required int? sessionId,
    required LessonItem? item,
    required PronunciationResult result,
    required String? audioPath,
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    final id = await attempts.saveAttempt(
      userId: user.id!,
      sessionId: sessionId,
      itemId: item?.id,
      result: result,
      audioPath: audioPath,
      at: now,
    );
    await progress.addAttempt(user.id!, dateKey(now), result.overall);
    await progress.updateWeakPhonemes(user.id!, result.phonemeStats(), now);
    final streak = await progress.refreshStreak(user.id!, now);
    await notifications.reschedule(user, streak);
    return (attemptId: id, streak: streak);
  }

  /// Cộng thời gian học thực tế (giây) vào ngày hiện tại.
  Future<void> addPracticeTime(UserProfile user, int seconds, {DateTime? at}) =>
      progress.addPracticeSeconds(user.id!, dateKey(at ?? DateTime.now()), seconds);

  Future<void> rescheduleReminders(UserProfile user) async {
    final streak = await progress.refreshStreak(user.id!, DateTime.now());
    await notifications.reschedule(user, streak);
  }
}
