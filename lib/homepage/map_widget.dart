import 'dart:async';
import 'package:flutter/material.dart';
import 'package:huawei_map/huawei_map.dart';
import 'package:huawei_location/huawei_location.dart' as hwLocation;
import 'package:permission_handler/permission_handler.dart';

class MapWidget extends StatefulWidget {
  final List<Map<String, dynamic>> incidents;

  const MapWidget({
    super.key,
    required this.incidents,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  HuaweiMapController? _mapController;
  final hwLocation.FusedLocationProviderClient _locationService =
      hwLocation.FusedLocationProviderClient();
  hwLocation.Location? _currentLocation;

  final hwLocation.GeocoderService _geocoderService = hwLocation.GeocoderService();
  Set<Marker> _incidentMarkers = {};
  bool _isLoadingMarkers = true;
  bool _isLoadingLocation = true; // New flag for location loading
  CameraPosition? _initialPosition; // Will be set after fetching location

  // Default fallback position
  static const CameraPosition _kFallbackPosition = CameraPosition(
    target: LatLng(5.3644, 100.4660),
    zoom: 13.0,
  );

  @override
  void initState() {
    super.initState();
    HuaweiMapInitializer.initializeMap();
    _initializeMap(); // New initialization method
  }

  // Initialize map by fetching location first
  Future<void> _initializeMap() async {
    await _requestLocationPermissionAndFetch();
    if (mounted) {
      _geocodeAndBuildMarkers();
    }
  }

  @override
  void didUpdateWidget(covariant MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.incidents != oldWidget.incidents) {
      _geocodeAndBuildMarkers();
    }
  }

  Future<void> _geocodeAndBuildMarkers() async {
    print("--- Starting geocoding ---");
    if (!mounted) {
      print("Widget not mounted, exiting geocoding.");
      return;
    }
    if (mounted) {
      setState(() {
        _isLoadingMarkers = true;
        _incidentMarkers = {};
      });
    }

    final Set<Marker> markers = {};
    int markerIndex = 0;
    final hwLocation.Locale geocodingLocale = hwLocation.Locale(language: 'en', country: 'my');

    List<Future<void>> geocodingFutures = [];

    for (final incident in widget.incidents) {
      geocodingFutures.add(Future<void>(() async {
        final String address = incident['location'] ?? '';
        final String title = incident['title'] ?? 'Incident';
        final String snippet = incident['timestamp'] ?? '';

        print("Processing incident: '$title' at '$address'");

        if (address.isNotEmpty) {
          try {
            final hwLocation.GetFromLocationNameRequest request =
                hwLocation.GetFromLocationNameRequest(locationName: address, maxResults: 1);

            print("  Calling geocoder for: $address");
            final List<hwLocation.HWLocation> locations =
                await _geocoderService.getFromLocationName(request, geocodingLocale);
            print("  Geocoder returned ${locations.length} results for '$address'.");

            if (locations.isNotEmpty) {
              final hwLocation.HWLocation hwLoc = locations.first;
              if (hwLoc.latitude != null && hwLoc.longitude != null) {
                final LatLng position = LatLng(hwLoc.latitude!, hwLoc.longitude!);
                print("Geocoded '$address' to: $position");

                double markerHue;
                switch (incident['severity']?.toLowerCase()) {
                  case 'high':
                    markerHue = BitmapDescriptor.hueRed;
                    break;
                  case 'medium':
                    markerHue = BitmapDescriptor.hueOrange;
                    break;
                  case 'low':
                    markerHue = BitmapDescriptor.hueYellow;
                    break;
                  default:
                    markerHue = BitmapDescriptor.hueAzure;
                }

                markers.add(
                  Marker(
                    markerId: MarkerId('incident_${incident['id']}_$markerIndex'),
                    position: position,
                    icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
                    infoWindow: InfoWindow(
                      title: title,
                      snippet: snippet,
                    ),
                  ),
                );
                markerIndex++;
              } else {
                print('    Geocoding result for "$address" missing coordinates.');
              }
            } else {
              print('    Geocoding failed for address: $address (No results found)');
            }
          } catch (e, stackTrace) {
            print('    !!!!!!!! ERROR during geocoding for "$address": $e');
            print('    !!!!!!!! StackTrace: $stackTrace');
          }
        } else {
          print("  Skipping incident due to empty address.");
        }
      }));
    }

    try {
      await Future.wait(geocodingFutures);
    } catch (e) {
      print("Error occurred during Future.wait: $e");
    }

    print("--- Finished geocoding. Found ${markers.length} markers. Updating state. ---");
    if (mounted) {
      setState(() {
        _incidentMarkers = markers;
        _isLoadingMarkers = false;
      });
    } else {
      print("Widget unmounted before final setState.");
    }
  }

  Future<void> _requestLocationPermissionAndFetch() async {
    print("=== Starting location fetch ===");
    
    // 1. Check/Request Permission
    var status = await Permission.locationWhenInUse.status;
    print("Initial permission status: $status");
    
    if (!status.isGranted) {
      print("Requesting location permission...");
      status = await Permission.locationWhenInUse.request();
      print("Permission request result: $status");
      
      if (!status.isGranted) {
        print("Location permission DENIED by user.");
        if (mounted) {
          setState(() {
            _initialPosition = _kFallbackPosition;
            _isLoadingLocation = false;
          });
        }
        return;
      }
    }

    print("Permission GRANTED. Proceeding to fetch location...");

    // 2. Fetch Location
    try {
      // First try to get last known location (fastest)
      print("Attempting to get last known location...");
      hwLocation.Location? location = await _locationService.getLastLocation();
      
      if (location != null && location.latitude != null && location.longitude != null) {
        print("SUCCESS! Got last location: ${location.latitude}, ${location.longitude}");
        if (mounted) {
          setState(() {
            _currentLocation = location;
            _initialPosition = CameraPosition(
              target: LatLng(location.latitude!, location.longitude!),
              zoom: 15.0,
            );
            _isLoadingLocation = false;
          });
        }
        return; // Exit early since we got the location
      }

      print("Last location is null or invalid. Requesting fresh location update...");
      
      // If last location is null, request a fresh update with timeout
      final Completer<void> locationCompleter = Completer<void>();
      int? callbackId;
      
      // Set a timeout to prevent infinite waiting
      Timer timeoutTimer = Timer(const Duration(seconds: 10), () {
        print("Location request TIMEOUT after 10 seconds.");
        if (!locationCompleter.isCompleted) {
          locationCompleter.complete();
          if (callbackId != null) {
            _locationService.removeLocationUpdates(callbackId);
          }
          if (mounted) {
            setState(() {
              _initialPosition = _kFallbackPosition;
              _isLoadingLocation = false;
            });
          }
        }
      });
      
      callbackId = await _locationService.requestLocationUpdatesCb(
        hwLocation.LocationRequest()
          ..priority = hwLocation.LocationRequest.PRIORITY_HIGH_ACCURACY
          ..numUpdates = 1,
        hwLocation.LocationCallback(
          onLocationResult: (locationResult) {
            print("Location callback triggered!");
            if (!locationCompleter.isCompleted && 
                locationResult.lastLocation != null && 
                locationResult.lastLocation!.latitude != null &&
                locationResult.lastLocation!.longitude != null) {
              
              print("SUCCESS! Got fresh location: ${locationResult.lastLocation!.latitude}, ${locationResult.lastLocation!.longitude}");
              timeoutTimer.cancel();
              locationCompleter.complete();
              
              if (mounted) {
                setState(() {
                  _currentLocation = locationResult.lastLocation;
                  _initialPosition = CameraPosition(
                    target: LatLng(
                      locationResult.lastLocation!.latitude!,
                      locationResult.lastLocation!.longitude!,
                    ),
                    zoom: 15.0,
                  );
                  _isLoadingLocation = false;
                });
              }
            }
            if (callbackId != null) {
              _locationService.removeLocationUpdates(callbackId);
            }
          },
          onLocationAvailability: (availability) {
            print("Location availability: ${availability?.isLocationAvailable}");
          },
        ),
      );
      
      await locationCompleter.future;
      
    } catch (e, stackTrace) {
      print("ERROR fetching location: $e");
      print("StackTrace: $stackTrace");
      if (mounted) {
        setState(() {
          _initialPosition = _kFallbackPosition;
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _onMapCreated(HuaweiMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    print("Building MapWidget with ${_incidentMarkers.length} markers.");
    
    // Show loading indicator while fetching location
    if (_isLoadingLocation || _initialPosition == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Fetching your location...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        HuaweiMap(
          initialCameraPosition: _initialPosition!,
          onMapCreated: _onMapCreated,
          mapType: MapType.normal,
          compassEnabled: true,
          zoomControlsEnabled: true,
          zoomGesturesEnabled: true,
          scrollGesturesEnabled: true,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          buildingsEnabled: true,
          trafficEnabled: false,
          markers: _incidentMarkers,
        ),
        // Loading indicator while geocoding
        if (_isLoadingMarkers)
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }
}