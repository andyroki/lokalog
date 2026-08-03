import 'package:flutter/services.dart';

class LocationPermissionChannelMethods {
  const LocationPermissionChannelMethods._();

  static const String isLocationServiceEnabled = 'isLocationServiceEnabled';
  static const String hasLocationPermission = 'hasLocationPermission';
  static const String checkAndRequestPermission = 'checkAndRequestPermission';
  static const String hasBackgroundLocationPermission =
      'hasBackgroundLocationPermission';
  static const String syncBackgroundGeofences = 'syncBackgroundGeofences';
  static const String clearBackgroundGeofences = 'clearBackgroundGeofences';
  static const String openLocationSettings = 'openLocationSettings';
  static const String openAppSettings = 'openAppSettings';
  static const String openNotificationSettings = 'openNotificationSettings';
  static const String hasNotificationPermission = 'hasNotificationPermission';
  static const String checkAndRequestNotificationPermission =
      'checkAndRequestNotificationPermission';
  static const String isIgnoringBatteryOptimizations =
      'isIgnoringBatteryOptimizations';
  static const String openBatteryOptimizationSettings =
      'openBatteryOptimizationSettings';
}

class LocationPermissionStatus {
  const LocationPermissionStatus({
    required this.serviceEnabled,
    required this.foregroundPermissionGranted,
    required this.backgroundPermissionGranted,
    required this.notificationPermissionGranted,
    required this.batteryOptimizationDisabled,
  });

  final bool serviceEnabled;
  final bool foregroundPermissionGranted;
  final bool backgroundPermissionGranted;
  final bool notificationPermissionGranted;
  final bool batteryOptimizationDisabled;
}

class LocationPermissionService {
  static Future<LocationPermissionStatus> getPermissionStatus(
    MethodChannel channel,
  ) async {
    final bool serviceEnabled = await isLocationServiceEnabled(channel);
    if (!serviceEnabled) {
      return const LocationPermissionStatus(
        serviceEnabled: false,
        foregroundPermissionGranted: false,
        backgroundPermissionGranted: false,
        notificationPermissionGranted: false,
        batteryOptimizationDisabled: false,
      );
    }

    final bool foregroundPermissionGranted =
        await hasLocationPermission(channel);
    if (!foregroundPermissionGranted) {
      return const LocationPermissionStatus(
        serviceEnabled: true,
        foregroundPermissionGranted: false,
        backgroundPermissionGranted: false,
        notificationPermissionGranted: false,
        batteryOptimizationDisabled: false,
      );
    }

    final bool backgroundPermissionGranted =
        await hasBackgroundLocationPermission(channel);
    final bool notificationPermissionGranted =
        await hasNotificationPermission(channel);
    final bool batteryOptimizationDisabled =
        await isIgnoringBatteryOptimizations(channel);

    return LocationPermissionStatus(
      serviceEnabled: serviceEnabled,
      foregroundPermissionGranted: foregroundPermissionGranted,
      backgroundPermissionGranted: backgroundPermissionGranted,
      notificationPermissionGranted: notificationPermissionGranted,
      batteryOptimizationDisabled: batteryOptimizationDisabled,
    );
  }

  static Future<bool> isLocationServiceEnabled(MethodChannel channel) async {
    return _invokeBool(
      channel,
      LocationPermissionChannelMethods.isLocationServiceEnabled,
    );
  }

  static Future<bool> checkAndRequestPermission(MethodChannel channel) async {
    return _invokeBool(
      channel,
      LocationPermissionChannelMethods.checkAndRequestPermission,
    );
  }

  static Future<bool> hasLocationPermission(MethodChannel channel) async {
    return _invokeBool(
      channel,
      LocationPermissionChannelMethods.hasLocationPermission,
    );
  }

  static Future<bool> hasBackgroundLocationPermission(
    MethodChannel channel,
  ) async {
    return _invokeBool(
      channel,
      LocationPermissionChannelMethods.hasBackgroundLocationPermission,
    );
  }

  static Future<void> syncBackgroundGeofences(MethodChannel channel) async {
    await _invokeVoid(
      channel,
      LocationPermissionChannelMethods.syncBackgroundGeofences,
    );
  }

  static Future<void> clearBackgroundGeofences(MethodChannel channel) async {
    await _invokeVoid(
      channel,
      LocationPermissionChannelMethods.clearBackgroundGeofences,
    );
  }

  static Future<bool> openLocationSettings(MethodChannel channel) async {
    return _invokeBool(
      channel,
      LocationPermissionChannelMethods.openLocationSettings,
    );
  }

  static Future<bool> openAppSettings(MethodChannel channel) async {
    return _invokeBool(
      channel,
      LocationPermissionChannelMethods.openAppSettings,
    );
  }

  static Future<bool> openNotificationSettings(MethodChannel channel) async {
    return _invokeBool(
      channel,
      LocationPermissionChannelMethods.openNotificationSettings,
    );
  }

  static Future<bool> hasNotificationPermission(MethodChannel channel) async {
    return _invokeBool(
      channel,
      LocationPermissionChannelMethods.hasNotificationPermission,
    );
  }

  static Future<bool> checkAndRequestNotificationPermission(
    MethodChannel channel,
  ) async {
    return _invokeBool(
      channel,
      LocationPermissionChannelMethods.checkAndRequestNotificationPermission,
    );
  }

  static Future<bool> isIgnoringBatteryOptimizations(
    MethodChannel channel,
  ) async {
    return _invokeBool(
      channel,
      LocationPermissionChannelMethods.isIgnoringBatteryOptimizations,
    );
  }

  static Future<bool> openBatteryOptimizationSettings(
    MethodChannel channel,
  ) async {
    return _invokeBool(
      channel,
      LocationPermissionChannelMethods.openBatteryOptimizationSettings,
    );
  }

  static Future<bool> _invokeBool(MethodChannel channel, String method) async {
    try {
      return (await channel.invokeMethod<bool>(method)) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> _invokeVoid(MethodChannel channel, String method) async {
    try {
      await channel.invokeMethod<void>(method);
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }
}
