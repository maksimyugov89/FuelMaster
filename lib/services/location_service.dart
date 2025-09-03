import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:fuelmaster/utils/logger.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  // Метод для получения названия текущего города
  Future<String?> getCurrentCity() async {
    try {
      // 1. Проверяем и запрашиваем разрешение на использование геолокации
      PermissionStatus permission = await Permission.location.request();

      if (permission.isGranted) {
        // 2. Если разрешение получено, получаем текущие координаты
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        );

        // 3. Преобразуем координаты в адрес (обратное геокодирование)
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        // 4. Извлекаем и возвращаем название города
        if (placemarks.isNotEmpty) {
          final city = placemarks.first.locality;
          if (city != null && city.isNotEmpty) {
            logger.d('Определен город: $city');
            return city;
          }
        }
        logger.w('Не удалось определить город из координат.');
        return null;
      } else if (permission.isDenied || permission.isPermanentlyDenied) {
        // 5. Если в разрешении отказано, логируем это
        logger.w('Пользователь отказал в доступе к геолокации.');
        // Можно добавить диалог для пользователя с просьбой включить геолокацию в настройках
        // openAppSettings();
        return null;
      }
    } catch (e) {
      logger.e('Ошибка при определении местоположения: $e');
      return null;
    }
    return null;
  }
}
