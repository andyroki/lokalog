import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/lokalog_models.dart';
import 'location_fix_parser.dart';
import 'location_permission_service.dart';
import 'scenario_dialog_service.dart';
import 'ui_feedback_service.dart';

class TrackingAccessController {
  static Future<bool> ensureTrackingAccess({
    required BuildContext context,
    required MethodChannel channel,
    required Future<void> Function() syncBackgroundGeofences,
    required void Function(String status) setStatus,
    required void Function(bool granted) setBackgroundPermissionGranted,
  }) async {
    if (!Platform.isAndroid) {
      setStatus('Native GPS is implemented for Android in this build.');
      return false;
    }

    final LocationPermissionStatus permissionStatus =
        await LocationPermissionService.getPermissionStatus(channel);
    if (!context.mounted) {
      return false;
    }

    if (!permissionStatus.serviceEnabled) {
      setStatus('Location services are off. Turn on GPS and try again.');
      await _promptAndOpenSettingsIfRequested(
        context,
        title: 'Location Services Off',
        message: 'GPS is turned off. Open Location settings now?',
        openSettings: () => _openLocationSettings(context, channel),
      );
      return false;
    }

    if (!permissionStatus.foregroundPermissionGranted) {
      final bool grantedNow =
          await LocationPermissionService.checkAndRequestPermission(channel);
      if (!context.mounted) {
        return false;
      }
      if (grantedNow) {
        return ensureTrackingAccess(
          context: context,
          channel: channel,
          syncBackgroundGeofences: syncBackgroundGeofences,
          setStatus: setStatus,
          setBackgroundPermissionGranted: setBackgroundPermissionGranted,
        );
      }

      setStatus(
        'Location permission denied. Allow location access to start tracking.',
      );
      await _promptAndOpenSettingsIfRequested(
        context,
        title: 'Location Permission Needed',
        message:
            'Location permission is required. Open app permission settings now?',
        openSettings: () => _openAppSettings(context, channel),
      );
      return false;
    }

    final bool backgroundGranted = permissionStatus.backgroundPermissionGranted;
    setBackgroundPermissionGranted(backgroundGranted);
    if (!backgroundGranted) {
      setStatus(
        'For app-closed geofencing, set Location permission to "Allow all the time" in Android settings.',
      );
      await _promptAndOpenSettingsIfRequested(
        context,
        title: 'Background Location Needed',
        message:
            'To log when the app is closed, set Location to "Allow all the time". Open app settings now?',
        openSettings: () => _openAppSettings(context, channel),
      );
      return false;
    }

    if (!permissionStatus.notificationPermissionGranted) {
      final bool grantedNow =
          await LocationPermissionService.checkAndRequestNotificationPermission(
        channel,
      );
      if (!context.mounted) {
        return false;
      }
      if (grantedNow) {
        return ensureTrackingAccess(
          context: context,
          channel: channel,
          syncBackgroundGeofences: syncBackgroundGeofences,
          setStatus: setStatus,
          setBackgroundPermissionGranted: setBackgroundPermissionGranted,
        );
      }

      setStatus(
        'Notification permission is required for reminder alerts while running in the background.',
      );
      await _promptAndOpenSettingsIfRequested(
        context,
        title: 'Notifications Needed',
        message:
            'Enable notifications so log reminders can show while the app runs in the background. Open app settings now?',
        openSettings: () => _openNotificationSettings(context, channel),
      );
      return false;
    }

    if (!permissionStatus.batteryOptimizationDisabled) {
      setStatus(
        'Disable battery optimization for Lokalog so geofence logging keeps running when the app is closed.',
      );
      await _promptAndOpenSettingsIfRequested(
        context,
        title: 'Background Run Needed',
        message:
            'Set battery to Unrestricted (or disable optimization) for Lokalog to keep background logging active. Open Battery settings now?',
        openSettings: () => _openBatteryOptimizationSettings(context, channel),
      );
      return false;
    }

    await syncBackgroundGeofences();
    return true;
  }

  static Future<LocationFix?> readCurrentLocationForAdd({
    required BuildContext context,
    required MethodChannel channel,
    required Duration timeout,
  }) async {
    if (!Platform.isAndroid) {
      _showInfoSnackBar(
        context,
        'Current GPS lookup is available on Android only.',
      );
      return null;
    }

    final bool serviceEnabled =
        await LocationPermissionService.isLocationServiceEnabled(channel);
    if (!context.mounted) {
      return null;
    }
    if (!serviceEnabled) {
      _showInfoSnackBar(
        context,
        'Location services are off. Turn on GPS and try again.',
      );
      return null;
    }

    final bool granted =
        await LocationPermissionService.checkAndRequestPermission(channel);
    if (!context.mounted) {
      return null;
    }
    if (!granted) {
      _showInfoSnackBar(
        context,
        'Location permission is required to use current GPS.',
      );
      return null;
    }

    try {
      final Map<Object?, Object?>? position = await channel
          .invokeMethod<Map<Object?, Object?>>('getCurrentLocation')
          .timeout(timeout);
      if (!context.mounted) {
        return null;
      }
      final ParsedLocationFix parsedFix = LocationFixParser.parse(position);
      if (!parsedFix.isValid || parsedFix.fix == null) {
        UiFeedbackService.showMessage(
          context,
          parsedFix.errorMessage ?? 'GPS payload is invalid. Please try again.',
        );
        return null;
      }

      return parsedFix.fix;
    } on TimeoutException {
      if (!context.mounted) {
        return null;
      }
      UiFeedbackService.showMessage(
        context,
        'GPS read timed out. Move outdoors and try again.',
      );
      return null;
    } on PlatformException catch (error) {
      if (!context.mounted) {
        return null;
      }
      final bool timedOut = error.code == 'LOCATION_TIMEOUT';
      UiFeedbackService.showMessage(
        context,
        timedOut
            ? 'GPS read timed out. Move outdoors and try again.'
            : 'Could not get current GPS location (${error.code}). Please try again.',
      );
      return null;
    } catch (_) {
      if (!context.mounted) {
        return null;
      }
      UiFeedbackService.showMessage(
        context,
        'Could not get current GPS location. Please try again.',
      );
      return null;
    }
  }

  static Future<void> _promptAndOpenSettingsIfRequested(
    BuildContext context, {
    required String title,
    required String message,
    required Future<void> Function() openSettings,
  }) async {
    final bool shouldOpen = await ScenarioDialogService.showGoToSettingsDialog(
      context,
      title: title,
      message: message,
    );
    if (!context.mounted) {
      return;
    }
    if (shouldOpen) {
      await openSettings();
    }
  }

  static Future<void> _openLocationSettings(
    BuildContext context,
    MethodChannel channel,
  ) async {
    try {
      await LocationPermissionService.openLocationSettings(channel);
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      UiFeedbackService.showMessage(
          context, 'Could not open Location settings.');
    }
  }

  static Future<void> _openAppSettings(
    BuildContext context,
    MethodChannel channel,
  ) async {
    try {
      await LocationPermissionService.openAppSettings(channel);
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      UiFeedbackService.showMessage(context, 'Could not open App settings.');
    }
  }

  static Future<void> _openNotificationSettings(
    BuildContext context,
    MethodChannel channel,
  ) async {
    try {
      final bool opened =
          await LocationPermissionService.openNotificationSettings(channel);
      if (!opened) {
        if (!context.mounted) {
          return;
        }
        UiFeedbackService.showMessage(
          context,
          'Could not open Notification settings directly. Open App settings for Lokalog and enable Notifications.',
        );
      }
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      UiFeedbackService.showMessage(
        context,
        'Could not open Notification settings.',
      );
    }
  }

  static Future<void> _openBatteryOptimizationSettings(
    BuildContext context,
    MethodChannel channel,
  ) async {
    try {
      final bool opened =
          await LocationPermissionService.openBatteryOptimizationSettings(
        channel,
      );
      if (!opened) {
        if (!context.mounted) {
          return;
        }
        UiFeedbackService.showMessage(
          context,
          'Open App info for Lokalog, then Battery > Unrestricted.',
        );
      }
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      UiFeedbackService.showMessage(
          context, 'Could not open Battery optimization settings.');
    }
  }

  static void _showInfoSnackBar(BuildContext context, String message) {
    UiFeedbackService.showMessage(context, message);
  }
}
