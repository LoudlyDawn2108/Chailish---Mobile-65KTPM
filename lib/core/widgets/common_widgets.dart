// Widget dùng chung · Phụ trách: Đinh Thị Hoa

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../features/pronunciation/engine/phonemes.dart';

/// Vòng tròn hiển thị điểm 0–100.
class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.score, this.size = 140, this.label});

  final double score;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forScore(score);
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: score.clamp(0, 100)),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => CustomPaint(
          painter: _RingPainter(
            value: v / 100,
            color: color,
            track: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(v.round().toString(),
                    style: TextStyle(
                        fontSize: size * 0.3,
                        fontWeight: FontWeight.bold,
                        color: color)),
                if (label != null)
                  Text(label!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.color, required this.track});
  final double value;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.09;
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(r, 0, math.pi * 2, false, base);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * value, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color;
}

/// Thanh điểm thành phần (Accuracy, Fluency...).
class ScoreBar extends StatelessWidget {
  const ScoreBar({super.key, required this.label, required this.score, this.hint});
  final String label;
  final double score;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forScore(score);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(score.round().toString(),
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (score / 100).clamp(0, 1),
              minHeight: 8,
              color: color,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(hint!, style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

/// Nhãn âm vị dạng /θ/.
class PhonemeChip extends StatelessWidget {
  const PhonemeChip(this.phoneme, {super.key, this.color, this.onTap});
  final String phoneme;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.withValues(alpha: 0.4)),
        ),
        child: Text('/${ipaOfPhone(phoneme)}/',
            style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Row(children: [
          Expanded(
              child: Text(text,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold))),
          ?trailing,
        ]),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ]),
        ),
      );
}

/// Hiển thị lỗi của AsyncValue một cách thân thiện.
class ErrorView extends StatelessWidget {
  const ErrorView(this.error, {super.key});
  final Object error;
  @override
  Widget build(BuildContext context) =>
      EmptyState(icon: Icons.error_outline, text: 'Đã xảy ra lỗi:\n$error');
}

String formatMinutes(int seconds) {
  final m = seconds ~/ 60;
  if (m < 60) return '$m phút';
  return '${m ~/ 60} giờ ${m % 60} phút';
}
