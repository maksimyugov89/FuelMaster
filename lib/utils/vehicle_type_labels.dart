import 'package:fuelmaster/l10n/app_localizations.dart';

const List<String> kVehicleTypes = [
  'Passenger Car',
  'Bus',
  'Truck',
  'Tractor',
  'Dump Truck',
  'Van',
  'Special Equipment',
];

String localizedVehicleType(AppLocalizations l10n, String type) {
  switch (type) {
    case 'Passenger Car':
      return l10n.passenger_car;
    case 'Bus':
      return l10n.bus;
    case 'Truck':
      return l10n.truck;
    case 'Tractor':
      return l10n.tractor;
    case 'Dump Truck':
      return l10n.dump_truck;
    case 'Van':
      return l10n.van;
    case 'Special Equipment':
      return l10n.special_equipment;
    default:
      return type;
  }
}
