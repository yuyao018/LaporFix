import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  //Get current GPS location
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    //Check whether location services (GPS) are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    //Check the current permission status
    permission = await Geolocator.checkPermission();

    //Request location permission if it is denied
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    //Handle permanently denied permissions
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission permanently denied.'
        'Please enable it from settings.',
      );
    }

    //Get current device position — try last known first, fall back to fresh request
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) return lastKnown;

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
    ).timeout(
      const Duration(seconds: 8),
      onTimeout: () => throw Exception('Location request timed out.'),
    );
  }

  //Convert Latitude & Longitude into readable address
  Future<String> getAddress(double latitude, double longitude) async {
    try {
      //Convert coordinates into address
      List<Placemark> placenarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      //Get first address
      Placemark place = placenarks.first;

      //Build readable address
      String address =
          '${place.street},'
          '${place.locality},'
          '${place.postalCode},'
          '${place.country}';

      return address;
    } catch (e) {
      return 'Unable to get address';
    }
  }
}
