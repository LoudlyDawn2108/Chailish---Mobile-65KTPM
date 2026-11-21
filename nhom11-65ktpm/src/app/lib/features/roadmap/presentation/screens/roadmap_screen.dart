import 'package:flutter/material.dart';

import '../../../../core/widgets/glass.dart';

class RoadmapScreen extends StatelessWidget {
  const RoadmapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GlassScaffold(
      appBar: GlassAppBar(title: Text('Bản Đồ Lộ Trình HSK')),
      body: ComingSoonView(
        icon: Icons.map_outlined,
        color: Color(0xFF1E88E5),
        title: 'Lộ Trình Học HSK 1 - HSK 2',
        message: 'Đang phát triển theo phân công Issue #29 của Bảo',
      ),
    );
  }
}
