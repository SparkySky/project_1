import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../app_theme.dart';
import 'incident_model.dart';

class IncidentHistoryPage extends StatefulWidget {
  const IncidentHistoryPage({super.key});

  @override
  _IncidentHistoryPageState createState() => _IncidentHistoryPageState();
}

class _IncidentHistoryPageState extends State<IncidentHistoryPage> {
  bool _isLoadingAddresses = false;
  
  // Sample incident history data with latitude/longitude only
  // District, postcode, and state will be fetched via reverse geocoding
  final List<Incident> _incidentHistory = [
    Incident(
      id: 1,
      dateTime: DateTime(2025, 10, 22, 14, 30),
      latitude: 5.3654,
      longitude: 100.4629,
      district: '',
      postcode: '',
      state: '',
      incidentType: IncidentType.threat,
      description: 'Suspicious activity near the park area. Multiple people acting strangely.',
      status: IncidentStatus.active,
      media: [
        IncidentMedia(
          path: 'https://images.unsplash.com/photo-1551650975-87deedd944c3?w=800',
          type: MediaType.image,
        ),
        IncidentMedia(
          path: 'https://images.unsplash.com/photo-1509281373149-e957c6296406?w=800',
          type: MediaType.image,
        ),
      ],
    ),
    Incident(
      id: 2,
      dateTime: DateTime(2025, 10, 20, 9, 15),
      latitude: 5.3589,
      longitude: 100.4725,
      district: '',
      postcode: '',
      state: '',
      incidentType: IncidentType.general,
      description: 'Road closure due to maintenance work.',
      status: IncidentStatus.active,
      media: [],
    ),
    Incident(
      id: 3,
      dateTime: DateTime(2025, 10, 18, 16, 45),
      latitude: 5.3645,
      longitude: 100.4598,
      district: '',
      postcode: '',
      state: '',
      incidentType: IncidentType.threat,
      description: 'Attempted break-in at residential area. Police notified.',
      status: IncidentStatus.resolved,
      media: [
        IncidentMedia(
          path: 'audio_recording.mp3',
          type: MediaType.audio,
        ),
      ],
    ),
    Incident(
      id: 4,
      dateTime: DateTime(2025, 10, 15, 11, 20),
      latitude: 5.3612,
      longitude: 100.4689,
      district: '',
      postcode: '',
      state: '',
      incidentType: IncidentType.general,
      description: 'Traffic accident at main intersection. Minor injuries reported.',
      status: IncidentStatus.resolved,
      media: [
        IncidentMedia(
          path: 'https://images.unsplash.com/photo-1449965408869-eaa3f722e40d?w=800',
          type: MediaType.image,
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadAddressesForIncidents();
  }

  Future<void> _loadAddressesForIncidents() async {
    setState(() {
      _isLoadingAddresses = true;
    });

    for (int i = 0; i < _incidentHistory.length; i++) {
      if (_incidentHistory[i].district.isEmpty) {
        await _reverseGeocodeForIncident(i);
      }
    }

    setState(() {
      _isLoadingAddresses = false;
    });
  }

  Future<void> _reverseGeocodeForIncident(int index) async {
    try {
      final incident = _incidentHistory[index];
      final apiKey = "DgEDAOcs4D0sDGUBoVxbgVd02uYRdo2kw9qeSFS5/KrMMaYEI7cOCtkJtpYr0nlE9+D1YwFMnU0G7L630uhclxboFY3v3jXCx0j8Hg==";

      final url = Uri.parse(
        'https://siteapi.cloud.huawei.com/mapApi/v1/siteService/reverseGeocode',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'location': {'lat': incident.latitude, 'lng': incident.longitude},
          'language': 'en',
          'returnPoi': true,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['returnCode'] != null && data['returnCode'] != '0') {
          throw Exception('API Error: ${data['returnDesc'] ?? 'Unknown error'}');
        }

        if (data['sites'] != null && data['sites'].isNotEmpty) {
          final site = data['sites'][0];
          final address = site['address'];
          
          String district = '';
          String postcode = '';
          String state = '';

          // Extract district (full address before postcode)
          String fullAddress = site['formatAddress'] ?? '';
          if (fullAddress.isNotEmpty) {
            if (address['postalCode'] != null && address['postalCode'].isNotEmpty) {
              String postcodeStr = address['postalCode'];
              int postcodeIndex = fullAddress.indexOf(postcodeStr);
              if (postcodeIndex > 0) {
                district = fullAddress.substring(0, postcodeIndex).trim();
                district = district.replaceAll(RegExp(r',\s*$'), '').trim();
              } else {
                district = fullAddress;
              }
            } else {
              district = fullAddress;
            }
          } else {
            // Fallback to locality
            if (address['locality'] != null && address['locality'].isNotEmpty) {
              district = address['locality'];
            } else if (address['subLocality'] != null && address['subLocality'].isNotEmpty) {
              district = address['subLocality'];
            } else if (address['county'] != null && address['county'].isNotEmpty) {
              district = address['county'];
            }
          }

          // Extract postcode
          if (address['postalCode'] != null && address['postalCode'].isNotEmpty) {
            postcode = address['postalCode'];
          }

          // Extract state
          if (address['adminArea'] != null && address['adminArea'].isNotEmpty) {
            state = address['adminArea'];
          } else if (address['subAdminArea'] != null && address['subAdminArea'].isNotEmpty) {
            state = address['subAdminArea'];
          }

          // Update incident with geocoded address
          setState(() {
            _incidentHistory[index] = incident.copyWith(
              district: district,
              postcode: postcode,
              state: state,
            );
          });
        }
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please check your API key.');
      } else if (response.statusCode == 403) {
        throw Exception('API access forbidden. Check API key permissions.');
      }
    } catch (e) {
      print('Error reverse geocoding incident $index: $e');
      // Set fallback values if geocoding fails
      setState(() {
        _incidentHistory[index] = _incidentHistory[index].copyWith(
          district: 'Location unavailable',
          postcode: 'N/A',
          state: 'N/A',
        );
      });
    }
  }

  void _markAsResolved(int index) {
    setState(() {
      _incidentHistory[index].status = IncidentStatus.resolved;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Incident marked as resolved'),
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

  void _deleteIncident(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Delete Incident'),
        content: const Text('Are you sure you want to delete this incident? The action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _incidentHistory.removeAt(index);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.delete, color: Colors.white),
                      SizedBox(width: 12),
                      Text('Incident deleted'),
                    ],
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteAllIncidents() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Delete All Incidents'),
        content: const Text('Are you sure you want to delete all incident history? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _incidentHistory.clear();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.delete_sweep, color: Colors.white),
                      SizedBox(width: 12),
                      Text('All incidents deleted'),
                    ],
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
            child: const Text(
              'Delete All',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('MYSafeZone'),
        automaticallyImplyLeading: false,
        actions: [
          if (_incidentHistory.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, size: 28, color: Colors.white),
              padding: const EdgeInsets.only(right: 24),
              onPressed: _deleteAllIncidents,
            ),
        ]
      ),
      body: _isLoadingAddresses
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading incidents...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : _incidentHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No incident history',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your reported incidents will appear here',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _incidentHistory.length,
                  itemBuilder: (context, index) {
                    return _buildIncidentPost(
                      _incidentHistory[index],
                      index,
                    );
                  },
                ),
    );
  }

  Widget _buildIncidentPost(Incident incident, int index) {
    final bool isResolved = incident.status == IncidentStatus.resolved;
    final bool isThreat = incident.incidentType == IncidentType.threat;
    final DateFormat dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          // Post Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Type Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isThreat 
                        ? Colors.red.withOpacity(0.1) 
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isThreat ? Icons.warning_amber_rounded : Icons.info_outline,
                    color: isThreat ? Colors.red : Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // Date and Location
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isThreat ? Colors.red : Colors.blue,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isThreat ? 'THREAT' : 'GENERAL',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isResolved ? Colors.green : Colors.orange,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isResolved ? Icons.check_circle : Icons.circle,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isResolved ? 'RESOLVED' : 'ACTIVE',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              dateFormat.format(incident.dateTime),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Location
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    incident.district.isEmpty 
                        ? 'Loading location...'
                        : '${incident.district}, ${incident.postcode}, ${incident.state}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              incident.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
                height: 1.5,
              ),
            ),
          ),

          // Media section
          if (incident.media.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildMediaSection(incident.media),
          ],

          const SizedBox(height: 16),

          // Action buttons (only show if active)
          if (!isResolved)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _markAsResolved(index),
                      icon: const Icon(
                        Icons.check_circle_outline,
                        size: 18,
                      ),
                      label: const Text('Mark as Resolved'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _deleteIncident(index),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            // Only delete button for resolved incidents
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _deleteIncident(index),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaSection(List<IncidentMedia> media) {
    final images = media.where((m) => m.type == MediaType.image).toList();
    final videos = media.where((m) => m.type == MediaType.video).toList();
    final audios = media.where((m) => m.type == MediaType.audio).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Images
        if (images.isNotEmpty) ...[
          if (images.length == 1)
            // Single image - full width
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(images[0].path),
                  fit: BoxFit.cover,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    // Open image viewer
                  },
                ),
              ),
            )
          else
            // Multiple images - scrollable
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: NetworkImage(images[index].path),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          // Open image viewer
                        },
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],

        // Videos
        if (videos.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: videos.map((video) => Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryOrange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Video recording',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                        Icon(
                          Icons.open_in_new,
                          size: 18,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  )).toList(),
            ),
          ),
        ],

        // Audio
        if (audios.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: audios.map((audio) => Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.mic,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Audio recording',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                        Icon(
                          Icons.play_circle_outline,
                          size: 24,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  )).toList(),
            ),
          ),
        ],
      ],
    );
  }
}