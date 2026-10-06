import 'package:get/get.dart';
import '../../services/location_service.dart';

class LocationController extends GetxController {
  final LocationService _locationService = Get.find<LocationService>();

  // Future<void> _requestLocationPermission() async {
  //   await _locationService.requestLocationPermission();
  // }

  // Getters to expose location service data
  bool get hasLocationPermission => _locationService.hasLocationPermission.value;
  bool get isLocationServiceEnabled => _locationService.isLocationServiceEnabled.value;
  
  // Methods
  Future<void> requestLocationPermission() async {
    await _locationService.requestLocationPermission();
  }

  Future<void> openLocationSettings() async {
    await _locationService.openLocationSettings();
  }

  Future<void> openAppSettings() async {
    await _locationService.openAppSettings();
  }
}
