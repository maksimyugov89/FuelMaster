import 'package:flutter_test/flutter_test.dart';
import 'package:fuelmaster/utils/weather_service.dart';

/// Регрессия B-5 аудита: WeatherAPI возвращает целые значения как int
/// (temp_c: 20), а прямой каст `as double` ронял расчёт топлива с TypeError.
void main() {
  group('WeatherService.parseNumeric', () {
    test('целые числа из JSON приводятся к double', () {
      expect(WeatherService.parseNumeric(20), 20.0);
      expect(WeatherService.parseNumeric(0), 0.0);
      expect(WeatherService.parseNumeric(-5), -5.0);
    });

    test('double и строки разбираются', () {
      expect(WeatherService.parseNumeric(20.5), 20.5);
      expect(WeatherService.parseNumeric('20.5'), 20.5);
      expect(WeatherService.parseNumeric('20'), 20.0);
    });

    test('null и мусор дают fallback', () {
      expect(WeatherService.parseNumeric(null), 1.0);
      expect(WeatherService.parseNumeric('abc'), 1.0);
      expect(WeatherService.parseNumeric(null, 0), 0.0);
      expect(WeatherService.parseNumeric('abc', 0), 0.0);
    });
  });
}
