// Module M4 – Tạo / sửa hồ sơ, đặt mục tiêu hằng ngày · Phụ trách: Chu Hữu Đệ

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/lesson.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers.dart';

class ProfileFormScreen extends ConsumerStatefulWidget {
  const ProfileFormScreen({super.key, this.existing});

  final UserProfile? existing;

  @override
  ConsumerState<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends ConsumerState<ProfileFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late int _level;
  late String _accent;
  late String _gender;
  late int _goal;
  late bool _reminder;
  late TimeOfDay _time;
  bool _saving = false;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final u = widget.existing;
    _name = TextEditingController(text: u?.name ?? '');
    _level = u?.level ?? 1;
    _accent = u?.accent ?? UserProfile.accents.first;
    _gender = u?.gender ?? UserProfile.genders.last;
    _goal = u?.dailyGoalMinutes ?? 10;
    _reminder = u?.reminderEnabled ?? true;
    _time = TimeOfDay(hour: u?.reminderHour ?? 19, minute: u?.reminderMinute ?? 0);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final base = widget.existing ??
        UserProfile(name: '', createdAt: DateTime.now());
    var user = base.copyWith(
      name: _name.text.trim(),
      level: _level,
      accent: _accent,
      gender: _gender,
      dailyGoalMinutes: _goal,
      reminderEnabled: _reminder,
      reminderHour: _time.hour,
      reminderMinute: _time.minute,
    );
    final notifier = ref.read(activeUserProvider.notifier);
    if (_isNew) {
      user = await ref.read(userRepoProvider).insert(user);
      if (_reminder) {
        await ref.read(notificationServiceProvider).requestPermission();
      }
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      await notifier.select(user);
    } else {
      if (_reminder) {
        await ref.read(notificationServiceProvider).requestPermission();
      }
      await notifier.save(user);
      ref.read(dataVersionProvider.notifier).bump();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'Tạo hồ sơ học' : 'Sửa hồ sơ')),
      body: Form(
        key: _form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Tên của bạn', prefixIcon: Icon(Icons.person)),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Hãy nhập tên' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _gender,
              decoration: const InputDecoration(labelText: 'Giới tính'),
              items: [
                for (final g in UserProfile.genders)
                  DropdownMenuItem(value: g, child: Text(g)),
              ],
              onChanged: (v) => setState(() => _gender = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _accent,
              decoration: const InputDecoration(
                  labelText: 'Giọng vùng miền',
                  helperText: 'Dùng để thống kê độ chính xác theo giọng nói'),
              items: [
                for (final a in UserProfile.accents)
                  DropdownMenuItem(value: a, child: Text(a)),
              ],
              onChanged: (v) => setState(() => _accent = v!),
            ),
            const SizedBox(height: 20),
            Text('Trình độ tiếng Anh',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: [
                for (final l in [1, 2, 3])
                  ButtonSegment(value: l, label: Text(Lesson.levelName(l))),
              ],
              selected: {_level},
              onSelectionChanged: (s) => setState(() => _level = s.first),
            ),
            const SizedBox(height: 24),
            Text('Mục tiêu mỗi ngày: $_goal phút',
                style: Theme.of(context).textTheme.titleSmall),
            Slider(
              value: _goal.toDouble(),
              min: 5,
              max: 60,
              divisions: 11,
              label: '$_goal phút',
              onChanged: (v) => setState(() => _goal = v.round()),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Nhắc nhở luyện tập hằng ngày'),
              value: _reminder,
              onChanged: (v) => setState(() => _reminder = v),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: _reminder,
              leading: const Icon(Icons.alarm),
              title: const Text('Giờ nhắc'),
              trailing: Text(_time.format(context),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: _time);
                if (t != null) setState(() => _time = t);
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_isNew ? 'Tạo hồ sơ & bắt đầu học' : 'Lưu thay đổi'),
            ),
          ],
        ),
      ),
    );
  }
}
