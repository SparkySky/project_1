// Emergency Services Data for Malaysia
// Police Stations, Hospitals, and Fire Departments

import 'dart:math';

class EmergencyService {
  final String name;
  final String phone;
  final double lat;
  final double lng;
  final String state;
  final String type; // 'police', 'hospital', 'fire'

  EmergencyService({
    required this.name,
    required this.phone,
    required this.lat,
    required this.lng,
    required this.state,
    required this.type,
  });

  String get emoji {
    switch (type) {
      case 'police':
        return '👮'; // Police officer
      case 'hospital':
        return '🏥'; // Hospital
      case 'fire':
        return '🚒'; // Fire truck
      default:
        return '📍';
    }
  }

  String get iconLabel {
    switch (type) {
      case 'police':
        return 'Police';
      case 'hospital':
        return 'Hospital';
      case 'fire':
        return 'Fire Dept';
      default:
        return 'Service';
    }
  }
}

class EmergencyServicesData {
  // Police Stations
  static final List<EmergencyService> policeStations = [
    // Kuala Lumpur & Selangor
    EmergencyService(
      name: 'Dang Wangi Police Station',
      phone: '03-26002222',
      lat: 3.1569,
      lng: 101.7017,
      state: 'Kuala Lumpur',
      type: 'police',
    ),
    EmergencyService(
      name: 'Brickfields Police Station',
      phone: '03-22979222',
      lat: 3.1338,
      lng: 101.6869,
      state: 'Kuala Lumpur',
      type: 'police',
    ),
    EmergencyService(
      name: 'Cheras Police Station',
      phone: '03-92842222',
      lat: 3.1193,
      lng: 101.7414,
      state: 'Kuala Lumpur',
      type: 'police',
    ),
    EmergencyService(
      name: 'Sentul Police Station',
      phone: '03-40482222',
      lat: 3.1865,
      lng: 101.6912,
      state: 'Kuala Lumpur',
      type: 'police',
    ),
    EmergencyService(
      name: 'Shah Alam Police Station',
      phone: '03-55102222',
      lat: 3.0738,
      lng: 101.5183,
      state: 'Selangor',
      type: 'police',
    ),
    EmergencyService(
      name: 'Petaling Jaya Police Station',
      phone: '03-79662222',
      lat: 3.1000,
      lng: 101.6500,
      state: 'Selangor',
      type: 'police',
    ),
    EmergencyService(
      name: 'Subang Jaya Police Station',
      phone: '03-56372222',
      lat: 3.0435,
      lng: 101.5902,
      state: 'Selangor',
      type: 'police',
    ),
    EmergencyService(
      name: 'Kajang Police Station',
      phone: '03-87362222',
      lat: 2.9923,
      lng: 101.7888,
      state: 'Selangor',
      type: 'police',
    ),
    // Penang
    EmergencyService(
      name: 'Georgetown Police Station',
      phone: '04-2692222',
      lat: 5.4141,
      lng: 100.3288,
      state: 'Penang',
      type: 'police',
    ),
    EmergencyService(
      name: 'Bayan Lepas Police Station',
      phone: '04-6432222',
      lat: 5.2972,
      lng: 100.2661,
      state: 'Penang',
      type: 'police',
    ),
    // Johor
    EmergencyService(
      name: 'Johor Bahru Central Police Station',
      phone: '07-2212222',
      lat: 1.4655,
      lng: 103.7578,
      state: 'Johor',
      type: 'police',
    ),
    EmergencyService(
      name: 'Skudai Police Station',
      phone: '07-5562222',
      lat: 1.5355,
      lng: 103.6579,
      state: 'Johor',
      type: 'police',
    ),
  ];

  // Hospitals
  static final List<EmergencyService> hospitals = [
    // Kuala Lumpur
    EmergencyService(
      name: 'Hospital Kuala Lumpur',
      phone: '03-26155555',
      lat: 3.1687,
      lng: 101.7041,
      state: 'Kuala Lumpur',
      type: 'hospital',
    ),
    EmergencyService(
      name: 'Hospital Tung Shin',
      phone: '03-20371888',
      lat: 3.1468,
      lng: 101.7016,
      state: 'Kuala Lumpur',
      type: 'hospital',
    ),
    EmergencyService(
      name: 'Hospital Universiti Malaya (UMMC)',
      phone: '03-79492020',
      lat: 3.1210,
      lng: 101.6566,
      state: 'Kuala Lumpur',
      type: 'hospital',
    ),
    // Selangor
    EmergencyService(
      name: 'Hospital Sungai Buloh',
      phone: '03-61454333',
      lat: 3.2174,
      lng: 101.5779,
      state: 'Selangor',
      type: 'hospital',
    ),
    EmergencyService(
      name: 'Hospital Tengku Ampuan Rahimah',
      phone: '03-33626868',
      lat: 3.0433,
      lng: 101.5284,
      state: 'Selangor',
      type: 'hospital',
    ),
    EmergencyService(
      name: 'Hospital Ampang',
      phone: '03-42896000',
      lat: 3.1558,
      lng: 101.7624,
      state: 'Selangor',
      type: 'hospital',
    ),
    EmergencyService(
      name: 'Hospital Serdang',
      phone: '03-89475555',
      lat: 3.0017,
      lng: 101.7188,
      state: 'Selangor',
      type: 'hospital',
    ),
    // Penang
    EmergencyService(
      name: 'Hospital Pulau Pinang',
      phone: '04-2225333',
      lat: 5.4020,
      lng: 100.3182,
      state: 'Penang',
      type: 'hospital',
    ),
    // Johor
    EmergencyService(
      name: 'Hospital Sultanah Aminah',
      phone: '07-2257000',
      lat: 1.4620,
      lng: 103.7269,
      state: 'Johor',
      type: 'hospital',
    ),
  ];

  // Fire Departments
  static final List<EmergencyService> fireDepartments = [
    // Kuala Lumpur
    EmergencyService(
      name: 'Balai Bomba Hang Tuah',
      phone: '03-20711444',
      lat: 3.1412,
      lng: 101.7066,
      state: 'Kuala Lumpur',
      type: 'fire',
    ),
    EmergencyService(
      name: 'Balai Bomba Pudu',
      phone: '03-92213444',
      lat: 3.1334,
      lng: 101.7117,
      state: 'Kuala Lumpur',
      type: 'fire',
    ),
    EmergencyService(
      name: 'Balai Bomba Sentul',
      phone: '03-40211911',
      lat: 3.1804,
      lng: 101.6919,
      state: 'Kuala Lumpur',
      type: 'fire',
    ),
    // Selangor
    EmergencyService(
      name: 'Balai Bomba Petaling Jaya',
      phone: '03-79571911',
      lat: 3.1073,
      lng: 101.6425,
      state: 'Selangor',
      type: 'fire',
    ),
    EmergencyService(
      name: 'Balai Bomba Shah Alam',
      phone: '03-55190994',
      lat: 3.0708,
      lng: 101.5185,
      state: 'Selangor',
      type: 'fire',
    ),
    EmergencyService(
      name: 'Balai Bomba Subang',
      phone: '03-56338994',
      lat: 3.0742,
      lng: 101.5975,
      state: 'Selangor',
      type: 'fire',
    ),
    // Penang
    EmergencyService(
      name: 'Balai Bomba Jalan Perak',
      phone: '04-2291515',
      lat: 5.4204,
      lng: 100.3296,
      state: 'Penang',
      type: 'fire',
    ),
    // Johor
    EmergencyService(
      name: 'Balai Bomba Larkin',
      phone: '07-2371444',
      lat: 1.4854,
      lng: 103.7442,
      state: 'Johor',
      type: 'fire',
    ),
  ];

  // Get all emergency services
  static List<EmergencyService> get allServices {
    return [...policeStations, ...hospitals, ...fireDepartments];
  }

  // Get services within radius (in kilometers)
  static List<EmergencyService> getServicesWithinRadius(
    double userLat,
    double userLng,
    double radiusKm,
  ) {
    return allServices.where((service) {
      final distance = _calculateDistance(
        userLat,
        userLng,
        service.lat,
        service.lng,
      );
      return distance <= radiusKm;
    }).toList();
  }

  // Calculate distance between two points using Haversine formula
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a =
        0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }
}
