import 'package:lokalog_app/models/lokalog_models.dart';

/// Encapsulates current GPS fix and accuracy-related state.
/// Groups GPS data, accuracy, speed, and nearest site information.
class GPSFixState {
  LocationFix? currentFix;
  SiteDistance? latestNearest;
  Map<Object?, Object?>? lastRawGpsPayload;
  DateTime? lastRawGpsPayloadAt;
  String? lastRawGpsReadError;

  GPSFixState({
    this.currentFix,
    this.latestNearest,
    this.lastRawGpsPayload,
    this.lastRawGpsPayloadAt,
    this.lastRawGpsReadError,
  });

  /// Update current fix and clear any previous error.
  void updateFix(LocationFix fix) {
    currentFix = fix;
    lastRawGpsReadError = null;
  }

  /// Record a GPS read error.
  void recordError(String errorMessage) {
    lastRawGpsReadError = errorMessage;
  }

  /// Record raw GPS payload received from platform.
  void recordRawPayload(Map<Object?, Object?>? payload) {
    lastRawGpsPayload = payload == null ? null : Map<Object?, Object?>.from(payload);
    lastRawGpsPayloadAt = DateTime.now();
  }

  /// Clear all GPS-related state.
  void clear() {
    currentFix = null;
    latestNearest = null;
    lastRawGpsPayload = null;
    lastRawGpsPayloadAt = null;
    lastRawGpsReadError = null;
  }

  /// Check if we have a current valid fix.
  bool hasCurrentFix() => currentFix != null;

  /// Get current accuracy if available.
  double? get currentAccuracy => currentFix?.accuracyMeters;

  /// Get current speed if available.
  double? get currentSpeed => currentFix?.speedMetersPerSecond;
}
