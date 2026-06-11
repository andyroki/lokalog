import 'package:flutter/services.dart';

class DebugPreferences {
  DebugPreferences({
    required this.debugModeEnabled,
    required this.showBatteryInfo,
  });

  final bool debugModeEnabled;
  final bool showBatteryInfo;
}

class PollingPreferences {
  PollingPreferences({
    required this.closePollSeconds,
    required this.farPollSeconds,
    required this.farDistanceMeters,
    required this.outOfGeofenceRetriggerMinutes,
    required this.hideNearestWhenFar,
  });

  final int closePollSeconds;
  final int farPollSeconds;
  final int farDistanceMeters;
  final int outOfGeofenceRetriggerMinutes;
  final bool hideNearestWhenFar;
}

class ThemePreferences {
  ThemePreferences({
    required this.darkModeEnabled,
    required this.fontScale,
  });

  final bool darkModeEnabled;
  final double fontScale;
}

class ScenarioPreferencesService {
  static Future<String?> loadStringPreference(
    MethodChannel channel, {
    required String key,
  }) async {
    return channel.invokeMethod<String>(
      'loadPreference',
      <String, dynamic>{'key': key},
    );
  }

  static Future<bool?> loadBoolPreference(
    MethodChannel channel, {
    required String key,
  }) async {
    final String? raw = await loadStringPreference(channel, key: key);
    if (raw == null) {
      return null;
    }
    return raw == 'true';
  }

  static Future<void> saveStringPreference(
    MethodChannel channel, {
    required String key,
    required String value,
  }) async {
    await channel.invokeMethod<void>(
      'savePreference',
      <String, dynamic>{
        'key': key,
        'value': value,
      },
    );
  }

  static Future<void> saveBoolPreference(
    MethodChannel channel, {
    required String key,
    required bool value,
  }) async {
    await saveStringPreference(
      channel,
      key: key,
      value: value.toString(),
    );
  }

  static Future<ThemePreferences> loadThemePreferences(
    MethodChannel channel, {
    required String darkModeKey,
    required String fontScaleKey,
    required double defaultFontScale,
    required double minFontScale,
    required double maxFontScale,
  }) async {
    final bool? darkModeEnabled = await loadBoolPreference(
      channel,
      key: darkModeKey,
    );
    final String? fontRaw =
        await loadStringPreference(channel, key: fontScaleKey);
    final double parsedFontScale =
        double.tryParse(fontRaw ?? '') ?? defaultFontScale;

    return ThemePreferences(
      darkModeEnabled: darkModeEnabled ?? false,
      fontScale: parsedFontScale.clamp(minFontScale, maxFontScale),
    );
  }

  static Future<void> saveFontScalePreference(
    MethodChannel channel, {
    required String key,
    required double value,
  }) async {
    await saveStringPreference(
      channel,
      key: key,
      value: value.toStringAsFixed(2),
    );
  }

  static Future<DebugPreferences> loadDebugPreferences(
    MethodChannel channel, {
    required String debugModeKey,
    required String showBatteryInfoKey,
  }) async {
    final String? debugRaw = await channel.invokeMethod<String>(
      'loadPreference',
      <String, dynamic>{'key': debugModeKey},
    );
    final String? showBatteryRaw = await channel.invokeMethod<String>(
      'loadPreference',
      <String, dynamic>{'key': showBatteryInfoKey},
    );

    return DebugPreferences(
      debugModeEnabled: debugRaw == 'true',
      showBatteryInfo: showBatteryRaw != 'false',
    );
  }

  static Future<PollingPreferences> loadPollingPreferences(
    MethodChannel channel, {
    required String closePollSecondsKey,
    required String farPollSecondsKey,
    required String farDistanceMetersKey,
    required String outOfGeofenceRetriggerMinutesKey,
    required String hideNearestWhenFarKey,
    required int defaultClosePollSeconds,
    required int defaultFarPollSeconds,
    required int defaultFarDistanceMeters,
    required int defaultOutOfGeofenceRetriggerMinutes,
    required List<int> closePollSecondOptions,
    required List<int> farPollSecondOptions,
    required List<int> farDistanceMeterOptions,
    required List<int> outOfGeofenceRetriggerMinuteOptions,
  }) async {
    final String? closeRaw = await channel.invokeMethod<String>(
      'loadPreference',
      <String, dynamic>{'key': closePollSecondsKey},
    );
    final String? farRaw = await channel.invokeMethod<String>(
      'loadPreference',
      <String, dynamic>{'key': farPollSecondsKey},
    );
    final String? distanceRaw = await channel.invokeMethod<String>(
      'loadPreference',
      <String, dynamic>{'key': farDistanceMetersKey},
    );
    final String? retriggerMinutesRaw = await channel.invokeMethod<String>(
      'loadPreference',
      <String, dynamic>{'key': outOfGeofenceRetriggerMinutesKey},
    );
    final String? hideNearestRaw = await channel.invokeMethod<String>(
      'loadPreference',
      <String, dynamic>{'key': hideNearestWhenFarKey},
    );

    final int parsedClose =
        int.tryParse(closeRaw ?? '') ?? defaultClosePollSeconds;
    final int parsedFar = int.tryParse(farRaw ?? '') ?? defaultFarPollSeconds;
    final int parsedDistance =
        int.tryParse(distanceRaw ?? '') ?? defaultFarDistanceMeters;
    final int parsedRetriggerMinutes =
        int.tryParse(retriggerMinutesRaw ?? '') ??
            defaultOutOfGeofenceRetriggerMinutes;

    return PollingPreferences(
      closePollSeconds: closePollSecondOptions.contains(parsedClose)
          ? parsedClose
          : defaultClosePollSeconds,
      farPollSeconds: farPollSecondOptions.contains(parsedFar)
          ? parsedFar
          : defaultFarPollSeconds,
      farDistanceMeters: farDistanceMeterOptions.contains(parsedDistance)
          ? parsedDistance
          : defaultFarDistanceMeters,
      outOfGeofenceRetriggerMinutes:
          outOfGeofenceRetriggerMinuteOptions.contains(parsedRetriggerMinutes)
              ? parsedRetriggerMinutes
              : defaultOutOfGeofenceRetriggerMinutes,
      hideNearestWhenFar: hideNearestRaw != 'false',
    );
  }

  static Future<void> savePollingPreferences(
    MethodChannel channel, {
    required String closePollSecondsKey,
    required int closePollSeconds,
    required String farPollSecondsKey,
    required int farPollSeconds,
    required String farDistanceMetersKey,
    required int farDistanceMeters,
    required String outOfGeofenceRetriggerMinutesKey,
    required int outOfGeofenceRetriggerMinutes,
    required String hideNearestWhenFarKey,
    required bool hideNearestWhenFar,
  }) async {
    await channel.invokeMethod<void>(
      'savePreference',
      <String, dynamic>{
        'key': closePollSecondsKey,
        'value': closePollSeconds.toString(),
      },
    );
    await channel.invokeMethod<void>(
      'savePreference',
      <String, dynamic>{
        'key': farPollSecondsKey,
        'value': farPollSeconds.toString(),
      },
    );
    await channel.invokeMethod<void>(
      'savePreference',
      <String, dynamic>{
        'key': farDistanceMetersKey,
        'value': farDistanceMeters.toString(),
      },
    );
    await channel.invokeMethod<void>(
      'savePreference',
      <String, dynamic>{
        'key': outOfGeofenceRetriggerMinutesKey,
        'value': outOfGeofenceRetriggerMinutes.toString(),
      },
    );
    await channel.invokeMethod<void>(
      'savePreference',
      <String, dynamic>{
        'key': hideNearestWhenFarKey,
        'value': hideNearestWhenFar.toString(),
      },
    );
  }
}
