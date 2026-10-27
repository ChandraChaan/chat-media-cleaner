import 'package:flutter/material.dart';

import '../features/media/domain/media_type.dart';

/// Brand colours. Deliberately not the green of any chat app.
abstract final class AppTheme {
  static const seed = Color(0xFF3949AB);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      extensions: [MediaTypeColors.forBrightness(brightness)],
      cardTheme: const CardThemeData(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
    );
  }
}

/// One colour per media type for the storage bar. The type is always also
/// written next to its colour, so colour never carries meaning alone.
@immutable
final class MediaTypeColors extends ThemeExtension<MediaTypeColors> {
  const MediaTypeColors(this.colors);

  factory MediaTypeColors.forBrightness(Brightness brightness) {
    final light = brightness == Brightness.light;
    return MediaTypeColors({
      MediaType.video: light
          ? const Color(0xFF3949AB)
          : const Color(0xFF9FA8DA),
      MediaType.image: light
          ? const Color(0xFFE8743B)
          : const Color(0xFFFFAB80),
      MediaType.voiceNote: light
          ? const Color(0xFF00897B)
          : const Color(0xFF80CBC4),
      MediaType.audio: light
          ? const Color(0xFF8E24AA)
          : const Color(0xFFCE93D8),
      MediaType.document: light
          ? const Color(0xFF546E7A)
          : const Color(0xFFB0BEC5),
      MediaType.sticker: light
          ? const Color(0xFFF9A825)
          : const Color(0xFFFFE082),
      MediaType.gif: light ? const Color(0xFFD81B60) : const Color(0xFFF48FB1),
      MediaType.status: light
          ? const Color(0xFF1E88E5)
          : const Color(0xFF90CAF9),
      MediaType.other: light
          ? const Color(0xFF8D6E63)
          : const Color(0xFFBCAAA4),
    });
  }

  final Map<MediaType, Color> colors;

  Color colorOf(MediaType type) => colors[type]!;

  static MediaTypeColors of(BuildContext context) =>
      Theme.of(context).extension<MediaTypeColors>()!;

  @override
  MediaTypeColors copyWith({Map<MediaType, Color>? colors}) =>
      MediaTypeColors(colors ?? this.colors);

  @override
  MediaTypeColors lerp(MediaTypeColors? other, double t) {
    if (other == null) return this;
    return MediaTypeColors({
      for (final type in MediaType.values)
        type: Color.lerp(colorOf(type), other.colorOf(type), t)!,
    });
  }
}
