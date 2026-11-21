import 'package:flutter/material.dart';

import '../../../../core/widgets/glass.dart';

class LessonListScreen extends StatelessWidget {
  const LessonListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GlassScaffold(
      appBar: GlassAppBar(title: Text('Danh Sách Bài Học')),
      body: ComingSoonView(
        icon: Icons.book_outlined,
        color: Color(0xFF2E7D32),
        title: 'Danh Sách Bài Học HSK',
        message: 'Đang phát triển theo phân công Issue #19 của Hoa',
      ),
    );
  }
}
