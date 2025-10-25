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
  bool forLog;
  String mediaType;
  String mediaURI;

  media({
    required this.mediaID,
    required this.order,
    required this.forLog,
    required this.mediaType,
    required this.mediaURI,
  });

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