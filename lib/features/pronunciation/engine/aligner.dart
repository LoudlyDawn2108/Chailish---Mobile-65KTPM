// Module M1 – Engine chấm điểm phát âm · Phụ trách: Nguyễn Hồng Phúc
//
// Căn chỉnh hai chuỗi bằng khoảng cách Levenshtein có trọng số.
// Dùng cho cả cấp từ (câu mẫu vs câu nhận dạng) và cấp âm vị.

enum AlignType { match, substitute, delete, insert }

/// Một bước căn chỉnh. [refIndex] = -1 với insert, [hypIndex] = -1 với delete.
class AlignStep {
  const AlignStep(this.type, this.refIndex, this.hypIndex);
  final AlignType type;
  final int refIndex;
  final int hypIndex;

  @override
  String toString() => '${type.name}($refIndex,$hypIndex)';
}

class Alignment {
  const Alignment(this.steps, this.cost);
  final List<AlignStep> steps;
  final double cost;
}

/// [subCost] trả về chi phí thay thế trong khoảng [0, 1]; 0 nghĩa là trùng.
Alignment align<T>(
  List<T> ref,
  List<T> hyp, {
  required double Function(T a, T b) subCost,
  double deleteCost = 1,
  double insertCost = 1,
}) {
  final n = ref.length, m = hyp.length;
  final d = List.generate(n + 1, (_) => List<double>.filled(m + 1, 0));
  for (var i = 1; i <= n; i++) {
    d[i][0] = d[i - 1][0] + deleteCost;
  }
  for (var j = 1; j <= m; j++) {
    d[0][j] = d[0][j - 1] + insertCost;
  }
  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      final sub = d[i - 1][j - 1] + subCost(ref[i - 1], hyp[j - 1]);
      final del = d[i - 1][j] + deleteCost;
      final ins = d[i][j - 1] + insertCost;
      var best = sub;
      if (del < best) best = del;
      if (ins < best) best = ins;
      d[i][j] = best;
    }
  }

  // Truy vết ngược.
  final steps = <AlignStep>[];
  var i = n, j = m;
  const eps = 1e-9;
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0) {
      final c = subCost(ref[i - 1], hyp[j - 1]);
      if ((d[i][j] - (d[i - 1][j - 1] + c)).abs() < eps) {
        steps.add(AlignStep(
            c == 0 ? AlignType.match : AlignType.substitute, i - 1, j - 1));
        i--;
        j--;
        continue;
      }
    }
    if (i > 0 && (d[i][j] - (d[i - 1][j] + deleteCost)).abs() < eps) {
      steps.add(AlignStep(AlignType.delete, i - 1, -1));
      i--;
      continue;
    }
    steps.add(AlignStep(AlignType.insert, -1, j - 1));
    j--;
  }
  return Alignment(steps.reversed.toList(), d[n][m]);
}
