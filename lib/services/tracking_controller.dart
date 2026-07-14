import '../models/lokalog_models.dart';
import '../constants/app_constants.dart';
import 'location_tracking_calculator.dart';

class TrackingProcessResult {
  TrackingProcessResult({
    required this.currentFix,
    required this.latestNearest,
    required this.candidateSite,
    required this.stableSamples,
    required this.goodAccuracy,
    required this.lowSpeed,
    required this.inGeofence,
    required this.effectiveRadiusMeters,
    required this.shouldPrompt,
    this.promptSite,
  });

  final LocationFix currentFix;
  final SiteDistance? latestNearest;
  final JobSite? candidateSite;
  final int stableSamples;
  final bool goodAccuracy;
  final bool lowSpeed;
  final bool inGeofence;
  final double effectiveRadiusMeters;
  final bool shouldPrompt;
  final JobSite? promptSite;
}

class TrackingController {
  static TrackingProcessResult processFix({
    required LocationFix fix,
    required DateTime now,
    required DateTime? lastFixAt,
    required List<JobSite> sites,
    required Set<String> sessionLoggedAddresses,
    required Map<String, double> timeInGeofenceMinutes,
    required Map<String, DateTime> outOfGeofenceSince,
    required int outOfGeofenceRetriggerMinutes,
    required double matchRadiusMeters,
    required double maxAccuracyMeters,
    required double maxSpeedForDwell,
    required int requiredStableSamples,
    required JobSite? currentCandidateSite,
    required int currentStableSamples,
    required JobSite? pendingSite,
  }) {
    final double elapsedMinutes = lastFixAt == null
        ? 0
        : now.difference(lastFixAt).inMilliseconds / 60000;

    if (sites.isEmpty) {
      return TrackingProcessResult(
        currentFix: fix,
        latestNearest: null,
        candidateSite: null,
        stableSamples: 0,
        goodAccuracy: fix.accuracyMeters <= maxAccuracyMeters,
        lowSpeed: fix.speedMetersPerSecond <= maxSpeedForDwell,
        inGeofence: false,
        effectiveRadiusMeters: matchRadiusMeters,
        shouldPrompt: false,
      );
    }

    final bool goodAccuracy = fix.accuracyMeters <= maxAccuracyMeters;
    final bool lowSpeed = fix.speedMetersPerSecond <= maxSpeedForDwell;
    final bool canUseFixForDwell = goodAccuracy && lowSpeed;
    final double effectiveRadius = _effectiveRadius(
      matchRadiusMeters,
      fix.accuracyMeters,
    );

    JobSite? nearestSite;
    double nearestDistance = double.infinity;
    JobSite? nextCandidateSite;
    double candidateDistance = double.infinity;
    final double increment = elapsedMinutes < 0 ? 0 : elapsedMinutes;

    for (final JobSite site in sites) {
      final double distance = LocationTrackingCalculator.distanceMetersBetween(
        fix.lat,
        fix.lng,
        site.lat,
        site.lng,
      );
      final bool inGeofence = distance <= effectiveRadius;
      final bool isLogged = sessionLoggedAddresses.contains(site.address);
      final double retriggerOutsideRadius =
          effectiveRadius + (fix.accuracyMeters * 0.75 < 25 ? 25 : fix.accuracyMeters * 0.75);
        final double requiredOutsideDistance = retriggerOutsideRadius >
            AppConstants.retriggerMinimumOutsideDistanceMeters
          ? retriggerOutsideRadius
          : AppConstants.retriggerMinimumOutsideDistanceMeters;
      final bool confidentlyOutside =
          distance > requiredOutsideDistance && goodAccuracy;

      if (distance < nearestDistance) {
        nearestSite = site;
        nearestDistance = distance;
      }

      // Only high-quality, low-speed fixes are allowed to advance dwell/candidate state.
      // Low-quality readings are treated as "unknown" so they don't trigger false logs
      // or accidental dwell resets.
      if (inGeofence) {
        if (canUseFixForDwell) {
          timeInGeofenceMinutes[site.address] =
              (timeInGeofenceMinutes[site.address] ?? 0) + increment;
        }
      } else {
        if (goodAccuracy) {
          timeInGeofenceMinutes[site.address] = 0;
        }
      }

      if (isLogged) {
        if (confidentlyOutside) {
          final DateTime outSince =
              outOfGeofenceSince.putIfAbsent(site.address, () => now);
          if (now.difference(outSince).inMinutes >=
              outOfGeofenceRetriggerMinutes) {
            sessionLoggedAddresses.remove(site.address);
            outOfGeofenceSince.remove(site.address);
            timeInGeofenceMinutes[site.address] = 0;
          }
        } else {
          // Only allow retrigger timer to run while we are clearly outside.
          // Borderline/low-confidence readings should not accumulate out time.
          outOfGeofenceSince.remove(site.address);
        }
        continue;
      }

      if (inGeofence && canUseFixForDwell && distance < candidateDistance) {
        nextCandidateSite = site;
        candidateDistance = distance;
      }
    }

    int nextStableSamples;
    if (nextCandidateSite != null) {
      if (currentCandidateSite?.address == nextCandidateSite.address) {
        nextStableSamples = currentStableSamples + 1;
      } else {
        nextStableSamples = 1;
      }
    } else {
      nextStableSamples = 0;
    }

    final SiteDistance nearest = SiteDistance(
      site: nearestSite!,
      distanceMeters: nearestDistance,
    );
    final bool nearestInGeofence = nearestDistance <= effectiveRadius;
    final bool shouldPrompt = nextCandidateSite != null &&
        pendingSite == null &&
        !sessionLoggedAddresses.contains(nextCandidateSite.address) &&
      (timeInGeofenceMinutes[nextCandidateSite.address] ?? 0) >=
            nextCandidateSite.requiredDwellMinutes.toDouble() &&
        nextStableSamples >= requiredStableSamples;

    return TrackingProcessResult(
      currentFix: fix,
      latestNearest: nearest,
      candidateSite: nextCandidateSite,
      stableSamples: nextStableSamples,
      goodAccuracy: goodAccuracy,
      lowSpeed: lowSpeed,
      inGeofence: nearestInGeofence,
      effectiveRadiusMeters: effectiveRadius,
      shouldPrompt: shouldPrompt,
      promptSite: shouldPrompt ? nextCandidateSite : null,
    );
  }

  static double _effectiveRadius(double matchRadiusMeters, double accuracyMeters) {
    return matchRadiusMeters < accuracyMeters + 35
        ? (matchRadiusMeters + 80 < accuracyMeters + 35
            ? matchRadiusMeters + 80
            : accuracyMeters + 35)
        : matchRadiusMeters;
  }
}