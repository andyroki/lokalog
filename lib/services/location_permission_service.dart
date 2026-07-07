import 'package:flutter/services.dart';

class LocationPermissionChannelMethods {
  const LocationPermissionChannelMethods._();

  static const String isLocationServiceEnabled = 'isLocationServiceEnabled';
  static const String checkAndRequestPermission = 'checkAndRequestPermission';
  static const String hasBackgroundLocationPermission =
      'hasBackgroundLocationPermission';
  static const String syncBackgroundGeofences = 'syncBackgroundGeofences';
  static const String clearBackgroundGeofences = 'clearBackgroundGeofences';
  static const String openLocationSettings = 'openLocationSettings';
  static const String openAppSettings = 'openAppSettings';
  static const String hasNotificationPermission = 'hasNotificationPermission';
  static const String checkAndRequestNotificationPermission =
      'checkAndRequestNotificationPermission';
}

class LocationPermissionStatus {
  const LocationPermissionStatus({
    required this.serviceEnabled,
    required this.foregroundPermissionGranted,
    required this.backgroundPermissionGranted,
    required this.notificationPermissionGranted,
  });

  final bool serviceEnabled;
  final bool foregroundPermissionGranted;
  final bool backgroundPermissionGranted;
  final bool notificationPermissionGranted;
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
      );
    }

    final bool foregroundPermissionGranted =
        await checkAndRequestPermission(channel);
    if (!foregroundPermissionGranted) {
      return const LocationPermissionStatus(
        serviceEnabled: true,
        foregroundPermissionGranted: false,
        backgroundPermissionGranted: false,
        notificationPermissionGranted: false,
      );
    }

    final bool backgroundPermissionGranted =
        await hasBackgroundLocationPermission(channel);
    final bool notificationPermissionGranted =
        await checkAndRequestNotificationPermission(channel);

    return LocationPermissionStatus(
      serviceEnabled: serviceEnabled,
      foregroundPermissionGranted: foregroundPermissionGranted,
      backgroundPermissionGranted: backgroundPermissionGranted,
      notificationPermissionGranted: notificationPermissionGranted,
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
