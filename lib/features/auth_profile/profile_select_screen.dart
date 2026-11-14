// Module M4 – Chọn / tạo hồ sơ người dùng · Phụ trách: Chu Hữu Đệ
//
// Hỗ trợ nhiều người dùng trên cùng một máy để kiểm thử với nhiều giọng nói.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/lesson.dart';
import '../../core/providers.dart';
import '../../core/widgets/common_widgets.dart';
import 'profile_form_screen.dart';

class ProfileSelectScreen extends ConsumerWidget {
  const ProfileSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: users.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(e),
          data: (list) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 32),
              Icon(Icons.record_voice_over, size: 72, color: scheme.primary),
              const SizedBox(height: 16),
              Text('Ailish',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall
                      ?.copyWith(fontWeight: FontWeight.bold, color: scheme.primary)),
              const SizedBox(height: 8),
              const Text(
                'Luyện phát âm tiếng Anh với AI.\nMỗi ngày một chút, tiến bộ thật nhanh!',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (list.isNotEmpty) ...[
                const SectionTitle('Chọn người học'),
                for (final u in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        leading: CircleAvatar(
                            child: Text(u.name.characters.first.toUpperCase())),
                        title: Text(u.name,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            '${Lesson.levelName(u.level)} · ${u.accent} · ${u.gender}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => ref.read(activeUserProvider.notifier).select(u),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(list.isEmpty ? 'Bắt đầu' : 'Thêm người học mới'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ProfileFormScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
