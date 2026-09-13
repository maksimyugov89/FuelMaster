import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:geolocator/geolocator.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Completer<YandexMapController> _controller = Completer();
  List<MapObject> _mapObjects = [];

  bool _isMeasuring = false;
  final List<Point> _measuredPoints = [];
  String _measuredDistance = "";

  @override
  void initState() {
    super.initState();
    _initPermission().then((_) => _moveToCurrentLocation());
  }

  // --- Разрешения ---
  Future<void> _initPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  Future<void> _moveToCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
      );
      final controller = await _controller.future;
      await controller.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: Point(
              latitude: position.latitude,
              longitude: position.longitude,
            ),
            zoom: 12.0,
          ),
        ),
        animation: const MapAnimation(
          type: MapAnimationType.smooth,
          duration: 1.5,
        ),
      );
    } catch (e) {
      debugPrint("Ошибка получения геолокации: $e");
    }
  }

  void _clearMapObjects() {
    setState(() {
      _mapObjects.clear();
      _measuredPoints.clear();
      _measuredDistance = "";
    });
  }

  // --- Поиск АЗС ---
  Future<void> _searchGasStations() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Идет поиск АЗС в радиусе ~50 км...')),
    );

    try {
      final position = await Geolocator.getCurrentPosition();
      final searchCenter =
          Point(latitude: position.latitude, longitude: position.longitude);

      const latDelta = 0.45;
      final lonDelta = 0.45 / cos(searchCenter.latitude * pi / 180);

      final (_, resultFuture) = await YandexSearch.searchByText(
        searchText: 'АЗС',
        geometry: Geometry.fromBoundingBox(
          BoundingBox(
            southWest: Point(latitude: searchCenter.latitude - latDelta, longitude: searchCenter.longitude - lonDelta),
            northEast: Point(latitude: searchCenter.latitude + latDelta, longitude: searchCenter.longitude + lonDelta),
          ),
        ),
        searchOptions: const SearchOptions(
          resultPageSize: 50,
          searchType: SearchType.biz,
        ),
      );

      final result = await resultFuture;
      
      // Вот переменная, которую нужно было объявить
      final List<MapObject> newPlacemarks = []; 

      if (result.items != null && result.items!.isNotEmpty) {
        debugPrint("✅ Найдено ${result.items!.length} АЗС.");
        for (var item in result.items!) {
          final point = item.geometry.first.point;
          if (point != null) {
            // Здесь мы добавляем метки в наш новый список
            newPlacemarks.add(
              PlacemarkMapObject(
                mapId: MapObjectId('gas_station_${item.name}_${point.latitude}_${point.longitude}'),
                point: point,
                icon: PlacemarkIcon.single(
                  PlacemarkIconStyle(
                    image: BitmapDescriptor.fromAssetImage('assets/fuelmaster_gas_pump.png'),
                    scale: 0.7,
                  ),
                ),
                text: PlacemarkText(
                  text: item.name,
                  style: const PlacemarkTextStyle(
                    size: 10,
                    placement: TextStylePlacement.bottom,
                    color: Colors.black,
                    outlineColor: Colors.white,
                  ),
                ),
              ),
            );
          }
        }
      } else if (mounted) {
        debugPrint("❌ Поиск АЗС: ничего не найдено");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('АЗС не найдены в радиусе 50 км.')),
        );
      }

      // B-13: после await экран мог быть закрыт.
      if (!mounted) return;
      setState(() {
        // И здесь мы присваиваем этот новый список
        _mapObjects = newPlacemarks;
      });

    } catch (e) {
      debugPrint("Ошибка поиска: $e");
      if (!mounted) return; // B-13
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Произошла ошибка при поиске. Попробуйте снова.')),
      );
      setState(() {
        _mapObjects = [];
      });
    }
  }

  // --- Измерение расстояния ---
  void _toggleMeasureMode() {
    setState(() {
      _isMeasuring = !_isMeasuring;
      _clearMapObjects();
    });
  }

  void _onMapTap(Point point) {
    if (!_isMeasuring) return;

    if (_measuredPoints.length < 2) {
      setState(() {
        _measuredPoints.add(point);
        _mapObjects.add(
          PlacemarkMapObject(
            mapId: MapObjectId('measure_dot_${_measuredPoints.length}'),
            point: point,
            icon: PlacemarkIcon.single(
              PlacemarkIconStyle(
                image: BitmapDescriptor.fromAssetImage('assets/fuelmaster_marker.png'),
                scale: 0.7,
              ),
            ),
          ),
        );
      });

      if (_measuredPoints.length == 2) {
        _createRoute();
      }
    }
  }

  Future<void> _createRoute() async {
    if (_measuredPoints.length != 2) return;

    final startPoint = _measuredPoints[0];
    final endPoint = _measuredPoints[1];

    try {
      final (_, resultFuture) = await YandexDriving.requestRoutes(
        points: [
          RequestPoint(
            point: startPoint,
            requestPointType: RequestPointType.wayPoint,
          ),
          RequestPoint(
            point: endPoint,
            requestPointType: RequestPointType.wayPoint,
          ),
        ],
        drivingOptions: const DrivingOptions(
          initialAzimuth: 0,
          routesCount: 1,
          avoidTolls: true,
        ),
      );

      final result = await resultFuture;

      if (result.routes != null && result.routes!.isNotEmpty) {
        final route = result.routes!.first;
        setState(() {
          _mapObjects.removeWhere((obj) => obj is PolylineMapObject);
          _mapObjects.add(
            PolylineMapObject(
              mapId: const MapObjectId('route_line'),
              polyline: route.geometry,
              strokeColor: Colors.blueAccent,
              strokeWidth: 4,
            ),
          );
          _measuredDistance = route.metadata.weight.distance.text;
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось построить маршрут.')),
        );
      }
    } catch (e) {
      debugPrint("Ошибка построения маршрута: $e");
      if (!mounted) return; // B-13
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка построения маршрута: $e')),
      );
    }
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Карта АЗС')),
      body: Stack(
        children: [
          YandexMap(
            onMapCreated: (YandexMapController yandexMapController) {
              _controller.complete(yandexMapController);
            },
            onMapTap: _onMapTap,
            mapObjects: _mapObjects,
          ),
          if (_isMeasuring)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _measuredPoints.isEmpty
                        ? 'Поставьте точку А на карте'
                        : _measuredPoints.length == 1
                            ? 'Поставьте точку Б на карте'
                            : 'Расстояние: $_measuredDistance',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: "find_gas_stations",
            onPressed: _isMeasuring ? null : _searchGasStations,
            backgroundColor:
                _isMeasuring ? Colors.grey : Theme.of(context).primaryColor,
            tooltip: 'Найти АЗС в радиусе 50 км',
            child: const Icon(Icons.local_gas_station),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "measure_distance",
            onPressed: _toggleMeasureMode,
            backgroundColor: _isMeasuring
                ? Colors.redAccent
                : Theme.of(context).colorScheme.secondary,
            tooltip:
                _isMeasuring ? 'Отменить измерение' : 'Замерить расстояние',
            child: Icon(_isMeasuring ? Icons.close : Icons.straighten),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "current_location",
            onPressed: _moveToCurrentLocation,
            tooltip: 'Мое местоположение',
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}
