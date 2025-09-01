import 'package:flutter/material.dart';

const Color _inputLabelColorLight = Color(0xFF0B2A3E); // Цвет лейблов полей ввода в светлой теме (темно-синий)
const Color _inputHintColorLight = Color(0x990B2A3E); // Цвет подсказок полей ввода в светлой теме (серо-синий с прозрачностью)

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: const Color(0xFFFFE3AD), // Фон из старой темы и скриншотов (светлый желтый)
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF026C96), // Синий для акцентов (например, OK кнопки, соответствует скриншотам с синим)
    secondary: Color(0xFF288DA9), // Вторичный цвет (теал, для дополнительных элементов)
    tertiary: Color(0xFF0B2A3E), // Цвет текста и границ (темно-синий, соответствует тексту на скриншотах)
    surface: Color(0xFFFDA46F), // Оранжевый для попапов и поверхностей (соответствует попапам и кнопкам на скриншотах)
    background: Color(0xFFFFE3AD), // Фон (соответствует скриншотам)
    error: Color(0xFFDB806B), // Цвет ошибок (красный)
    onPrimary: Colors.white,
    onSecondary: Color(0xFF0B2A3E),
    onBackground: Color(0xFF0B2A3E),
    onSurface: Color(0xFF0B2A3E),
    onError: Colors.white,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Color(0xFF0B2A3E), fontSize: 16), // Основной текст (темно-синий, соответствует скриншотам)
    headlineMedium: TextStyle(color: Color(0xFF0B2A3E), fontWeight: FontWeight.bold), // Заголовки (темно-синий, для соответствия тексту на скриншотах)
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFD96B3A), // Более темный оранжевый для кнопок (темнее #FDA46F, для "мужественности", сохраняя стиль скриншотов)
      foregroundColor: Colors.black, // Черный текст для кнопок (по запросу, для контраста и строгости)
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Округление соответствует скриншотам
      padding: const EdgeInsets.symmetric(vertical: 16),
    ),
  ),
  cardTheme: CardThemeData(
    color: Colors.white, // Белый для карточек и дропдаунов (соответствует дропдаунам на скриншотах)
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 2,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    // Обычная рамка (когда поле неактивно)
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
    ),
    // Яркая рамка (когда пользователь печатает в поле)
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: const Color(0xFF026C96), width: 2.5), // Ваш основной синий цвет
    ),
    border: OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(8)),
    ),
    labelStyle: const TextStyle(color: _inputLabelColorLight),
    hintStyle: const TextStyle(color: _inputHintColorLight),
  ),
  popupMenuTheme: const PopupMenuThemeData(
    color: Colors.white, // Белый для меню
    textStyle: TextStyle(color: Color(0xFF0B2A3E)),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Color(0xFFFDA46F), // Оранжевый для нижнего бара в светлой теме (соответствует скриншотам)
    selectedItemColor: Color.fromARGB(255, 9, 37, 48), // Primary (синий) для выбранных иконок/текста — цветной и современный
    unselectedItemColor: Color.fromARGB(255, 3, 50, 63), // Secondary (теал) с 0.6 opacity — для градиента цветности
    type: BottomNavigationBarType.fixed, // Современный фиксированный стиль (без сдвига)
    elevation: 0, // Плоский Material 3 дизайн
  ),
  iconTheme: const IconThemeData(
    color: Color.fromARGB(255, 10, 35, 44), // Primary (синий) для всех иконок — цветные и современные
    size: 24.0, // Стандартный размер Material 3
    opacity: 1.0, // Полная видимость
  ),
  iconButtonTheme: IconButtonThemeData(
    style: ButtonStyle(
      iconColor: MaterialStateProperty.all(Color(0xFF026C96)), // Primary для иконок в кнопках — цветные
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent, // Прозрачный фон для показа изображения
    elevation: 0, // Без тени
  ),
  switchTheme: SwitchThemeData(
    thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
      if (states.contains(MaterialState.selected)) {
        return const Color(0xFF22C55E); // Активный цвет из зеленого градиента
      }
      return Colors.grey.shade400; // Неактивный цвет
    }),
    trackColor: MaterialStateProperty.resolveWith<Color>((states) {
      if (states.contains(MaterialState.selected)) {
        return const Color(0xFF34D399).withOpacity(0.6); // Второй цвет градиента с прозрачностью
      }
      return Colors.grey.shade200;
    }),
  ),
);

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF030F19),
  colorScheme: const ColorScheme.dark(
    // Делаем основной акцентный цвет (для иконок) ярче
  primary: Color(0xFFFB7806), 
  secondary: Color.fromARGB(255, 211, 137, 52),
    // Делаем основной цвет текста (для заголовков) ярче
  tertiary: Color(0xFFA8DADC), 
  surface: Color(0xFF503B33),
  background: Color(0xFF030F19),
  error: Color.fromARGB(207, 202, 69, 16),
  onPrimary: Colors.black,
  onSecondary: Color.fromARGB(255, 20, 26, 23),
  onBackground: Color(0xFFA8DADC), // Используем новый яркий цвет для текста на фоне
  onSurface: Color(0xFFA8DADC), // И для текста на карточках
  onError: Colors.black,
  ),
  textTheme: const TextTheme(
    // Задаем новый, более яркий цвет для основного текста
  bodyMedium: TextStyle(color: Color(0xFFA8DADC), fontSize: 16), 
  headlineMedium: TextStyle(color: Color(0xFFA8DADC), fontWeight: FontWeight.bold),
    // Добавляем стиль для заголовков "Шаг 1"
    titleLarge: TextStyle(color: Color(0xFFA8DADC), fontWeight: FontWeight.bold),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color.fromARGB(255, 211, 140, 48), // Темнее оранжевый для кнопок (на 3 тона меньше яркости #FB7806, для снижения яркости по запросу)
      foregroundColor: const Color.fromARGB(255, 253, 253, 253), // Черный текст для контраста
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(vertical: 16),
    ),
  ),
  cardTheme: CardThemeData(
    color: const Color.fromARGB(255, 155, 126, 114), // Коричневый для карточек и меню
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 2,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    // Цвет фона поля ввода - темно-серый, но светлее основного фона
    fillColor: Colors.grey.shade800.withOpacity(0.5),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    // Обычная рамка
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.grey.shade700, width: 1.5),
    ),
    // Яркая оранжевая рамка при фокусе
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      // Используем ваш основной оранжевый цвет из темной темы
      borderSide: BorderSide(color: const Color.fromARGB(206, 155, 75, 6), width: 2.5),
    ),
    border: OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(8)),
    ),
    // Цвет для заголовка поля (например, "Начальный пробег")
    labelStyle: TextStyle(color: Colors.grey.shade300),
    // Цвет для текста-подсказки (placeholder)
    hintStyle: TextStyle(color: Colors.grey.shade600),
  ),
  popupMenuTheme: const PopupMenuThemeData(
    color: Color.fromARGB(183, 202, 69, 17), // Коричневый для меню
    textStyle: TextStyle(color: Color(0xFFA8DADC)), // Светло-теал текст (для соответствия изменениям)
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: const Color(0xFF030F19), // Фон нижней панели навигации (для нижнего бара в темной теме, для контраста на темном фоне)
    selectedItemColor: Color.fromARGB(220, 176, 176, 176), // Цвет выбранных элементов нижней панели (светло-серый для выбранных иконок/текста, читаемый на белом фоне)
    unselectedItemColor: Color.fromARGB(235, 128, 128, 128), // Цвет неактивных элементов нижней панели (тёмно-серый с 0.6 opacity, приглушенный, но видимый)
    type: BottomNavigationBarType.fixed, // Тип нижней панели навигации (фиксированный стиль, без сдвига)
    elevation: 0, // Тень нижней панели навигации (плоский Material 3 дизайн)
  ),
  iconTheme: const IconThemeData(
    color: Color.fromARGB(225, 202, 189, 69), // Цвет иконок (оранжевый для всех иконок — цветные и современные)
    size: 24.0, // Размер иконок (стандартный размер Material 3)
    opacity: 1.0, // Прозрачность иконок (полная видимость)
  ),
  iconButtonTheme: IconButtonThemeData(
    style: ButtonStyle(
      iconColor: MaterialStateProperty.all(Color.fromARGB(248, 143, 71, 9)), // Цвет иконок в кнопках (основной для цветных иконок)
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent, // Фон верхней панели (прозрачный для показа изображения)
    elevation: 0, // Тень верхней панели (без тени)
  ),
  switchTheme: SwitchThemeData(
    thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
      if (states.contains(MaterialState.selected)) {
        // Оставляем тот же яркий зеленый, он отлично смотрится на темном
        return const Color(0xFF22C55E); 
      }
      // Для неактивного состояния берем серый потемнее
      return Colors.grey.shade600; 
    }),
    trackColor: MaterialStateProperty.resolveWith<Color>((states) {
      if (states.contains(MaterialState.selected)) {
        return const Color(0xFF34D399).withOpacity(0.6);
      }
      // Фон для неактивного состояния делаем почти невидимым
      return Colors.white.withOpacity(0.1);
    }),
  ),
);

  // Зеленый градиент для действий "Рассчитать", "ОК"
  const Gradient greenGradient = LinearGradient(
    colors: [Color(0xFF34D399), Color(0xFF22C55E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Синий градиент для "Сохранить", "История"
  const Gradient blueGradient = LinearGradient(
    colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Оранжево-желтый для особых кнопок или акцентов
  const Gradient orangeGradient = LinearGradient(
    colors: [Color(0xFFFBBF24), Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Серый градиент для второстепенных или неактивных кнопок
  const Gradient greyGradient = LinearGradient(
    colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  // Серый градиент специально для темной темы
  const Gradient darkGreyGradient = LinearGradient(
    colors: [Color(0xFF6B7280), Color(0xFF4B5563)], // Цвета светлее
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );