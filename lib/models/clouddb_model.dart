class users {
  String? uid;
  String? district;
  String? postcode;
  String? state;
  String? username;
  String? phoneNo;
  double? latitude;
  double? longitude;
  bool? allowDiscoverable;
  bool? allowEmergencyAlert;

  users({
    this.uid,
    this.district,
    this.postcode,
    this.state,
    this.username,
    this.phoneNo,
    this.latitude,
    this.longitude,
    this.allowDiscoverable,
    this.allowEmergencyAlert,
  });

  Map<String, dynamic> getObjectData() {
    return {
      'uid': uid,
      'district': district,
      'postcode': postcode,
      'state': state,
      'username': username,
      'phoneNo': phoneNo,
      'latitude': latitude,
      'longitude': longitude,
      'allowDiscoverable': allowDiscoverable,
      'allowEmergencyAlert': allowEmergencyAlert,
    }..removeWhere((key, value) => value == null); // Remove null values
  }
}

class incidents {
  String iid;
  String uid;
  double latitude;
  double longitude;
  DateTime datetime;
  String incidentType;
  bool isAIGenerated;
  String desc;
  String? mediaID;
  String status;

  incidents({
    required this.iid,
    required this.uid,
    required this.latitude,
    required this.longitude,
    required this.datetime,
    required this.incidentType,
    required this.isAIGenerated,
    required this.desc,
    this.mediaID,
    required this.status,
  });

  factory incidents.fromMap(Map<String, dynamic> map) {
    return incidents(
      iid: map['iid'] as String,
      uid: map['uid'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      datetime: DateTime.fromMillisecondsSinceEpoch(map['datetime'] as int),
      incidentType: map['incidentType'] as String,
      isAIGenerated: map['isAIGenerated'] as bool,
      desc: map['desc'] as String,
      mediaID: map['mediaID'] as String?,
      status: map['status'] as String,
    );
  }

  Map<String, dynamic> getObjectData() {
    return {
      'iid': iid,
      'uid': uid,
      'latitude': latitude,
      'longitude': longitude,
      'datetime': datetime.millisecondsSinceEpoch,
      'incidentType': incidentType,
      'isAIGenerated': isAIGenerated,
      'desc': desc,
      'mediaID': mediaID,
      'status': status,
    }..removeWhere((key, value) => value == null);
  }
}

class media {
  String mediaID;
  int order;
  String mediaType;
  String mediaURI;

  media({
    required this.mediaID,
    required this.order,
    required this.mediaType,
    required this.mediaURI,
  });

  Map<String, dynamic> getObjectData() {
    return {
      'mediaID': mediaID,
      'order': order,
      'mediaType': mediaType,
      'mediaURI': mediaURI,
    }..removeWhere((key, value) => value == null);
  }
}

class incident_logs {
  String iid;
  DateTime timestamp;
  String sensorJsonData; // Keep as String to store serialized JSON
  String aiDesc;

  incident_logs({
    required this.iid,
    required this.timestamp,
    required this.sensorJsonData,
    required this.aiDesc,
  });

  Map<String, dynamic> getObjectData() {
    return {
      'iid': iid,
      // Convert DateTime to a compatible format
      'timestamp': timestamp.toIso8601String(),
      'sensorJsonData': sensorJsonData,
      'aiDesc': aiDesc,
    }..removeWhere((key, value) => value == null);
  }
}