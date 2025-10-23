import 'package:flutter/material.dart';
import 'dart:io';
import '../app_theme.dart';
import '../util/location_helper.dart';
import 'package:huawei_map/huawei_map.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'media_operations_widget.dart';

class LodgeIncidentPage extends StatefulWidget {
  final String? incidentType;
  final String? description;
  final String? district;
  final String? postcode;
  final String? state;
  final String? audioRecordingPath;

  LodgeIncidentPage({
    Key? key,
    this.incidentType,
    this.description,
    this.district,
    this.postcode,
    this.state,
    this.audioRecordingPath,
  }) : super(key: key);

  @override
  _LodgeIncidentPageState createState() => _LodgeIncidentPageState();
}

class _LodgeIncidentPageState extends State<LodgeIncidentPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _districtController;
  late final TextEditingController _postcodeController;
  late final TextEditingController _stateController;
  late final TextEditingController _descriptionController;

  String _incidentType = 'general';
  List<File> _mediaFiles = [];

  HuaweiMapController? _mapController;
  LatLng? _selectedPosition;
  Set<Marker> _markers = {};
  bool _isLoadingAddress = false;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _districtController = TextEditingController(text: widget.district);
    _postcodeController = TextEditingController(text: widget.postcode);
    _stateController = TextEditingController(text: widget.state);
    _descriptionController = TextEditingController(text: widget.description);
    if (widget.incidentType != null) {
      _incidentType = widget.incidentType!;
    }

    // Auto-detect user location when page loads
    _initializeLocation();
  }

  @override
  void dispose() {
    _districtController.dispose();
    _postcodeController.dispose();
    _stateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    final locationService = LocationServiceHelper();

    bool hasPermission = await locationService.hasLocationPermission();
    if (!hasPermission) {
      hasPermission = await locationService.requestLocationPermission();
    }

    if (hasPermission) {
      try {
        final location = await locationService.getLastLocation();
        if (location != null && mounted) {
          final userPosition = LatLng(location.latitude!, location.longitude!);

          setState(() {
            _selectedPosition = userPosition;
            _isLoadingLocation = false;
            _markers = {
              Marker(
                markerId: MarkerId('selected_location'),
                position: userPosition,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange,
                ),
              ),
            };
          });

          await _reverseGeocodeLocation(userPosition.lat, userPosition.lng);

          _mapController?.animateCamera(CameraUpdate.newLatLng(userPosition));
        } else {
          if (mounted) {
            setState(() {
              _isLoadingLocation = false;
            });
          }
        }
      } catch (e) {
        print('Error initializing location: $e');
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location permission is required'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _initializeLocation,
            ),
          ),
        );
      }
    }
  }

  Future<void> _reverseGeocodeLocation(
    double latitude,
    double longitude,
  ) async {
    setState(() {
      _isLoadingAddress = true;
    });

    try {
      final apiKey =
          "DgEDAOcs4D0sDGUBoVxbgVd02uYRdo2kw9qeSFS5/KrMMaYEI7cOCtkJtpYr0nlE9+D1YwFMnU0G7L630uhclxboFY3v3jXCx0j8Hg==";

      // Huawei Site Kit Reverse Geocoding REST API
      final url = Uri.parse(
        'https://siteapi.cloud.huawei.com/mapApi/v1/siteService/reverseGeocode',
      );

      print('Reverse geocoding: $latitude, $longitude'); // Debug log

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey', // Add authorization header
        },
        body: jsonEncode({
          'location': {'lat': latitude, 'lng': longitude},
          'language': 'en',
          'returnPoi': true,
        }),
      );

      print('Response status: ${response.statusCode}'); // Debug log
      print('Response body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Check for API errors in response
        if (data['returnCode'] != null && data['returnCode'] != '0') {
          throw Exception(
            'API Error: ${data['returnDesc'] ?? 'Unknown error'}',
          );
        }

        if (data['sites'] != null && data['sites'].isNotEmpty) {
          final site = data['sites'][0];
          final address = site['address'];

          setState(() {
            // Extract full address before postcode for district
            String fullAddress = site['formatAddress'] ?? '';
            if (fullAddress.isNotEmpty) {
              // Remove postcode and everything after it
              if (address['postalCode'] != null &&
                  address['postalCode'].isNotEmpty) {
                String postcode = address['postalCode'];
                int postcodeIndex = fullAddress.indexOf(postcode);
                if (postcodeIndex > 0) {
                  _districtController.text = fullAddress
                      .substring(0, postcodeIndex)
                      .trim();
                } else {
                  _districtController.text = fullAddress;
                }
              } else {
                _districtController.text = fullAddress;
              }
            } else {
              // Fallback to locality if formatAddress is not available
              if (address['locality'] != null &&
                  address['locality'].isNotEmpty) {
                _districtController.text = address['locality'];
              } else if (address['subLocality'] != null &&
                  address['subLocality'].isNotEmpty) {
                _districtController.text = address['subLocality'];
              } else if (address['county'] != null &&
                  address['county'].isNotEmpty) {
                _districtController.text = address['county'];
              }
            }

            // Extract postcode
            if (address['postalCode'] != null &&
                address['postalCode'].isNotEmpty) {
              _postcodeController.text = address['postalCode'];
            }

            // Extract state
            if (address['adminArea'] != null &&
                address['adminArea'].isNotEmpty) {
              _stateController.text = address['adminArea'];
            } else if (address['subAdminArea'] != null &&
                address['subAdminArea'].isNotEmpty) {
              _stateController.text = address['subAdminArea'];
            }

            _isLoadingAddress = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Address auto-filled!'),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        } else {
          _handleNoAddress();
        }
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please check your API key.');
      } else if (response.statusCode == 403) {
        throw Exception('API access forbidden. Check API key permissions.');
      } else {
        throw Exception(
          'Failed to reverse geocode: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error reverse geocoding: $e');
      setState(() {
        _isLoadingAddress = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not get address: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _handleNoAddress() {
    setState(() {
      _isLoadingAddress = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No address found at this location'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _submitIncident() {
    if (_formKey.currentState!.validate()) {
      final incidentData = {
        'dateTime': DateTime.now().toIso8601String(),
        'district': _districtController.text,
        'postcode': _postcodeController.text,
        'state': _stateController.text,
        'incidentType': _incidentType,
        'description': _descriptionController.text,
        'mediaFiles': _mediaFiles.map((f) => f.path).toList(),
      };

      print('Incident Data: $incidentData');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Incident reported successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      setState(() {
        _incidentType = 'general';
        _mediaFiles.clear();
        _districtController.clear();
        _postcodeController.clear();
        _stateController.clear();
        _descriptionController.clear();
      });
    }
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.primaryOrange, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (trailing != null) ...[const Spacer(), trailing],
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return _buildSectionCard(
      title: 'Location Details',
      icon: Icons.location_on,
      children: [
        // Embedded Map
        Container(
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _isLoadingLocation
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          color: AppTheme.primaryOrange,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Fetching your location...',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : _selectedPosition == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_off,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Location not available',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _initializeLocation,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Try Again'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryOrange,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : HuaweiMap(
                        initialCameraPosition: CameraPosition(
                          target: _selectedPosition!,
                          zoom: 15,
                        ),
                        mapType: MapType.normal,
                        compassEnabled: true,
                        zoomControlsEnabled: true,
                        zoomGesturesEnabled: true,
                        scrollGesturesEnabled: true,
                        tiltGesturesEnabled: true,
                        rotateGesturesEnabled: true,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        markers: _markers,
                        gestureRecognizers: <Factory<
                            OneSequenceGestureRecognizer>>{
                          Factory<OneSequenceGestureRecognizer>(
                              () => EagerGestureRecognizer()),
                        },
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                        onClick: (LatLng position) {
                          setState(() {
                            _selectedPosition = position;
                            _markers = {
                              Marker(
                                markerId: MarkerId('selected_location'),
                                position: position,
                                icon: BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueOrange,
                                ),
                              ),
                            };
                          });
                          _reverseGeocodeLocation(position.lat, position.lng);
                        },
                      ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Use current location or tap on the map to select location',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 10,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _districtController,
          label: 'District',
          icon: Icons.location_city,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter district';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _postcodeController,
          label: 'Postcode',
          icon: Icons.markunread_mailbox,
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter postcode';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _stateController,
          label: 'State',
          icon: Icons.map,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter state';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      cursorColor: AppTheme.primaryOrange,
      onChanged: (value) {
        // Trigger rebuild to update label color
        setState(() {});
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        floatingLabelStyle: MaterialStateTextStyle.resolveWith((
          Set<MaterialState> states,
        ) {
          if (states.contains(MaterialState.focused)) {
            return const TextStyle(
              color: AppTheme.primaryOrange,
            );
          }
          if (controller.text.isNotEmpty) {
            return TextStyle(color: Colors.grey[600]);
          }
          return const TextStyle(color: AppTheme.primaryOrange);
        }),
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryOrange, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: validator,
    );
  }

  Widget _buildIncidentTypeCard({
    required String type,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _incidentType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _incidentType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryOrange.withOpacity(0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryOrange : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryOrange : Colors.grey[600],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? AppTheme.primaryOrange : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),
              Text(
                'Report Incidents or Post General News',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                'Share important information with the community',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 36),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionCard(
                      title: 'Date & Time',
                      icon: Icons.calendar_today,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              Text(
                                DateTime.now().toString().substring(0, 16),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildLocationSection(),
                    const SizedBox(height: 20),
                    _buildSectionCard(
                      title: 'Incident Type',
                      icon: Icons.category,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildIncidentTypeCard(
                                type: 'general',
                                icon: Icons.info_outline,
                                label: 'General',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildIncidentTypeCard(
                                type: 'threat',
                                icon: Icons.warning_amber_rounded,
                                label: 'Threat',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSectionCard(
                      title: 'Description',
                      icon: Icons.description,
                      children: [
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            hintText: 'Describe what happened in detail...',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppTheme.primaryOrange,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          maxLines: 6,
                          cursorColor: AppTheme.primaryOrange,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a description';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    MediaOperationsWidget(
                      mediaFiles: _mediaFiles,
                      onMediaFilesChanged: (files) {
                        setState(() {
                          _mediaFiles = files;
                        });
                      },
                      initialAudioFile: widget.audioRecordingPath != null
                          ? File(widget.audioRecordingPath!)
                          : null,
                    ),
                    const SizedBox(height: 45),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _submitIncident,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryOrange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Submit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}