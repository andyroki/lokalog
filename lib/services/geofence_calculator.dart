import 'package:lokalog_app/constants/app_constants.dart';

/// Encapsulates geofence distance calculations.
/// Provides consistent geofence boundary logic throughout the app.
class GeofenceCalculator {
  final double inGeofenceDistanceMeters;

  GeofenceCalculator({required this.inGeofenceDistanceMeters});

  /// Calculates the effective geofence radius based on GPS accuracy.
  ///
  /// The radius is adaptive: as GPS accuracy improves, the radius stays
  /// at the configured distance. As accuracy degrades, the radius expands
  /// to account for GPS uncertainty.
  ///
  /// Formula:
  ///   effectiveRadius = max(configuredDistance,
  ///                     min(configuredDistance + 80m,
  ///                         accuracyMeters + 35m))
  ///
  /// This prevents:
  /// - GPS jitter from triggering false geofence exits
  /// - Over-wide geofences that trigger too early
  double calculateEffectiveRadius(double gpsAccuracyMeters) {
    return max(
      inGeofenceDistanceMeters.toDouble(),
      min(
        inGeofenceDistanceMeters.toDouble() +
            AppConstants.geofenceRadiusAdjustment,
        gpsAccuracyMeters + AppConstants.geofenceAccuracyBuffer,
      ),
    );
  }

  /// Checks if a distance is within the geofence.
  bool isWithinGeofence(double distanceMeters, double effectiveRadius) {
    return distanceMeters <= effectiveRadius;
  }

  /// Checks if confidently outside the geofence.
  /// Used for retrigger timer safety: only advance the timer when
  /// we're certain we've exited, not just marginal/noisy readings.
  bool isConfidentlyOutside(
    double distanceMeters,
    double effectiveRadius,
    double gpsAccuracyMeters,
    double maxAccuracyMeters,
  ) {
    final bool farEnough = distanceMeters > effectiveRadius;
    final bool goodAccuracy = gpsAccuracyMeters <= maxAccuracyMeters;
    return farEnough && goodAccuracy;
  }
}

double max(double a, double b) => a > b ? a : b;
double min(double a, double b) => a < b ? a : b;
