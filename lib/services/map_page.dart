import 'dart:async';
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
  final List<MapObject> _mapObjects = [];

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
        desiredAccuracy: LocationAccuracy.high,
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
    _clearMapObjects();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Идет поиск АЗС в радиусе 50 км...')),
    );

    try {
      final position = await Geolocator.getCurrentPosition();
      final searchCenter =
          Point(latitude: position.latitude, longitude: position.longitude);

      final (_, resultFuture) = await YandexSearch.searchByText(
        searchText: 'АЗС',
        geometry: Geometry.fromBoundingBox(
          BoundingBox(
            southWest: Point(latitude: searchCenter.latitude - 0.5, longitude: searchCenter.longitude - 0.5),
            northEast: Point(latitude: searchCenter.latitude + 0.5, longitude: searchCenter.longitude + 0.5),
          ),
        ),
        searchOptions: const SearchOptions(),
        
                
      );

      final result = await resultFuture;
      final List<MapObject> gasStationPlacemarks = [];

      if (result.items != null && result.items!.isNotEmpty) {
        for (var item in result.items!) {
          final point = item.geometry.first.point;
          if (point != null) {
            gasStationPlacemarks.add(
              PlacemarkMapObject(
                mapId: MapObjectId('gas_station_${item.name}'),
                point: point,
                icon: PlacemarkIcon.single(
                  PlacemarkIconStyle(
                    image: BitmapDescriptor.fromAssetImage('assets/fuelmaster_gas_pump.png'),
                    scale: 0.7,
                  ),
                ),
                // Можно убрать текст, если PlacemarkText не поддерживается в твоей версии
                text: PlacemarkText(
                  text: item.name,
                  style: const PlacemarkTextStyle(
                    size: 10,
                    placement: TextStylePlacement.bottom,
                  ),
                ),
              ),
            );
          }
        }
      } else {
        debugPrint("❌ Поиск АЗС: ничего не найдено");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('АЗС не найдены в радиусе 50 км.')),
        );
      }

      setState(() {
        _mapObjects.addAll(gasStationPlacemarks);
      });
    } catch (e) {
      debugPrint("Ошибка поиска: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка поиска: $e')),
      );
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось построить маршрут.')),
        );
      }
    } catch (e) {
      debugPrint("Ошибка построения маршрута: $e");
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
            child: const Icon(Icons.local_gas_station),
            tooltip: 'Найти АЗС в радиусе 50 км',
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "measure_distance",
            onPressed: _toggleMeasureMode,
            backgroundColor: _isMeasuring
                ? Colors.redAccent
                : Theme.of(context).colorScheme.secondary,
            child: Icon(_isMeasuring ? Icons.close : Icons.straighten),
            tooltip:
                _isMeasuring ? 'Отменить измерение' : 'Замерить расстояние',
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "current_location",
            onPressed: _moveToCurrentLocation,
            child: const Icon(Icons.my_location),
            tooltip: 'Мое местоположение',
          ),
        ],
      ),
    );
  }
}
