/// Global application constants and magic numbers.
class AppConstants {
  // Polling configuration
  static const int closePollSeconds = 30;
  static const int farPollSeconds = 300;
  static const int farDistanceMeters = 3000;
  static const int inGeofenceDistanceMeters = 200;
  static const int outOfGeofenceRetriggerMinutes = 20;

  // Polling options
  static const List<int> closePollSecondOptions = <int>[30, 60, 300];
  static const List<int> farPollSecondOptions = <int>[60, 300, 600];
  static const List<int> farDistanceMeterOptions = <int>[300, 1000, 2000, 3000, 5000];
  static const List<int> inGeofenceDistanceMeterOptions = <int>[50, 100, 150, 200, 300];
  static const List<int> outOfGeofenceRetriggerMinuteOptions = <int>[1, 20, 45, 60];

  // Dwell and stability
  static const int requiredStableSamples = 3;
  static const int duplicateLogGuardMinutes = 2;
  static const int maxSavedLocations = 5;

  // GPS accuracy
  static const double maxAccuracyMeters = 50;
  static const double maxSpeedForDwell = 1.2;
  static const Duration gpsReadTimeout = Duration(seconds: 20);

  // Geofence radius calculation adjustments
  static const double geofenceRadiusAdjustment = 80.0;
  static const double geofenceAccuracyBuffer = 35.0;
  static const double retriggerMinimumOutsideDistanceMeters = 300.0;

  // Dwell time options (minutes)
  static const List<int> logMinuteOptions = <int>[1, 5, 10, 15, 20, 30, 45, 60];

  // Polling mode thresholds
  static const int minPollingForDoubleStableRequirement = 120;
  static const int minPollingForSingleStableRequirement = 300;

  // Unlock code for location limit
  static const String locationLimitUnlockCode = 'arokicki';

  // Default display
  static const String defaultVersion = '1.0.1';
  static const String defaultBuildNumber = '3';
}
