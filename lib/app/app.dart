// Khung ứng dụng & điều hướng · Phụ trách: Nguyễn Hồng Phúc

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../features/auth_profile/profile_select_screen.dart';
import '../features/auth_profile/settings_screen.dart';
import '../features/lessons/lessons_screen.dart';
import '../features/progress/home_screen.dart';
import '../features/progress/stats_screen.dart';
import 'theme.dart';

class AilishApp extends ConsumerWidget {
  const AilishApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(activeUserProvider);
    return MaterialApp(
      title: 'Ailish',
      debugShowCheckedModeBanner: false,
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: user == null
          ? const ProfileSelectScreen()
          : HomeShell(key: ValueKey(user.id)),
    );
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _tab = 0;
  late final ValueNotifier<String?> _tapped;

  @override
  void initState() {
    super.initState();
    // Nạp sẵn từ điển phát âm trong nền.
    ref.read(dictionaryProvider);
    _tapped = ref.read(notificationServiceProvider).tappedPayload;
    _tapped.addListener(_onNotificationTap);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onNotificationTap();
      final user = ref.read(activeUserProvider);
      if (user != null) {
        ref.read(progressServiceProvider).rescheduleReminders(user);
      }
    });
  }

  void _onNotificationTap() {
    if (_tapped.value == 'practice' && mounted) {
      setState(() => _tab = 1);
      _tapped.value = null;
    }
  }

  @override
  void dispose() {
    _tapped.removeListener(_onNotificationTap);
    super.dispose();
  }

  void goTo(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onOpenTab: goTo),
      const LessonsScreen(),
      const StatsScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: goTo,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Trang chủ'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Bài học'),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Tiến độ'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Cài đặt'),
        ],
      ),
    );
  }
}
