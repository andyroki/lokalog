class DebugBatteryAppUsage {
  DebugBatteryAppUsage({
    required this.packageName,
    required this.appName,
    required this.foregroundMinutes,
    required this.estimatedBatterySharePercent,
  });

  final String packageName;
  final String appName;
  final double foregroundMinutes;
  final double estimatedBatterySharePercent;
}

class LocationTrackingState {
  LocationTrackingState({
    required this.name,
    required this.far,
    required this.inGeofence,
    required this.outOfGeofence,
    required this.logged,
    required this.waitingToGetLogged,
    required this.timeInGeofenceMinutes,
    required this.remainingMinutes,
    this.distanceMeters,
    required this.lastUpdatedAt,
  });

  final String name;
  final bool far;
  final bool inGeofence;
  final bool outOfGeofence;
  final bool logged;
  final bool waitingToGetLogged;
  final double timeInGeofenceMinutes;
  final double remainingMinutes;
  final double? distanceMeters;
  final DateTime lastUpdatedAt;
}

class JobSite {
  JobSite({
    required this.name,
    required this.street,
    required this.city,
    required this.state,
    required this.zip,
    required this.lat,
    required this.lng,
    required this.requiredDwellMinutes,
  });

  final String name;
  final String street;
  final String city;
  final String state;
  final String zip;
  final double lat;
  final double lng;
  final int requiredDwellMinutes;

  String get address => '$street, $city, $state $zip';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'street': street,
      'city': city,
      'state': state,
      'zip': zip,
      'lat': lat,
      'lng': lng,
      'requiredDwellMinutes': requiredDwellMinutes,
    };
  }

  factory JobSite.fromJson(Map<String, dynamic> json) {
    return JobSite(
      name: (json['name'] ?? '').toString(),
      street: (json['street'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      zip: (json['zip'] ?? '').toString(),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      requiredDwellMinutes: (json['requiredDwellMinutes'] as num).toInt(),
    );
  }
}

class LocationFix {
  LocationFix({
    required this.lat,
    required this.lng,
    required this.accuracyMeters,
    required this.speedMetersPerSecond,
  });

  final double lat;
  final double lng;
  final double accuracyMeters;
  final double speedMetersPerSecond;
}

class SiteDistance {
  SiteDistance({required this.site, required this.distanceMeters});

  final JobSite site;
  final double distanceMeters;
}

class JobLog {
  JobLog({
    required this.name,
    required this.address,
    this.notes = '',
    required this.lat,
    required this.lng,
    required this.confidence,
    required this.confirmedByUser,
    required this.autoLogged,
    this.calendarAdded = false,
    required this.timestamp,
  });

  final String name;
  final String address;
  final String notes;
  final double lat;
  final double lng;
  final double confidence;
  final bool confirmedByUser;
  final bool autoLogged;
  final bool calendarAdded;
  final DateTime timestamp;

  JobLog copyWith({
    String? name,
    String? address,
    String? notes,
    double? lat,
    double? lng,
    double? confidence,
    bool? confirmedByUser,
    bool? autoLogged,
    bool? calendarAdded,
    DateTime? timestamp,
  }) {
    return JobLog(
      name: name ?? this.name,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      confidence: confidence ?? this.confidence,
      confirmedByUser: confirmedByUser ?? this.confirmedByUser,
      autoLogged: autoLogged ?? this.autoLogged,
      calendarAdded: calendarAdded ?? this.calendarAdded,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
