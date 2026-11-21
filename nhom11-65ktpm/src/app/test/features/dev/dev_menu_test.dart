import 'package:chailish/core/theme/app_theme.dart';
import 'package:chailish/features/dev/dev_menu_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('menu dev hiện trạng thái hợp đồng và tạo được dữ liệu giả', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(theme: AppTheme.lightTheme, home: const DevMenuScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Chưa đăng nhập'), findsOneWidget);
    expect(find.text('GIẢ'), findsWidgets);
    expect(find.textContaining('0 sự kiện'), findsOneWidget);

    await tester.tap(find.byKey(const Key('dev-generate')));
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(find.byKey(const Key('dev-progress'))).data!;
    expect(text, isNot(startsWith('0 sự kiện')));
    expect(text, contains('streak'));
  });
}
