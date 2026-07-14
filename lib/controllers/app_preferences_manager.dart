import 'package:flutter/services.dart';
import 'package:lokalog_app/constants/app_constants.dart';
import 'package:lokalog_app/services/scenario_preferences_service.dart';

/// Centralized management of all app preferences and settings.
/// Handles loading and saving of user preferences, debug options, and polling settings.
class AppPreferencesManager {
  final MethodChannel _locationChannel;

  // Preference keys
  static const String _debugModeKey = 'pref_debug_mode';
  static const String _showBatteryInfoKey = 'pref_show_battery_info_debug';
  static const String _closePollSecondsKey = 'pref_close_poll_secs';
  static const String _farPollSecondsKey = 'pref_far_poll_secs';
  static const String _farDistanceMetersKey = 'pref_far_distance_meters';
  static const String _inGeofenceDistanceMetersKey = 'pref_in_geofence_distance_meters';
  static const String _hideNearestWhenFarKey = 'pref_hide_nearest_when_far';
  static const String _outOfGeofenceRetriggerMinutesKey =
      'pref_out_of_geofence_retrigger_minutes';
  static const String _useMetricKey = 'pref_use_metric';
  static const String _trackingEnabledKey = 'pref_tracking_enabled';
  static const String _trackingRuntimeStateKey = 'pref_tracking_runtime_state_v1';
  static const String _locationLimitUnlockedKey = 'pref_location_limit_unlocked';

  AppPreferencesManager(this._locationChannel);

  /// Loads debug preferences (debug mode enabled, battery info display).
  Future<DebugPreferences> loadDebugPreferences() async {
    try {
      return await ScenarioPreferencesService.loadDebugPreferences(
        _locationChannel,
        debugModeKey: _debugModeKey,
        showBatteryInfoKey: _showBatteryInfoKey,
      );
    } catch (_) {
      return DebugPreferences(debugModeEnabled: false, showBatteryInfo: true);
    }
  }

  /// Saves battery info display preference.
  Future<void> setShowBatteryInfo(bool enabled) async {
    try {
      await ScenarioPreferencesService.saveBoolPreference(
        _locationChannel,
        key: _showBatteryInfoKey,
        value: enabled,
      );
    } catch (_) {
      // Keep local toggle if persistence fails.
    }
  }

  /// Loads all polling preferences at once.
  Future<PollingPreferences> loadPollingPreferences() async {
    try {
      return await ScenarioPreferencesService.loadPollingPreferences(
        _locationChannel,
        closePollSecondsKey: _closePollSecondsKey,
        farPollSecondsKey: _farPollSecondsKey,
        farDistanceMetersKey: _farDistanceMetersKey,
        inGeofenceDistanceMetersKey: _inGeofenceDistanceMetersKey,
        outOfGeofenceRetriggerMinutesKey: _outOfGeofenceRetriggerMinutesKey,
        hideNearestWhenFarKey: _hideNearestWhenFarKey,
        defaultClosePollSeconds: AppConstants.closePollSeconds,
        defaultFarPollSeconds: AppConstants.farPollSeconds,
        defaultFarDistanceMeters: AppConstants.farDistanceMeters,
        defaultInGeofenceDistanceMeters: AppConstants.inGeofenceDistanceMeters,
        defaultOutOfGeofenceRetriggerMinutes:
            AppConstants.outOfGeofenceRetriggerMinutes,
        closePollSecondOptions: AppConstants.closePollSecondOptions,
        farPollSecondOptions: AppConstants.farPollSecondOptions,
        farDistanceMeterOptions: AppConstants.farDistanceMeterOptions,
        inGeofenceDistanceMeterOptions: AppConstants.inGeofenceDistanceMeterOptions,
        outOfGeofenceRetriggerMinuteOptions:
            AppConstants.outOfGeofenceRetriggerMinuteOptions,
      );
    } catch (_) {
      return PollingPreferences(
        closePollSeconds: AppConstants.closePollSeconds,
        farPollSeconds: AppConstants.farPollSeconds,
        farDistanceMeters: AppConstants.farDistanceMeters,
        inGeofenceDistanceMeters: AppConstants.inGeofenceDistanceMeters,
        outOfGeofenceRetriggerMinutes: AppConstants.outOfGeofenceRetriggerMinutes,
        hideNearestWhenFar: true,
      );
    }
  }

  /// Saves all polling preferences at once.
  Future<void> savePollingPreferences(PollingPreferences prefs) async {
    try {
      await ScenarioPreferencesService.savePollingPreferences(
        _locationChannel,
        closePollSecondsKey: _closePollSecondsKey,
        closePollSeconds: prefs.closePollSeconds,
        farPollSecondsKey: _farPollSecondsKey,
        farPollSeconds: prefs.farPollSeconds,
        farDistanceMetersKey: _farDistanceMetersKey,
        farDistanceMeters: prefs.farDistanceMeters,
        inGeofenceDistanceMetersKey: _inGeofenceDistanceMetersKey,
        inGeofenceDistanceMeters: prefs.inGeofenceDistanceMeters,
        outOfGeofenceRetriggerMinutesKey: _outOfGeofenceRetriggerMinutesKey,
        outOfGeofenceRetriggerMinutes: prefs.outOfGeofenceRetriggerMinutes,
        hideNearestWhenFarKey: _hideNearestWhenFarKey,
        hideNearestWhenFar: prefs.hideNearestWhenFar,
      );
    } catch (_) {
      // Keep active values if persistence fails.
    }
  }

  /// Loads tracking enabled preference.
  Future<bool> loadTrackingEnabled() async {
    try {
      final bool? enabled =
          await ScenarioPreferencesService.loadBoolPreference(
        _locationChannel,
        key: _trackingEnabledKey,
      );
      return enabled ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Saves tracking enabled preference.
  Future<void> saveTrackingEnabled(bool enabled) async {
    try {
      await ScenarioPreferencesService.saveBoolPreference(
        _locationChannel,
        key: _trackingEnabledKey,
        value: enabled,
      );
    } catch (_) {
      // Keep local value if persistence fails.
    }
  }

  /// Loads unit preference (metric vs imperial).
  Future<bool> loadUseMetric() async {
    try {
      final bool? useMetric =
          await ScenarioPreferencesService.loadBoolPreference(
        _locationChannel,
        key: _useMetricKey,
      );
      return useMetric ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Saves unit preference.
  Future<void> saveUseMetric(bool useMetric) async {
    try {
      await ScenarioPreferencesService.saveBoolPreference(
        _locationChannel,
        key: _useMetricKey,
        value: useMetric,
      );
    } catch (_) {
      // Keep local value if persistence fails.
    }
  }

  /// Loads location limit unlock status.
  Future<bool> loadLocationLimitUnlocked() async {
    try {
      final bool? unlocked =
          await ScenarioPreferencesService.loadBoolPreference(
        _locationChannel,
        key: _locationLimitUnlockedKey,
      );
      return unlocked ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Saves location limit unlock status.
  Future<void> saveLocationLimitUnlocked(bool unlocked) async {
    try {
      await ScenarioPreferencesService.saveBoolPreference(
        _locationChannel,
        key: _locationLimitUnlockedKey,
        value: unlocked,
      );
    } catch (_) {
      // Keep local value if persistence fails.
    }
  }

  /// Loads tracking runtime state (geofence times, dwell times, etc).
  Future<Map<String, dynamic>?> loadTrackingRuntimeState() async {
    try {
      final String? raw = await ScenarioPreferencesService.loadStringPreference(
        _locationChannel,
        key: _trackingRuntimeStateKey,
      );
      if (raw == null || raw.trim().isEmpty) {
        return null;
      }
      return _parseJson(raw);
    } catch (_) {
      return null;
    }
  }

  /// Saves tracking runtime state.
  Future<void> saveTrackingRuntimeState(Map<String, dynamic> payload) async {
    try {
      await ScenarioPreferencesService.saveStringPreference(
        _locationChannel,
        key: _trackingRuntimeStateKey,
        value: _encodeJson(payload),
      );
    } catch (_) {
      // Keep runtime behavior if persistence fails.
    }
  }

  Map<String, dynamic>? _parseJson(String raw) {
    try {
      final dynamic decoded = _decodeJson(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  dynamic _decodeJson(String raw) {
    // This will be imported from dart:convert
    throw UnimplementedError('Use jsonDecode from dart:convert');
  }

  String _encodeJson(Map<String, dynamic> data) {
    // This will be imported from dart:convert
    throw UnimplementedError('Use jsonEncode from dart:convert');
  }
}
