import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LicensePlateWidget extends StatelessWidget {
  final String plateNumber;
  // --- НАЧАЛО ИЗМЕНЕНИЙ ---
  // 1. Добавляем новый параметр `scale`
  final double scale;
  // --- КОНЕЦ ИЗМЕНЕНИЙ ---

  const LicensePlateWidget({
    super.key,
    required this.plateNumber,
    // --- НАЧАЛО ИЗМЕНЕНИЙ ---
    // 2. Добавляем его в конструктор со значением по умолчанию
    this.scale = 1.0,
    // --- КОНЕЦ ИЗМЕНЕНИЙ ---
  });

  Map<String, String> _parsePlateNumber() {
    final cleanPlate = plateNumber.replaceAll(' ', '').toUpperCase();
    final RegExp plateRegex = RegExp(r'^([А-Я])(\d{3})([А-Я]{2})(\d{2,3})$');
    final match = plateRegex.firstMatch(cleanPlate);

    if (match != null) {
      final String firstLetter = match.group(1)!;
      final String numbers = match.group(2)!;
      final String lastLetters = match.group(3)!;
      final String region = match.group(4)!;
      final String mainPart = '$firstLetter $numbers $lastLetters';
      return {'main': mainPart, 'region': region};
    }

    if (cleanPlate.length > 2) {
      final regionPart = cleanPlate.substring(cleanPlate.length - 2);
      final mainPart = cleanPlate.substring(0, cleanPlate.length - 2);
      return {'main': mainPart, 'region': regionPart};
    }
    
    return {'main': cleanPlate, 'region': ''};
  }

  @override
  Widget build(BuildContext context) {
    final parts = _parsePlateNumber();
    final String mainNumber = parts['main']!;
    final String regionCode = parts['region']!;

    // --- НАЧАЛО ИЗМЕНЕНИЙ ---
    // 3. Оборачиваем весь виджет в Transform.scale для масштабирования
    return Transform.scale(
      scale: scale,
      // --- КОНЕЦ ИЗМЕНЕНИЙ ---
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          // 4. Масштабируем толщину рамки
          border: Border.all(color: Colors.black, width: 2.0 * scale), 
          // 5. Масштабируем скругление углов
          borderRadius: BorderRadius.circular(6.0 * scale), 
        ),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(
                  mainNumber,
                  style: TextStyle(
                    fontFamily: 'RoadUA',
                    // 6. Масштабируем все размеры шрифтов и отступов
                    fontSize: 36 * scale, 
                    color: Colors.black,
                    letterSpacing: 2 * scale,
                  ),
                ),
              ),
              
              SizedBox(width: 6 * scale),

              Container(
                width: 2 * scale,
                color: Colors.black,
              ),

              SizedBox(width: 4 * scale),

              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    regionCode,
                    style: TextStyle(
                      fontFamily: 'RoadUA',
                      fontSize: 26 * scale,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 2 * scale),
                  Row(
                    children: [
                      Text(
                        'RUS',
                        style: TextStyle(
                          fontSize: 10 * scale,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(width: 3 * scale),
                      SvgPicture.asset(
                        'assets/images/russian_flag.svg',
                        width: 20 * scale,
                      ),
                    ],
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}