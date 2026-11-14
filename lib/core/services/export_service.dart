// Xuất dữ liệu kiểm thử (CSV) · Phụ trách: Phạm Vũ Ngọc Bảo
//
// Phục vụ checklist mục 7: tổng hợp kết quả chấm điểm của nhiều người dùng
// với các giọng nói khác nhau để phân tích độ chính xác của AI.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/repositories.dart';

String toCsv(List<Map<String, Object?>> rows) {
  if (rows.isEmpty) return '';
  String esc(Object? v) {
    final s = v?.toString() ?? '';
    return s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  final headers = rows.first.keys.toList();
  final b = StringBuffer()..writeln(headers.join(','));
  for (final r in rows) {
    b.writeln(headers.map((h) => esc(r[h])).join(','));
  }
  return b.toString();
}

Future<int> exportAttemptsCsv(AttemptRepository repo) async {
  final rows = await repo.exportRows();
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path,
      'ailish_kiem_thu_${DateTime.now().millisecondsSinceEpoch}.csv'));
  // BOM để Excel đọc đúng tiếng Việt.
  await file.writeAsString('﻿${toCsv(rows)}');
  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: 'text/csv')],
    subject: 'Kết quả kiểm thử Ailish',
    text: 'Dữ liệu ${rows.length} lần luyện phát âm',
  ));
  return rows.length;
}
