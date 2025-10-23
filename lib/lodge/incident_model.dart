enum IncidentType { threat, general }

enum IncidentStatus { active, resolved }

enum MediaType { image, video, audio }

class IncidentMedia {
  final String path;
  final MediaType type;
  final String? thumbnail; // For videos

  IncidentMedia({
    required this.path,
    required this.type,
    this.thumbnail,
  });

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'type': type.toString(),
      'thumbnail': thumbnail,
    };
  }

  factory IncidentMedia.fromJson(Map<String, dynamic> json) {
    return IncidentMedia(
      path: json['path'] as String,
      type: MediaType.values.firstWhere(
        (e) => e.toString() == json['type'],
      ),
      thumbnail: json['thumbnail'] as String?,
    );
  }
}

class Incident {
  final int id;
  final DateTime dateTime;
  final double latitude;
  final double longitude;
  final String district;
  final String postcode;
  final String state;
  final IncidentType incidentType;
  final String description;
  IncidentStatus status;
  final List<IncidentMedia> media;

  Incident({
    required this.id,
    required this.dateTime,
    required this.latitude,
    required this.longitude,
    required this.district,
    required this.postcode,
    required this.state,
    required this.incidentType,
    required this.description,
    required this.status,
    this.media = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dateTime': dateTime.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'district': district,
      'postcode': postcode,
      'state': state,
      'incidentType': incidentType.toString(),
      'description': description,
      'status': status.toString(),
      'media': media.map((m) => m.toJson()).toList(),
    };
  }

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: json['id'] as int,
      dateTime: DateTime.parse(json['dateTime'] as String),
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      district: json['district'] as String,
      postcode: json['postcode'] as String,
      state: json['state'] as String,
      incidentType: IncidentType.values.firstWhere(
        (e) => e.toString() == json['incidentType'],
      ),
      description: json['description'] as String,
      status: IncidentStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
      ),
      media: (json['media'] as List<dynamic>?)
              ?.map((m) => IncidentMedia.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Incident copyWith({
    int? id,
    DateTime? dateTime,
    double? latitude,
    double? longitude,
    String? district,
    String? postcode,
    String? state,
    IncidentType? incidentType,
    String? description,
    IncidentStatus? status,
    List<IncidentMedia>? media,
  }) {
    return Incident(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      district: district ?? this.district,
      postcode: postcode ?? this.postcode,
      state: state ?? this.state,
      incidentType: incidentType ?? this.incidentType,
      description: description ?? this.description,
      status: status ?? this.status,
      media: media ?? this.media,
    );
  }
}