import 'dart:math';

import '../models/lokalog_models.dart';

class LocationTrackingCalculator {
  static List<LocationTrackingState> buildLocationTrackingStates({
    required List<JobSite> sites,
    required LocationFix? fix,
    required int farDistanceMeters,
    required double matchRadiusMeters,
    required Map<String, double> dwellMinutes,
    required Set<String> sessionLoggedAddresses,
    required JobSite? pendingSite,
    required JobSite? candidateSite,
    required DateTime now,
  }) {
    final List<LocationTrackingState> states = sites.map((JobSite site) {
      final double? distanceMeters = fix == null
          ? null
          : distanceMetersBetween(fix.lat, fix.lng, site.lat, site.lng);

      final bool far =
          distanceMeters == null || distanceMeters > farDistanceMeters;

      final double effectiveRadius = fix == null
          ? matchRadiusMeters
          : _effectiveRadius(matchRadiusMeters, fix.accuracyMeters);
      final bool inGeofence =
          distanceMeters != null && distanceMeters <= effectiveRadius;
      final bool outOfGeofence =
          distanceMeters != null && distanceMeters > effectiveRadius;

      final double dwell = dwellMinutes[site.address] ?? 0;
      final double remaining =
          max(0, site.requiredDwellMinutes.toDouble() - dwell);

      final bool logged = sessionLoggedAddresses.contains(site.address);
      final bool waitingToGetLogged =
          !logged &&
          (pendingSite?.address == site.address ||
              (candidateSite?.address == site.address && dwell > 0));

      return LocationTrackingState(
        name: site.name,
        far: far,
        inGeofence: inGeofence,
        outOfGeofence: outOfGeofence,
        logged: logged,
        waitingToGetLogged: waitingToGetLogged,
        dwellMinutes: dwell,
        remainingMinutes: remaining,
        distanceMeters: distanceMeters,
        lastUpdatedAt: now,
      );
    }).toList();

    states.sort((LocationTrackingState a, LocationTrackingState b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return states;
  }

  static SiteDistance findNearestSite(LocationFix fix, List<JobSite> sites) {
    if (sites.isEmpty) {
      throw StateError('No sites available.');
    }

    JobSite nearest = sites.first;
    double best = distanceMetersBetween(fix.lat, fix.lng, nearest.lat, nearest.lng);
    for (final JobSite site in sites.skip(1)) {
      final double next = distanceMetersBetween(fix.lat, fix.lng, site.lat, site.lng);
      if (next < best) {
        nearest = site;
        best = next;
      }
    }
    return SiteDistance(site: nearest, distanceMeters: best);
  }

  static double minutesRemainingToLog(
    JobSite site,
    Map<String, double> dwellMinutes,
  ) {
    final double dwell = dwellMinutes[site.address] ?? 0;
    return max(0, site.requiredDwellMinutes.toDouble() - dwell);
  }

  static double confidenceScore(LocationFix fix, JobSite site) {
    final double distance = distanceMetersBetween(
      fix.lat,
      fix.lng,
      site.lat,
      site.lng,
    );
    final double accuracyScore = (1 - (fix.accuracyMeters / 60)).clamp(0, 1);
    final double distanceScore = (1 - (distance / 120)).clamp(0, 1);
    final double speedScore = (1 - (fix.speedMetersPerSecond / 3)).clamp(0, 1);
    return ((accuracyScore * 0.4) +
            (distanceScore * 0.4) +
            (speedScore * 0.2)) *
        100;
  }

  static double distanceMetersBetween(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371000;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _effectiveRadius(double matchRadiusMeters, double accuracyMeters) {
    return max(
      matchRadiusMeters,
      min(matchRadiusMeters + 80, accuracyMeters + 35),
    );
  }

  static double _toRadians(double deg) => deg * pi / 180;
}