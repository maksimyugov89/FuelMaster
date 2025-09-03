import 'package:flutter/material.dart';

// =====================================================================
// ✨ ИСПРАВЛЕННАЯ И УЛУЧШЕННАЯ ЦВЕТОВАЯ ПАЛИТРА ✨
// =====================================================================

// --- 1. Градиенты (без изменений) ---

const Gradient primaryActionGradient = LinearGradient(
  colors: [Color(0xFF007BFF), Color(0xFF0056B3)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const Gradient accentGradient = LinearGradient(
  colors: [Color(0xFFF7971E), Color(0xFFFFD200)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const Gradient secondaryActionGradient = LinearGradient(
  colors: [Color(0xFF495057), Color(0xFF343A40)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const Gradient darkerBlueGradient = LinearGradient(
  colors: [Color(0xFF0056B3), Color(0xFF003F8A)], // От темно-синего к еще более темному
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// --- 2. Исправленная светлая тема ---
final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: const Color(0xFFF5F7FA),
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF0056B3),
    secondary: Color(0xFF007BFF),
    tertiary: Color(0xFF1D2939),
    surface: Colors.white,
    background: Color(0xFFF5F7FA),
    error: Color(0xFFD32F2F),
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onBackground: Color(0xFF1D2939),
    onSurface: Color(0xFF1D2939),
    onError: Colors.white,
  ),
  textTheme: const TextTheme(
    // Основной текст стал чуть меньше
    bodyMedium: TextStyle(fontSize: 15), 
    // Заголовки карточек (например, "Ваши автомобили")
    headlineMedium: TextStyle(fontWeight: FontWeight.bold, fontSize: 18), 
    // Самый крупный заголовок на экране
    titleLarge: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
  ),
  cardTheme: CardThemeData( // ИСПРАВЛЕНО: Убрано "Data" из названия для соответствия конструктору
    // ❗️ ИСПРАВЛЕНО: Цвет карточек теперь белый, как и должно быть в светлой теме.
    color: const Color(0xFFFFFFFF), 
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 4,
  ),
  inputDecorationTheme: InputDecorationTheme(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    filled: true,
    fillColor: const Color(0xFFFFFFFF),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF0056B3), width: 2.5),
    ),
    // ❗️ УЛУЧШЕНО: Сделаем цвет метки чуть темнее для лучшего контраста.
    labelStyle: const TextStyle(color: Color(0xFF495057)), 
    hintStyle: TextStyle(color: Colors.grey.shade400),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
      if (states.contains(MaterialState.selected)) {
        return const Color(0xFF007BFF);
      }
      return Colors.grey.shade400;
    }),
    trackColor: MaterialStateProperty.resolveWith<Color>((states) {
      if (states.contains(MaterialState.selected)) {
        return const Color(0xFF007BFF).withOpacity(0.5);
      }
      return Colors.grey.shade200;
    }),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
  ),
  iconTheme: const IconThemeData(color: Color(0xFF0056B3)),
);

// --- 3. Исправленная темная тема ---
final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF101828),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFFF7971E),
    secondary: Color(0xFFFFD200),
    tertiary: Color(0xFFE9ECEF),
    surface: Color(0xFF1D2939),
    background: Color(0xFF101828),
    error: Color(0xFFE57373),
    onPrimary: Colors.black,
    onSecondary: Colors.black,
    onBackground: Color(0xFFE9ECEF),
    onSurface: Color(0xFFE9ECEF),
    onError: Colors.black,
  ),
  textTheme: const TextTheme(
    // Основной текст стал чуть меньше
    bodyMedium: TextStyle(fontSize: 15), 
    // Заголовки карточек (например, "Ваши автомобили")
    headlineMedium: TextStyle(fontWeight: FontWeight.bold, fontSize: 18), 
    // Самый крупный заголовок на экране
    titleLarge: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
  ),
  cardTheme: CardThemeData(
    color: const Color(0xFF1D2939),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 4,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF1D2939),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.grey.shade800, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFF7971E), width: 2.5),
    ),
    labelStyle: const TextStyle(color: Color(0xFFCED4DA)),
    hintStyle: TextStyle(color: Colors.grey.shade600),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    selectedItemColor: Color(0xFF007BFF),
    unselectedItemColor: Colors.grey,
    backgroundColor: Color(0xFF101828),
    elevation: 0,
    showUnselectedLabels: true,
  ),
  dialogTheme: const DialogThemeData( // ❗️ Оставляем только один dialogTheme
    backgroundColor: Color(0xFF253141),
    shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
      if (states.contains(MaterialState.selected)) {
        return const Color(0xFFF7971E);
      }
      return Colors.grey.shade600;
    }),
    trackColor: MaterialStateProperty.resolveWith<Color>((states) {
      if (states.contains(MaterialState.selected)) {
        return const Color(0xFFF7971E).withOpacity(0.5);
      }
      return Colors.white.withOpacity(0.1);
    }),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
  ),
  iconTheme: const IconThemeData(color: Color(0xFFF7971E)),
);