import 'package:lokalog_app/models/lokalog_models.dart';

/// Encapsulates geofence and logging state variables.
/// Groups candidate site, pending site, and prompt countdown state.
class GeofenceLocationState {
  JobSite? candidateSite;
  JobSite? pendingSite;
  int promptCountdown;

  GeofenceLocationState({
    this.candidateSite,
    this.pendingSite,
    this.promptCountdown = 0,
  });

  /// Clear all geofence-related state.
  void clear() {
    candidateSite = null;
    pendingSite = null;
    promptCountdown = 0;
  }

  /// Dismiss any pending prompt.
  void dismissPrompt() {
    pendingSite = null;
    promptCountdown = 0;
  }

  /// Set new candidate site.
  void setCandidate(JobSite? site) {
    candidateSite = site;
  }

  /// Set pending site and countdown.
  void setPending(JobSite site, int seconds) {
    pendingSite = site;
    promptCountdown = seconds;
  }

  /// Decrement prompt countdown.
  bool decrementCountdown() {
    if (promptCountdown > 0) {
      promptCountdown--;
      return true;
    }
    return false;
  }

  /// Check if a prompt is active.
  bool hasActivePendingSite() => pendingSite != null && promptCountdown > 0;
}
