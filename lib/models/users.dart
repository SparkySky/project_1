class Users {
  String? uid;
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

  Users({
    this.uid,
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
  });

  factory Users.fromMap(Map<String, dynamic> map) {
    return Users(
      uid: map['uid'],
      district: map['district'],
      postcode: map['postcode'],
      state: map['state'],
      username: map['username'],
      phoneNo: map['phoneNo'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      locUpdateTime: map['locUpdateTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['locUpdateTime'])
          : null,
      allowDiscoverable: map['allowDiscoverable'],
      allowEmergencyAlert: map['allowEmergencyAlert'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
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
    };
  }
}
