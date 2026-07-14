import 'package:lokalog_app/models/lokalog_models.dart';

/// Manages session-level tracking state: which sites are logged, dwell times, 
/// out-of-geofence timers, and candidate/pending sites.
/// 
/// This centralizes the complex interdependencies between:
/// - _sessionLoggedAddresses: addresses already logged this visit
/// - _outOfGeofenceSince: when each site exited the geofence
/// - _timeInGeofenceMinutesBySite: base dwell accumulated per site
/// - _candidateSite / _pendingSite: geofence entry workflow state
class SessionTrackingState {
  /// Addresses that have been logged during this app session.
  /// Cleared only by out-of-geofence retrigger or explicit Debug Retrigger.
  final Set<String> loggedAddresses = <String>{};

  /// When each site was last confirmed to be outside its geofence.
  /// Used to measure retrigger timer duration.
  final Map<String, DateTime> outOfGeofenceSince = <String, DateTime>{};

  /// Base dwell time (in minutes) accumulated for each address.
  /// Live time = base + elapsed since last GPS poll if still in geofence.
  final Map<String, double> timeInGeofenceMinutes = <String, double>{};

  /// The site that the GPS shows we're closest to and entering.
  /// Becomes the candidate for confirmation if dwell threshold is met.
  JobSite? candidateSite;

  /// The site awaiting user confirmation to log (has met dwell threshold).
  /// Null when no confirmation prompt is showing.
  JobSite? pendingSite;

  /// Countdown timer (seconds) for the pending confirmation prompt.
  /// Auto-confirms to log at 0.
  int promptCountdownSeconds = 0;

  /// Clears all logged addresses, allowing sites to be logged again.
  /// Called when a site exits the geofence beyond the retrigger timer.
  void clearLoggedAddresses() {
    loggedAddresses.clear();
  }

  /// Marks a site as logged for this session.
  void markAsLogged(String address) {
    loggedAddresses.add(address);
  }

  /// Checks if a site has been logged in this session.
  bool isLoggedThisSession(String address) {
    return loggedAddresses.contains(address);
  }

  /// Records when a site exited the geofence.
  /// Used to calculate when the retrigger timer is eligible.
  void recordOutOfGeofence(String address, DateTime when) {
    outOfGeofenceSince[address] = when;
  }

  /// Clears the out-of-geofence timer for a specific site.
  /// Called when a site is re-entered or retrigger happens.
  void clearOutOfGeofenceTimer(String address) {
    outOfGeofenceSince.remove(address);
  }

  /// Updates or initializes the accumulated dwell time for a site.
  void setBaseDwellMinutes(String address, double minutes) {
    timeInGeofenceMinutes[address] = minutes;
  }

  /// Gets the accumulated dwell time for a site.
  double getBaseDwellMinutes(String address) {
    return timeInGeofenceMinutes[address] ?? 0;
  }

  /// Removes all tracking state for sites not in the given address set.
  /// Called when user deletes or loads sites.
  void pruneToKnownSites(Set<String> knownAddresses) {
    loggedAddresses.removeWhere((String addr) => !knownAddresses.contains(addr));
    outOfGeofenceSince.removeWhere(
      (String addr, DateTime _) => !knownAddresses.contains(addr),
    );
    timeInGeofenceMinutes.removeWhere(
      (String addr, double _) => !knownAddresses.contains(addr),
    );
  }

  /// Clears all session state (used when stopping tracking or debugging).
  void reset() {
    loggedAddresses.clear();
    outOfGeofenceSince.clear();
    timeInGeofenceMinutes.clear();
    candidateSite = null;
    pendingSite = null;
    promptCountdownSeconds = 0;
  }

  /// Cancels any pending confirmation prompt.
  void dismissPendingPrompt() {
    pendingSite = null;
    promptCountdownSeconds = 0;
  }
}
