import 'package:lokalog_app/models/lokalog_models.dart';

/// Result of a logging validation check.
enum ValidationResult {
  /// Site can be logged; no blockers.
  canLog,

  /// Site was already logged this session.
  alreadyLoggedThisSession,

  /// Recent log exists; within cooldown window.
  withinCooldownWindow,

  /// Still inside geofence with recent log.
  duplicateLogWhileStationaryGuard,
}

/// Validates whether a location visit should be logged or skipped.
/// Encapsulates all the duplicate prevention and timing checks.
class LoggingValidator {
  final Set<String> sessionLoggedAddresses;
  final List<JobLog> existingLogs;
  final int outOfGeofenceRetriggerMinutes;
  final int duplicateLogGuardMinutes;

  LoggingValidator({
    required this.sessionLoggedAddresses,
    required this.existingLogs,
    required this.outOfGeofenceRetriggerMinutes,
    required this.duplicateLogGuardMinutes,
  });

  /// Validates whether a site can be logged right now.
  /// Returns the validation result and a human-readable reason.
  (ValidationResult result, String reason) validate(
    JobSite site,
    DateTime now,
    double distanceMeters,
    double effectiveGeofenceRadius,
  ) {
    // Hard guard: session-level duplicate prevention.
    if (sessionLoggedAddresses.contains(site.address)) {
      return (
        ValidationResult.alreadyLoggedThisSession,
        'Already logged for this visit at ${site.address}. '
            'Leave geofence for retrigger timer or use Debug Retrigger.',
      );
    }

    // Find the most recent log for this site.
    final JobLog? latestLog = existingLogs.cast<JobLog?>().firstWhere(
          (JobLog? log) => log?.address == site.address,
          orElse: () => null,
        );

    if (latestLog != null) {
      final double minutesSinceLast =
          now.difference(latestLog.timestamp).inMilliseconds / 60000;

      // Cooldown check: prevent logs within the retrigger window.
      if (minutesSinceLast < outOfGeofenceRetriggerMinutes) {
        return (
          ValidationResult.withinCooldownWindow,
          'Skipped repeat log for ${site.address} '
              '(inside cooldown window of $outOfGeofenceRetriggerMinutes minutes).',
        );
      }

      // Stationary guard: prevent duplicate while still inside geofence.
      final bool stillInside = distanceMeters <= effectiveGeofenceRadius;
      if (stillInside && minutesSinceLast < duplicateLogGuardMinutes) {
        return (
          ValidationResult.duplicateLogWhileStationaryGuard,
          'Skipped duplicate log for ${site.address} '
              '(recent log already recorded; still inside geofence).',
        );
      }
    }

    return (ValidationResult.canLog, '');
  }
}
