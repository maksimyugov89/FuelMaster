import 'package:flutter/material.dart';

class GradientButton extends StatelessWidget {
  final String text;
  final Gradient gradient;
  final VoidCallback onPressed;
  final IconData iconData; // Используем только стандартные иконки

  const GradientButton({
    super.key,
    required this.text,
    required this.gradient,
    required this.onPressed,
    required this.iconData, // Иконка теперь обязательна
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(8);

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: borderRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              // ✨ ЗАМЕНИТЕ ЭТОТ СПИСОК:
              children: [
                Icon(iconData, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                // Flexible говорит контейнеру с текстом занять ВСЁ оставшееся место
                Flexible(
                  // FittedBox уменьшает текст, если он не помещается в это место
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}