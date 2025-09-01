import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:fuelmaster/utils/logger.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    return Image.asset(
      'assets/fuelmaster_logo.png',
      fit: BoxFit.fitWidth,
      width: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        logger.e('Ошибка загрузки логотипа: $error');
        return Text(
          l10n.logo_not_found,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF5C191B),
            fontSize: 14,
            fontFamily: 'Roboto',
          ),
        );
      },
    );
  }
}

class ThemedAppLogo extends StatelessWidget {
  const ThemedAppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SizedBox(
        height: 60,
        child: AppLogo(),
      ),
    );
  }
}

class AnimatedButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;

  const AnimatedButton({super.key, required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark ? const Color(0xFFB5142B) : const Color(0xFFDD723C),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: child,
    );
  }
}

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String labelKey;
  final IconData? icon;
  final bool isNumber;
  final bool isPassword; // Добавлен параметр isPassword
  final bool enabled; // Добавлен параметр enabled
  final bool readOnly;
  final Widget? suffixIcon;
  final VoidCallback? onTap;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.labelKey,
    this.icon,
    this.isNumber = false,
    this.isPassword = false,
    this.enabled = true, // По умолчанию true
    this.readOnly = false,
    this.suffixIcon,
    this.onTap,
  });

  String _getLabelText(AppLocalizations l10n, String labelKey) {
    switch (labelKey) {
      case 'license_plate':
        return l10n.license_plate;
      case 'brand':
        return l10n.brand;
      case 'model':
        return l10n.model;
      case 'generation':
        return l10n.generation;
      case 'modification':
        return l10n.modification;
      case 'base_city_norm':
        return l10n.base_city_norm;
      case 'base_highway_norm':
        return l10n.base_highway_norm;
      case 'base_combined_norm':
        return l10n.base_combined_norm;
      case 'heater_fuel_consumption':
        return l10n.heater_fuel_consumption;
      case 'passenger_capacity':
        return l10n.passenger_capacity;
      case 'initial_mileage':
        return l10n.initial_mileage_short;
      case 'final_mileage':
        return l10n.final_mileage_short;
      case 'initial_fuel':
        return l10n.initial_fuel_short;
      case 'refuel':
        return l10n.refuel_short;
      case 'highway_distance':
        return l10n.highway_distance_short;
      case 'correction_factor':
        return l10n.correction_factor;
      case 'heater_operating_time':
        return l10n.heater_operating_time;
      case 'city':
        return l10n.city;
      case 'email':
        return l10n.email;
      case 'password':
        return l10n.password;
      default:
        return labelKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly,
      enabled: enabled,
      obscureText: isPassword, // Используем isPassword для скрытия текста
      keyboardType: isNumber ? TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      inputFormatters: isNumber
          ? [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              FilteringTextInputFormatter.deny(RegExp(r'-')),
            ]
          : null,
      decoration: InputDecoration(
        labelText: _getLabelText(l10n, labelKey),
        prefixIcon: icon != null ? Icon(icon, color: theme.colorScheme.primary) : null,
        suffixIcon: suffixIcon,
        border: theme.inputDecorationTheme.border,
        filled: theme.inputDecorationTheme.filled,
        fillColor: theme.inputDecorationTheme.fillColor,
        hintStyle: theme.inputDecorationTheme.hintStyle,
        labelStyle: theme.inputDecorationTheme.labelStyle ?? TextStyle(color: theme.colorScheme.onSurface),
      ).applyDefaults(theme.inputDecorationTheme),
      onTap: onTap,
    );
  }
}