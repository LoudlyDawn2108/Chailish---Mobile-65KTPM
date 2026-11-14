// Cài đặt ứng dụng (SharedPreferences) · Phụ trách: Chu Hữu Đệ

import 'package:shared_preferences/shared_preferences.dart';

enum ScoringEngine { offline, azure }

class AppSettings {
  const AppSettings({
    this.engine = ScoringEngine.offline,
    this.azureKey = '',
    this.azureRegion = 'southeastasia',
    this.ttsRate = 0.45,
    this.activeUserId,
  });

  final ScoringEngine engine;
  final String azureKey;
  final String azureRegion;
  final double ttsRate;
  final int? activeUserId;

  bool get azureReady => azureKey.trim().isNotEmpty && azureRegion.trim().isNotEmpty;

  /// Engine thực sự dùng: chỉ dùng Azure khi đã nhập khoá.
  ScoringEngine get effectiveEngine =>
      engine == ScoringEngine.azure && azureReady ? ScoringEngine.azure : ScoringEngine.offline;

  AppSettings copyWith({
    ScoringEngine? engine,
    String? azureKey,
    String? azureRegion,
    double? ttsRate,
    int? activeUserId,
    bool clearUser = false,
  }) =>
      AppSettings(
        engine: engine ?? this.engine,
        azureKey: azureKey ?? this.azureKey,
        azureRegion: azureRegion ?? this.azureRegion,
        ttsRate: ttsRate ?? this.ttsRate,
        activeUserId: clearUser ? null : (activeUserId ?? this.activeUserId),
      );
}

class SettingsStore {
  SettingsStore(this._prefs);
  final SharedPreferences _prefs;

  AppSettings load() => AppSettings(
        engine: _prefs.getString('engine') == 'azure'
            ? ScoringEngine.azure
            : ScoringEngine.offline,
        azureKey: _prefs.getString('azure_key') ?? '',
        azureRegion: _prefs.getString('azure_region') ?? 'southeastasia',
        ttsRate: _prefs.getDouble('tts_rate') ?? 0.45,
        activeUserId: _prefs.getInt('active_user_id'),
      );

  Future<void> save(AppSettings s) async {
    await _prefs.setString('engine', s.engine.name);
    await _prefs.setString('azure_key', s.azureKey);
    await _prefs.setString('azure_region', s.azureRegion);
    await _prefs.setDouble('tts_rate', s.ttsRate);
    if (s.activeUserId == null) {
      await _prefs.remove('active_user_id');
    } else {
      await _prefs.setInt('active_user_id', s.activeUserId!);
    }
  }
}
