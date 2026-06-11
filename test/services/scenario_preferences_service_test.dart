import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lokalog_app/services/scenario_preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('test/preferences');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'loadPreference') {
        final String key =
            (call.arguments as Map<dynamic, dynamic>)['key'] as String;
        switch (key) {
          case 'dark':
            return 'true';
          case 'font':
            return '9.99';
          case 'close':
            return '60';
          case 'far':
            return '600';
          case 'distance':
            return '5000';
          case 'retrigger':
            return '45';
          case 'hide':
            return 'false';
          case 'invalid_close':
            return '7';
          case 'invalid_far':
            return '123';
          case 'invalid_distance':
            return '-1';
          case 'invalid_retrigger':
            return '999';
          case 'invalid_hide':
            return 'not_false';
          default:
            return null;
        }
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('loadThemePreferences parses dark mode and clamps font scale', () async {
    final ThemePreferences prefs =
        await ScenarioPreferencesService.loadThemePreferences(
      channel,
      darkModeKey: 'dark',
      fontScaleKey: 'font',
      defaultFontScale: 1.0,
      minFontScale: 0.85,
      maxFontScale: 1.35,
    );

    expect(prefs.darkModeEnabled, isTrue);
    expect(prefs.fontScale, 1.35);
  });

  test('loadPollingPreferences uses parsed values when valid', () async {
    final PollingPreferences prefs =
        await ScenarioPreferencesService.loadPollingPreferences(
      channel,
      closePollSecondsKey: 'close',
      farPollSecondsKey: 'far',
      farDistanceMetersKey: 'distance',
      outOfGeofenceRetriggerMinutesKey: 'retrigger',
      hideNearestWhenFarKey: 'hide',
      defaultClosePollSeconds: 30,
      defaultFarPollSeconds: 300,
      defaultFarDistanceMeters: 3000,
      defaultOutOfGeofenceRetriggerMinutes: 20,
      closePollSecondOptions: const <int>[30, 60, 300],
      farPollSecondOptions: const <int>[60, 300, 600],
      farDistanceMeterOptions: const <int>[300, 1000, 3000, 5000],
      outOfGeofenceRetriggerMinuteOptions: const <int>[1, 20, 45, 60],
    );

    expect(prefs.closePollSeconds, 60);
    expect(prefs.farPollSeconds, 600);
    expect(prefs.farDistanceMeters, 5000);
    expect(prefs.outOfGeofenceRetriggerMinutes, 45);
    expect(prefs.hideNearestWhenFar, isFalse);
  });

  test('loadPollingPreferences falls back to defaults for invalid options',
      () async {
    final PollingPreferences prefs =
        await ScenarioPreferencesService.loadPollingPreferences(
      channel,
      closePollSecondsKey: 'invalid_close',
      farPollSecondsKey: 'invalid_far',
      farDistanceMetersKey: 'invalid_distance',
      outOfGeofenceRetriggerMinutesKey: 'invalid_retrigger',
      hideNearestWhenFarKey: 'invalid_hide',
      defaultClosePollSeconds: 30,
      defaultFarPollSeconds: 300,
      defaultFarDistanceMeters: 3000,
      defaultOutOfGeofenceRetriggerMinutes: 20,
      closePollSecondOptions: const <int>[30, 60, 300],
      farPollSecondOptions: const <int>[60, 300, 600],
      farDistanceMeterOptions: const <int>[300, 1000, 3000, 5000],
      outOfGeofenceRetriggerMinuteOptions: const <int>[1, 20, 45, 60],
    );

    expect(prefs.closePollSeconds, 30);
    expect(prefs.farPollSeconds, 300);
    expect(prefs.farDistanceMeters, 3000);
    expect(prefs.outOfGeofenceRetriggerMinutes, 20);
    expect(prefs.hideNearestWhenFar, isTrue);
  });
}
