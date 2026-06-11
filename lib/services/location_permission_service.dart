import 'package:flutter/services.dart';

class LocationPermissionService {
  static Future<bool> isLocationServiceEnabled(MethodChannel channel) async {
    try {
      return (await channel.invokeMethod<bool>('isLocationServiceEnabled')) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> checkAndRequestPermission(MethodChannel channel) async {
    return (await channel.invokeMethod<bool>('checkAndRequestPermission')) ??
        false;
  }

  static Future<bool> hasBackgroundLocationPermission(
    MethodChannel channel,
  ) async {
    return (await channel
            .invokeMethod<bool>('hasBackgroundLocationPermission')) ??
        false;
  }

  static Future<bool> openLocationSettings(MethodChannel channel) async {
    return (await channel.invokeMethod<bool>('openLocationSettings')) ?? false;
  }

  static Future<bool> openAppSettings(MethodChannel channel) async {
    return (await channel.invokeMethod<bool>('openAppSettings')) ?? false;
  }
}
