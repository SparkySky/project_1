import 'package:huawei_location/huawei_location.dart' as huawei_loc;
import 'package:permission_handler/permission_handler.dart';

class LocationServiceHelper {
  final huawei_loc.FusedLocationProviderClient _locationService =
      huawei_loc.FusedLocationProviderClient();

  Future<bool> hasLocationPermission() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  Future<huawei_loc.Location?> getLastLocation() async {
    try {
      final location = await _locationService.getLastLocation();
      return location;
    } catch (e) {
      print('Error getting last location: $e');
      return null;
    }
  }
}