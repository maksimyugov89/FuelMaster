import 'package:flutter/material.dart';

import 'package:fuelmaster/utils/constants.dart';

/// Логотип марки авто.
///
/// Каталог расширен марками, для которых логотипов в ассетах нет (Haval, Geely,
/// Changan, Москвич, КамАЗ и другие), поэтому вместо трёх копий «картинка или
/// серая иконка» — один виджет: ассет, если он есть, иначе монограмма марки.
/// Раньше отсутствие логотипа давало безымянную иконку машины, по которой
/// нельзя понять, что за марка.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    required this.brand,
    this.size = 32.0,
    this.padding = 4.0,
  });

  final String brand;
  final double size;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? asset = AppConstants.brandIcons[brand];
    if (asset == null) return _monogram(theme);

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        // Логотипы нарисованы для светлого фона: в тёмной теме под ними
        // оставляем белую подложку, иначе часть из них не читается.
        color: theme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.9)
            : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.directions_car,
          size: size * 0.7,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _monogram(ThemeData theme) {
    final String trimmed = brand.trim();
    final String letter =
        trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
