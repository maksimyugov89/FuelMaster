import 'dart:ui';
import 'package:flutter/material.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // 1. Проверяем, какая тема сейчас активна
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 2. Задаем цвета в зависимости от темы
    final baseColor = isDark ? const Color(0xFF101828) : const Color(0xFFF5F7FA);
    final blobColor1 = isDark ? Colors.deepPurple.withOpacity(0.3) : Colors.green.withOpacity(0.2);
    final blobColor2 = isDark ? Colors.indigo.withOpacity(0.4) : Colors.blue.withOpacity(0.2);

    return Container(
      color: baseColor, // Используем базовый цвет для текущей темы
      child: Stack(
        children: [
          // Размещаем цветные "пятна" с цветами для текущей темы
          Positioned(
            top: -100,
            left: -150,
            child: Container(
              height: 300,
              width: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: blobColor1,
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -200,
            child: Container(
              height: 400,
              width: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: blobColor2,
              ),
            ),
          ),

          // Фильтр размытия остается без изменений
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 100.0, sigmaY: 100.0),
            child: Container(
              decoration: const BoxDecoration(color: Colors.transparent),
            ),
          ),

          // Поверх всего размещаем основное содержимое страницы
          child,
        ],
      ),
    );
  }
}