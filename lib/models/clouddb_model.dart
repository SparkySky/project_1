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
  String? iid;
  String? uid;
  double? latitude;
  double? longitude;
  DateTime? datetime;
  String? incidentType;
  int? isAIGenerated;
  String? desc;
  String? mediaID;
  int? status;

  incidents({
    this.iid,
    this.uid,
    this.latitude,
    this.longitude,
    this.datetime,
    this.incidentType,
    this.isAIGenerated,
    this.desc,
    this.mediaID,
    this.status,
  });

  Map<String, dynamic> getObjectData() {
    return {
      'iid': iid,
      'uid': uid,
      'latitude': latitude,
      'longitude': longitude,
      // Convert DateTime to a compatible format (e.g., ISO 8601 String or Timestamp)
      'datetime': datetime?.toIso8601String(),
      'incidentType': incidentType,
      'isAIGenerated': isAIGenerated,
      'desc': desc,
      'mediaID': mediaID,
      'status': status,
    }..removeWhere((key, value) => value == null);
  }

  factory incidents.fromMap(Map<String, dynamic> map) {
    return incidents(
      iid: map['iid'],
      uid: map['uid'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      datetime: map['datetime'] != null
          ? DateTime.parse(map['datetime'])
          : null,
      incidentType: map['incidentType'],
      isAIGenerated: map['isAIGenerated'],
      desc: map['desc'],
      mediaID: map['mediaID'],
      status: map['status'],
    );
  }
}

class media {
  String? mediaID;
  int? order;
  int? forLog; // Changed from evidenceType based on user feedback
  String? mediaType;
  String? mediaURI;

  media({this.mediaID, this.order, this.forLog, this.mediaType, this.mediaURI});

  Map<String, dynamic> getObjectData() {
    return {
      'mediaID': mediaID,
      'order': order,
      'forLog': forLog,
      'mediaType': mediaType,
      'mediaURI': mediaURI,
    }..removeWhere((key, value) => value == null);
  }
}

class incident_logs {
  String? iid;
  DateTime? timestamp;
  String? sensorJsonData; // Keep as String to store serialized JSON
  String? aiDesc;

  incident_logs({this.iid, this.timestamp, this.sensorJsonData, this.aiDesc});

  Map<String, dynamic> getObjectData() {
    return {
      'iid': iid,
      // Convert DateTime to a compatible format
      'timestamp': timestamp?.toIso8601String(),
      'sensorJsonData': sensorJsonData,
      'aiDesc': aiDesc,
    }..removeWhere((key, value) => value == null);
  }
}
