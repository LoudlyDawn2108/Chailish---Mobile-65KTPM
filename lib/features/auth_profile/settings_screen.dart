// Module M4 – Cài đặt · Phụ trách: Chu Hữu Đệ

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/lesson.dart';
import '../../core/providers.dart';
import '../../core/services/export_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/widgets/common_widgets.dart';
import '../history/history_screen.dart';
import 'profile_form_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(activeUserProvider);
    if (user == null) return const SizedBox.shrink();
    final settings = ref.watch(settingsProvider);
    final userNotifier = ref.read(activeUserProvider.notifier);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    void snack(String m) =>
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          // ---- Hồ sơ ----
          const SectionTitle('Hồ sơ'),
          Card(
            child: Column(children: [
              ListTile(
                leading: CircleAvatar(child: Text(user.name.characters.first.toUpperCase())),
                title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    '${Lesson.levelName(user.level)} · ${user.accent} · ${user.gender}'),
                trailing: const Icon(Icons.edit),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProfileFormScreen(existing: user))),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.switch_account),
                title: const Text('Đổi người học'),
                subtitle: const Text('Dùng khi nhiều người kiểm thử trên cùng máy'),
                onTap: userNotifier.signOut,
              ),
            ]),
          ),

          // ---- Mục tiêu & nhắc nhở ----
          const SectionTitle('Mục tiêu & nhắc nhở'),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.flag),
                title: const Text('Mục tiêu mỗi ngày'),
                trailing: DropdownButton<int>(
                  value: user.dailyGoalMinutes,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final m in {5, 10, 15, 20, 30, 45, 60, user.dailyGoalMinutes}.toList()..sort())
                      DropdownMenuItem(value: m, child: Text('$m phút')),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    await userNotifier.save(user.copyWith(dailyGoalMinutes: v));
                    ref.read(dataVersionProvider.notifier).bump();
                  },
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active),
                title: const Text('Nhắc luyện tập hằng ngày'),
                subtitle: const Text('Kèm nhắc 20:00 nếu sắp mất streak'),
                value: user.reminderEnabled,
                onChanged: (v) async {
                  if (v) await ref.read(notificationServiceProvider).requestPermission();
                  await userNotifier.save(user.copyWith(reminderEnabled: v));
                },
              ),
              ListTile(
                enabled: user.reminderEnabled,
                leading: const Icon(Icons.alarm),
                title: const Text('Giờ nhắc'),
                trailing: Text(
                  TimeOfDay(hour: user.reminderHour, minute: user.reminderMinute)
                      .format(context),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime:
                        TimeOfDay(hour: user.reminderHour, minute: user.reminderMinute),
                  );
                  if (t != null) {
                    await userNotifier.save(
                        user.copyWith(reminderHour: t.hour, reminderMinute: t.minute));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.notification_add),
                title: const Text('Gửi thử thông báo'),
                onTap: () async {
                  await ref.read(notificationServiceProvider).requestPermission();
                  await ref.read(notificationServiceProvider).showTest();
                },
              ),
            ]),
          ),

          // ---- Chấm điểm ----
          const SectionTitle('Chấm điểm phát âm'),
          Card(
            child: Column(children: [
              RadioGroup<ScoringEngine>(
                groupValue: settings.engine,
                onChanged: (v) => settingsNotifier.update(settings.copyWith(engine: v)),
                child: const Column(children: [
                  RadioListTile(
                    value: ScoringEngine.offline,
                    title: Text('So sánh âm vị (offline)'),
                    subtitle: Text('Nhận dạng giọng nói của Android + từ điển CMUdict. '
                        'Không cần khoá API.'),
                  ),
                  RadioListTile(
                    value: ScoringEngine.azure,
                    title: Text('Azure AI Pronunciation Assessment'),
                    subtitle: Text('Chấm điểm từng âm vị trực tiếp từ âm thanh. '
                        'Cần Internet và khoá Azure Speech (gói F0 miễn phí).'),
                  ),
                ]),
              ),
              if (settings.engine == ScoringEngine.azure) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _AzureFields(settings: settings),
                ),
                if (!settings.azureReady)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text('Chưa nhập khoá → ứng dụng tạm dùng chế độ offline.',
                        style: TextStyle(color: Colors.orange)),
                  ),
              ],
              ListTile(
                leading: const Icon(Icons.speed),
                title: const Text('Tốc độ giọng đọc mẫu'),
                subtitle: Slider(
                  value: settings.ttsRate,
                  min: 0.2,
                  max: 0.7,
                  divisions: 10,
                  label: settings.ttsRate.toStringAsFixed(2),
                  onChanged: (v) => settingsNotifier.update(settings.copyWith(ttsRate: v)),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.volume_up),
                  onPressed: () => ref
                      .read(ttsServiceProvider)
                      .speak('Practice makes perfect', rate: settings.ttsRate),
                ),
              ),
            ]),
          ),

          // ---- Dữ liệu ----
          const SectionTitle('Dữ liệu'),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Lịch sử luyện tập'),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.table_view),
                title: const Text('Xuất dữ liệu kiểm thử (CSV)'),
                subtitle: const Text('Kết quả của tất cả người học trên máy này'),
                onTap: () async {
                  final n = await exportAttemptsCsv(ref.read(attemptRepoProvider));
                  if (n == 0) snack('Chưa có dữ liệu để xuất');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep),
                title: const Text('Xoá lịch sử luyện tập của tôi'),
                onTap: () async {
                  if (await _confirm(context, 'Xoá toàn bộ lịch sử, streak và thống kê của ${user.name}?')) {
                    await ref.read(userRepoProvider).clearHistory(user.id!);
                    ref.read(dataVersionProvider.notifier).bump();
                    snack('Đã xoá lịch sử');
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_remove, color: Colors.red),
                title: const Text('Xoá hồ sơ này', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  if (await _confirm(context, 'Xoá hồ sơ ${user.name} và mọi dữ liệu?')) {
                    await ref.read(userRepoProvider).delete(user.id!);
                    await ref.read(notificationServiceProvider).cancelAll();
                    await userNotifier.signOut();
                    ref.read(dataVersionProvider.notifier).bump();
                  }
                },
              ),
            ]),
          ),

          const SectionTitle('Giới thiệu'),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Ailish 1.0'),
              subtitle: Text('Nhóm 11 – Phát triển ứng dụng di động\n'
                  'Phúc · Khanh · Hoa · Đệ · Bảo'),
              isThreeLine: true,
            ),
          ),
        ],
      ),
    );
  }

  static Future<bool> _confirm(BuildContext context, String msg) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Xác nhận'),
          content: Text(msg),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xoá')),
          ],
        ),
      ) ??
      false;
}

class _AzureFields extends ConsumerStatefulWidget {
  const _AzureFields({required this.settings});
  final AppSettings settings;

  @override
  ConsumerState<_AzureFields> createState() => _AzureFieldsState();
}

class _AzureFieldsState extends ConsumerState<_AzureFields> {
  late final _key = TextEditingController(text: widget.settings.azureKey);
  late final _region = TextEditingController(text: widget.settings.azureRegion);
  bool _obscure = true;

  @override
  void dispose() {
    _key.dispose();
    _region.dispose();
    super.dispose();
  }

  void _save() {
    final s = ref.read(settingsProvider);
    ref.read(settingsProvider.notifier).update(
        s.copyWith(azureKey: _key.text.trim(), azureRegion: _region.text.trim()));
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Đã lưu cấu hình Azure')));
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        TextField(
          controller: _key,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: 'Azure Speech key',
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _region,
          decoration: const InputDecoration(
              labelText: 'Region', hintText: 'southeastasia, eastus...'),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonal(onPressed: _save, child: const Text('Lưu')),
        ),
      ]);
}
