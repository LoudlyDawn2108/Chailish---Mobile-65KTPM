import 'package:ailish/features/progress/streak_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 3, 21, 0);

  test('no practice -> zero streak', () {
    final s = computeStreak([], now);
    expect(s.current, 0);
    expect(s.longest, 0);
    expect(s.atRisk, isFalse);
  });

  test('consecutive days including today', () {
    final s = computeStreak(['2026-11-01', '2026-11-02', '2026-11-03'], now);
    expect(s.current, 3);
    expect(s.practicedToday, isTrue);
    expect(s.atRisk, isFalse);
  });

  test('streak kept (at risk) when yesterday practiced but not today', () {
    final s = computeStreak(['2026-11-01', '2026-11-02'], now);
    expect(s.current, 2);
    expect(s.practicedToday, isFalse);
    expect(s.atRisk, isTrue);
  });

  test('gap day resets current streak but keeps longest', () {
    final s = computeStreak(
        ['2026-10-20', '2026-10-21', '2026-10-22', '2026-10-23', '2026-11-01', '2026-11-03'],
        now);
    expect(s.current, 1);
    expect(s.longest, 4);
  });

  test('missed yesterday and today -> streak lost', () {
    final s = computeStreak(['2026-10-30', '2026-10-31', '2026-11-01'], now);
    expect(s.current, 0);
    expect(s.longest, 3);
  });

  test('duplicate days and unsorted input', () {
    final s = computeStreak(['2026-11-03', '2026-11-02', '2026-11-03', '2026-11-02'], now);
    expect(s.current, 2);
  });

  test('crosses month and year boundaries', () {
    final s = computeStreak(['2025-12-30', '2025-12-31', '2026-01-01'],
        DateTime(2026, 1, 1, 8));
    expect(s.current, 3);
    final m = computeStreak(['2026-02-27', '2026-02-28', '2026-03-01'],
        DateTime(2026, 3, 1, 8));
    expect(m.current, 3);
  });

  test('date key formatting', () {
    expect(dateKey(DateTime(2026, 1, 5)), '2026-01-05');
    expect(parseDateKey('2026-01-05'), DateTime.utc(2026, 1, 5));
  });
}
