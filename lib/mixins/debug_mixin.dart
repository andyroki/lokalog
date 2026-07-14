import 'package:lokalog_app/models/lokalog_models.dart';

/// Mixin that provides debug summary methods.
/// Separates debug/diagnostic output from core state management.
mixin DebugMixin {
  // These getters/methods must be implemented by the consuming class
  bool get debugModeEnabled;
  List<JobSite> get sites;
  List<JobLog> get logs;
  Set<String> get deletedLogKeys;
  Set<String> get sessionLoggedAddresses;
  bool get isTracking;
  bool get trackingPreferenceLoaded;
  bool get trackingRuntimeStateLoaded;
  bool get sitesLoaded;
  bool get autoStartTrackingAttempted;
  bool get trackingOffStartupDialogShown;
  bool get isChangingTrackingState;
  bool get isFetchingCurrentLocation;
  DateTime? get lastFixAt;
  String get status;
  LocationFix? get currentFix;
  SiteDistance? get latestNearest;
  Map<String, double> get timeInGeofenceMinutesBySite;
  Map<String, DateTime> get outOfGeofenceSince;
  int get stableSamples;
  int get requiredStableSamples;
  int get promptCountdown;
  JobSite? get candidateSite;
  JobSite? get pendingSite;
  int get closePollSeconds;
  int get farPollSeconds;
  Map<Object?, Object?>? get lastRawGpsPayload;
  DateTime? get lastRawGpsPayloadAt;
  String? get lastRawGpsReadError;
  DateTime? get trackingRuntimeStateLoadedAt;
  DateTime? get trackingRuntimeStateSavedAt;

  // Helper methods required
  String formatElapsedMinutes(double minutes);
  String formatDebugTimestamp(DateTime value);
  String fmtDist(double meters, {int decimals = 1});
  String fmtAccuracy(double meters);
  double liveTimeInGeofenceMinutes(JobSite site);
  double liveOutOfGeofenceMinutes(JobSite site, DateTime now);
  String siteAddressByName(String siteName);
  List<LocationTrackingState> buildLocationTrackingStates();
  Map<String, double> projectedOutOfGeofenceMinutesBySite();

  String pollingDebugSummary();
  String locationTrackingStatesDebugSummary();
  String rawGpsDebugSummary();
  String trackingRuntimeStateDebugSummary();
  String appReadinessDebugSummary();
  String geofenceDecisionDebugSummary();

  /// Generate complete startup and logging diagnostics summary.
  String startupLoggingDiagnosticsSummary() {
    final DateTime now = DateTime.now();
    final bool startupReady = trackingPreferenceLoaded &&
        trackingRuntimeStateLoaded &&
        sitesLoaded;
    final String lastFixAge = lastFixAt == null
        ? 'n/a'
        : '${now.difference(lastFixAt!).inSeconds}s ago';
    final SiteDistance? nearest = latestNearest;
    final JobSite? nearestSite = nearest?.site;
    final String nearestDistance =
        nearest == null ? 'n/a' : fmtDist(nearest.distanceMeters);

    String nearestBlock = 'Nearest logging diagnostics\nNo nearest site yet.';
    if (nearestSite != null) {
      final String address = nearestSite.address;
      final double baseDwell = timeInGeofenceMinutesBySite[address] ?? 0;
      final double projectedDwell = liveTimeInGeofenceMinutes(nearestSite);
      final double outMinutes = liveOutOfGeofenceMinutes(nearestSite, now);
      final bool logged = sessionLoggedAddresses.contains(address);
      final DateTime? outSince = outOfGeofenceSince[address];

      nearestBlock = 'Nearest logging diagnostics\n'
          'Site: ${nearestSite.name}\n'
          'Address: $address\n'
          'Distance: $nearestDistance\n'
          'Logged this session: $logged\n'
          'Required dwell: ${nearestSite.requiredDwellMinutes}m\n'
          'Base dwell map: ${formatElapsedMinutes(baseDwell)}\n'
          'Projected dwell: ${formatElapsedMinutes(projectedDwell)}\n'
          'Out-of-geofence: ${formatElapsedMinutes(outMinutes)}\n'
          'Out since: ${outSince == null ? 'none' : formatDebugTimestamp(outSince)}';
    }

    return 'Startup and logging gates\n'
        'Startup ready: $startupReady\n'
        'Tracking pref loaded: $trackingPreferenceLoaded\n'
        'Runtime state loaded: $trackingRuntimeStateLoaded\n'
        'Sites loaded: $sitesLoaded\n'
        'Auto-start attempted: $autoStartTrackingAttempted\n'
        'Tracking-off dialog shown: $trackingOffStartupDialogShown\n'
        'Tracking enabled pref: tracking preference pending\n'
        'Tracking active: $isTracking\n'
        'Last fix age: $lastFixAge\n'
        'Current status: $status\n'
        'Candidate site: ${candidateSite?.name ?? 'none'}\n'
        'Pending prompt site: ${pendingSite?.name ?? 'none'}\n'
        'Stable samples: $stableSamples/$requiredStableSamples\n'
        'Prompt countdown: ${promptCountdown}s\n'
        'Close/Far polling sec: $closePollSeconds/$farPollSeconds\n\n'
        '$nearestBlock';
  }

  /// Generate all available debug information as concatenated summaries.
  String getAllDebugInfo() {
    return '''
$pollingDebugSummary()

${locationTrackingStatesDebugSummary()}

${rawGpsDebugSummary()}

${trackingRuntimeStateDebugSummary()}

${appReadinessDebugSummary()}

${geofenceDecisionDebugSummary()}

${startupLoggingDiagnosticsSummary()}
''';
  }
}
