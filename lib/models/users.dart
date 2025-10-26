class Users {
  String? uid;
  String? email; // Added email field for account linking
  String? district;
  String? postcode;
  String? state;
  String? username;
  String? phoneNo;
  double? latitude;
  double? longitude;
  DateTime? locUpdateTime;
  bool? allowDiscoverable;
  bool? allowEmergencyAlert;
  String?
  detectionLanguage; // 'en' for English, 'zh' for Chinese (Traditional), 'ms' for Malay

  Users({
    this.uid,
    this.email,
    this.district,
    this.postcode,
    this.state,
    this.username,
    this.phoneNo,
    this.latitude,
    this.longitude,
    this.locUpdateTime,
    this.allowDiscoverable,
    this.allowEmergencyAlert,
    this.detectionLanguage,
  });

  factory Users.fromMap(Map<String, dynamic> map) {
    return Users(
      uid: map['uid'] as String?,
      email: map['email'] as String?,
      district: map['district'] as String?,
      postcode: map['postcode'] as String?,
      state: map['state'] as String?,
      username: map['username'] as String?,
      phoneNo: map['phoneNo'] as String?,
      latitude: map['latitude'] as double?,
      longitude: map['longtitutde'] as double?,
      locUpdateTime: map['locUpdateTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['locUpdateTime'])
          : null,
      allowDiscoverable: map['allowDiscoverable'] as bool?,
      allowEmergencyAlert: map['allowEmergencyAlert'] as bool?,
      detectionLanguage: map['detectionLanguage'] ?? 'en', // Default to English
    );
  }

  // Convert Users object to Map for CloudDB operations
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'district': district,
      'postcode': postcode,
      'state': state,
      'username': username,
      'phoneNo': phoneNo,
      'latitude': latitude,
      'longitude': longitude,
      'locUpdateTime': locUpdateTime?.millisecondsSinceEpoch,
      'allowDiscoverable': allowDiscoverable,
      'allowEmergencyAlert': allowEmergencyAlert,
      'detectionLanguage': detectionLanguage ?? 'en',
    };
  }
}
