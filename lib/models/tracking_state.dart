import 'dart:async';

/// Encapsulates tracking-related state variables.
/// Groups all state related to tracking on/off, timers, and sample counting.
class TrackingState {
  bool isTracking;
  String status;
  int stableSamples;
  Timer? trackingTimer;
  Timer? promptTimer;
  Timer? uiRefreshTimer;
  DateTime? lastFixAt;
  DateTime? trackingRuntimeStateLoadedAt;
  DateTime? trackingRuntimeStateSavedAt;

  TrackingState({
    this.isTracking = false,
    this.status = 'Open Settings to start tracking.',
    this.stableSamples = 0,
    this.trackingTimer,
    this.promptTimer,
    this.uiRefreshTimer,
    this.lastFixAt,
    this.trackingRuntimeStateLoadedAt,
    this.trackingRuntimeStateSavedAt,
  });

  /// Cancel all active timers.
  void cancelAllTimers() {
    trackingTimer?.cancel();
    promptTimer?.cancel();
    uiRefreshTimer?.cancel();
    trackingTimer = null;
    promptTimer = null;
    uiRefreshTimer = null;
  }

  /// Reset tracking state while preserving some runtime information.
  void reset() {
    stableSamples = 0;
    lastFixAt = null;
  }

  /// Reset session-specific state on startup.
  void resetSessionState() {
    stableSamples = 0;
    lastFixAt = null;
  }
}
