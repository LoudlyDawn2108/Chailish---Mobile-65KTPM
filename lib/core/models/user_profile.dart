// Model dùng chung · Phụ trách: Chu Hữu Đệ

class UserProfile {
  const UserProfile({
    this.id,
    required this.name,
    this.level = 1,
    this.accent = 'Miền Bắc',
    this.gender = 'Khác',
    this.dailyGoalMinutes = 10,
    this.reminderEnabled = true,
    this.reminderHour = 19,
    this.reminderMinute = 0,
    required this.createdAt,
  });

  final int? id;
  final String name;

  /// Trình độ tự đánh giá: 1 Cơ bản, 2 Trung cấp, 3 Nâng cao.
  final int level;

  /// Giọng vùng miền – phục vụ kiểm thử với nhiều giọng nói khác nhau.
  final String accent;
  final String gender;
  final int dailyGoalMinutes;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;
  final DateTime createdAt;

  static const accents = ['Miền Bắc', 'Miền Trung', 'Miền Nam', 'Người nước ngoài', 'Khác'];
  static const genders = ['Nam', 'Nữ', 'Khác'];

  UserProfile copyWith({
    int? id,
    String? name,
    int? level,
    String? accent,
    String? gender,
    int? dailyGoalMinutes,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
  }) =>
      UserProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        level: level ?? this.level,
        accent: accent ?? this.accent,
        gender: gender ?? this.gender,
        dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        reminderHour: reminderHour ?? this.reminderHour,
        reminderMinute: reminderMinute ?? this.reminderMinute,
        createdAt: createdAt,
      );

  factory UserProfile.fromMap(Map<String, Object?> m) => UserProfile(
        id: m['id'] as int?,
        name: m['name'] as String,
        level: m['level'] as int? ?? 1,
        accent: m['accent'] as String? ?? 'Khác',
        gender: m['gender'] as String? ?? 'Khác',
        dailyGoalMinutes: m['daily_goal_minutes'] as int? ?? 10,
        reminderEnabled: (m['reminder_enabled'] as int? ?? 1) == 1,
        reminderHour: m['reminder_hour'] as int? ?? 19,
        reminderMinute: m['reminder_minute'] as int? ?? 0,
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'level': level,
        'accent': accent,
        'gender': gender,
        'daily_goal_minutes': dailyGoalMinutes,
        'reminder_enabled': reminderEnabled ? 1 : 0,
        'reminder_hour': reminderHour,
        'reminder_minute': reminderMinute,
        'created_at': createdAt.toIso8601String(),
      };
}
