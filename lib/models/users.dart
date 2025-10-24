class Users {
  String? uid;
  String? district;
  String? postcode;
  String? state;
  String? username;
  String? phoneNo;
  double? latitude;
  double? longtitutde;
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
    this.longtitutde,
    this.allowDiscoverable,
    this.allowEmergencyAlert,
  });

  // Factory constructor for creating Users from CloudDB query results
  factory Users.fromMap(Map<String, dynamic> map) {
    return Users(
      uid: map['uid'] as String?,
      district: map['district'] as String?,
      postcode: map['postcode'] as String?,
      state: map['state'] as String?,
      username: map['username'] as String?,
      phoneNo: map['phoneNo'] as String?,
      latitude: map['latitude'] as double?,
      longtitutde: map['longtitutde'] as double?,
      allowDiscoverable: map['allowDiscoverable'] as bool?,
      allowEmergencyAlert: map['allowEmergencyAlert'] as bool?,
    );
  }

  // Convert Users object to Map for CloudDB operations
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'district': district,
      'postcode': postcode,
      'state': state,
      'username': username,
      'phoneNo': phoneNo,
      'latitude': latitude,
      'longtitutde': longtitutde,
      'allowDiscoverable': allowDiscoverable,
      'allowEmergencyAlert': allowEmergencyAlert,
    };
  }
}
