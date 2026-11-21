import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Token cho vật liệu "Liquid Glass": độ trong, viền phản quang, độ mờ nền
/// và bảng màu nền loang phía sau lớp kính. Lấy qua `GlassTheme.of(context)`.
@immutable
class GlassTheme extends ThemeExtension<GlassTheme> {
  /// Lớp kính thường (thẻ, nút).
  final Color tint;

  /// Lớp kính dày (thanh điều hướng, ô nhập, bottom sheet) – dễ đọc chữ hơn.
  final Color thickTint;

  /// Viền sáng phía trên-trái (ánh phản quang).
  final Color rimHighlight;

  /// Viền tối hơn phía dưới-phải.
  final Color rimShade;

  final double blurSigma;
  final List<BoxShadow> shadows;

  /// Màu nền gốc và các đốm màu loang phía sau lớp kính.
  final Color backdropBase;
  final List<Color> backdropBlobs;

  const GlassTheme({
    required this.tint,
    required this.thickTint,
    required this.rimHighlight,
    required this.rimShade,
    required this.blurSigma,
    required this.shadows,
    required this.backdropBase,
    required this.backdropBlobs,
  });

  static const light = GlassTheme(
    tint: Color(0x8CFFFFFF),
    thickTint: Color(0xC7FFFFFF),
    rimHighlight: Color(0xE6FFFFFF),
    rimShade: Color(0x33FFFFFF),
    blurSigma: 22,
    shadows: [
      BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 10)),
      BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
    ],
    backdropBase: Color(0xFFF6F2EF),
    backdropBlobs: [
      Color(0xFFFF8A80), // đỏ son nhạt
      Color(0xFFFFD180), // vàng hoàng gia nhạt
      Color(0xFF80CBC4), // ngọc bích
      Color(0xFFB39DDB), // tím
    ],
  );

  static const dark = GlassTheme(
    tint: Color(0x6B2C2C2E),
    thickTint: Color(0xB31C1C1E),
    rimHighlight: Color(0x59FFFFFF),
    rimShade: Color(0x0FFFFFFF),
    blurSigma: 26,
    shadows: [
      BoxShadow(color: Color(0x59000000), blurRadius: 28, offset: Offset(0, 12)),
    ],
    backdropBase: Color(0xFF0D0A0B),
    backdropBlobs: [
      Color(0xFF9A1B1B),
      Color(0xFF7A4A00),
      Color(0xFF0F5F55),
      Color(0xFF3A2A7A),
    ],
  );

  static GlassTheme of(BuildContext context) =>
      Theme.of(context).extension<GlassTheme>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  GlassTheme copyWith({
    Color? tint,
    Color? thickTint,
    Color? rimHighlight,
    Color? rimShade,
    double? blurSigma,
    List<BoxShadow>? shadows,
    Color? backdropBase,
    List<Color>? backdropBlobs,
  }) {
    return GlassTheme(
      tint: tint ?? this.tint,
      thickTint: thickTint ?? this.thickTint,
      rimHighlight: rimHighlight ?? this.rimHighlight,
      rimShade: rimShade ?? this.rimShade,
      blurSigma: blurSigma ?? this.blurSigma,
      shadows: shadows ?? this.shadows,
      backdropBase: backdropBase ?? this.backdropBase,
      backdropBlobs: backdropBlobs ?? this.backdropBlobs,
    );
  }

  @override
  GlassTheme lerp(GlassTheme? other, double t) {
    if (other == null) return this;
    return GlassTheme(
      tint: Color.lerp(tint, other.tint, t)!,
      thickTint: Color.lerp(thickTint, other.thickTint, t)!,
      rimHighlight: Color.lerp(rimHighlight, other.rimHighlight, t)!,
      rimShade: Color.lerp(rimShade, other.rimShade, t)!,
      blurSigma: lerpDouble(blurSigma, other.blurSigma, t)!,
      shadows: BoxShadow.lerpList(shadows, other.shadows, t)!,
      backdropBase: Color.lerp(backdropBase, other.backdropBase, t)!,
      backdropBlobs: [
        for (var i = 0; i < backdropBlobs.length; i++)
          Color.lerp(backdropBlobs[i], other.backdropBlobs[i % other.backdropBlobs.length], t)!,
      ],
    );
  }
}
