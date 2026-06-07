import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const LokaLogApp());
}

class LokaLogApp extends StatefulWidget {
  const LokaLogApp({super.key});

  @override
  State<LokaLogApp> createState() => _LokaLogAppState();
}

class _LokaLogAppState extends State<LokaLogApp> {
  static const MethodChannel _prefChannel = MethodChannel('lokalog/location');
  static const String _darkModePreferenceKey = 'pref_dark_mode';
  static const String _fontScalePreferenceKey = 'pref_font_scale';
  static const double _minFontScale = 0.85;
  static const double _maxFontScale = 1.35;
  static const double _fontScaleStep = 0.1;
  ThemeMode _themeMode = ThemeMode.light;
  double _fontScale = 1.0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDarkMode());
    unawaited(_loadFontScale());
  }

  Future<void> _loadDarkMode() async {
    try {
      final String? value = await _prefChannel.invokeMethod<String>(
        'loadPreference',
        <String, dynamic>{'key': _darkModePreferenceKey},
      );
      if (value == null || !mounted) {
        return;
      }
      setState(() {
        _themeMode = value == 'true' ? ThemeMode.dark : ThemeMode.light;
      });
    } catch (_) {
      // Use default if load fails.
    }
  }

  Future<void> _loadFontScale() async {
    try {
      final String? raw = await _prefChannel.invokeMethod<String>(
        'loadPreference',
        <String, dynamic>{'key': _fontScalePreferenceKey},
      );
      final double parsed = double.tryParse(raw ?? '') ?? 1.0;
      if (!mounted) {
        return;
      }
      setState(() {
        _fontScale = parsed.clamp(_minFontScale, _maxFontScale);
      });
    } catch (_) {
      // Keep default font scale if load fails.
    }
  }

  void _setDarkMode(bool enabled) {
    setState(() {
      _themeMode = enabled ? ThemeMode.dark : ThemeMode.light;
    });
    unawaited(_prefChannel.invokeMethod<void>(
      'savePreference',
      <String, dynamic>{
        'key': _darkModePreferenceKey,
        'value': enabled.toString(),
      },
    ));
  }

  void _setFontScale(double value) {
    final double clamped = value.clamp(_minFontScale, _maxFontScale);
    setState(() {
      _fontScale = clamped;
    });
    unawaited(_prefChannel.invokeMethod<void>(
      'savePreference',
      <String, dynamic>{
        'key': _fontScalePreferenceKey,
        'value': clamped.toStringAsFixed(2),
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lokalog',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.dark,
        ),
      ),
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(_fontScale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      themeMode: _themeMode,
      home: ScenarioPage(
        isDarkMode: _themeMode == ThemeMode.dark,
        onDarkModeChanged: _setDarkMode,
        fontScale: _fontScale,
        minFontScale: _minFontScale,
        maxFontScale: _maxFontScale,
        fontScaleStep: _fontScaleStep,
        onFontScaleChanged: _setFontScale,
      ),
    );
  }
}

class ScenarioPage extends StatefulWidget {
  const ScenarioPage({
    super.key,
    required this.isDarkMode,
    required this.onDarkModeChanged,
    required this.fontScale,
    required this.minFontScale,
    required this.maxFontScale,
    required this.fontScaleStep,
    required this.onFontScaleChanged,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;
  final double fontScale;
  final double minFontScale;
  final double maxFontScale;
  final double fontScaleStep;
  final ValueChanged<double> onFontScaleChanged;

  @override
  State<ScenarioPage> createState() => _ScenarioPageState();
}

class _ScenarioPageState extends State<ScenarioPage> {
  static const MethodChannel _locationChannel =
      MethodChannel('lokalog/location');
  static const String _debugModePreferenceKey = 'pref_debug_mode';
  static const String _showBatteryInfoPreferenceKey =
      'pref_show_battery_info_debug';
  static const String _closePollSecondsPreferenceKey = 'pref_close_poll_secs';
  static const String _farPollSecondsPreferenceKey = 'pref_far_poll_secs';
  static const String _farDistanceMetersPreferenceKey =
      'pref_far_distance_meters';
  static const String _hideNearestWhenFarPreferenceKey =
      'pref_hide_nearest_when_far';
  static const String _outOfGeofenceRetriggerMinutesPreferenceKey =
      'pref_out_of_geofence_retrigger_minutes';
  static const String _useMetricPreferenceKey = 'pref_use_metric';
  static const String _trackingEnabledPreferenceKey = 'pref_tracking_enabled';
  static const List<int> _closePollSecondOptions = <int>[30, 60, 300];
  static const List<int> _farPollSecondOptions = <int>[60, 300, 600];
  static const List<int> _farDistanceMeterOptions = <int>[
    300,
    1000,
    2000,
    3000,
    5000
  ];
  static const List<int> _outOfGeofenceRetriggerMinuteOptions = <int>[
    1,
    20,
    45,
    60
  ];
  static const int _defaultClosePollSeconds = 30;
  static const int _defaultFarPollSeconds = 300;
  static const int _defaultFarDistanceMeters = 3000;
  static const int _defaultOutOfGeofenceRetriggerMinutes = 20;
  static const int _maxSavedLocations = 5;
  static const int _requiredStableSamples = 3;
  static const double _maxAccuracyMeters = 50;
  static const double _maxSpeedForDwell = 1.2;
  static const double _matchRadiusMeters = 100;
  static const List<int> _logMinuteOptions = <int>[
    1,
    5,
    10,
    15,
    20,
    30,
    45,
    60
  ];
  static const String _sitesStorageKey = 'saved_job_sites_v1';
  static const String _deletedLogKeysPreferenceKey =
      'deleted_background_log_keys_v1';

  final List<JobSite> _sites = <JobSite>[];
  final List<JobLog> _logs = <JobLog>[];
  final Set<String> _deletedLogKeys = <String>{};
  final Set<String> _sessionLoggedAddresses = <String>{};
  final Map<String, double> _dwellMinutes = <String, double>{};
  bool _deletedLogKeysLoaded = false;
  bool _autoStartTrackingAttempted = false;
  bool _trackingOffStartupDialogShown = false;
  bool _trackingPreferenceLoaded = false;
  bool _sitesLoaded = false;
  bool _trackingEnabledPreference = true;

  Timer? _trackingTimer;
  Timer? _promptTimer;

  LocationFix? _currentFix;
  String _status = 'Open Settings to start tracking.';
  int _stableSamples = 0;
  bool _isTracking = false;
  int _selectedTabIndex = 0;
  bool _debugModeEnabled = false;
  bool _showBatteryInfo = true;
  int _closePollSeconds = _defaultClosePollSeconds;
  int _farPollSeconds = _defaultFarPollSeconds;
  int _farDistanceMeters = _defaultFarDistanceMeters;
  int _outOfGeofenceRetriggerMinutes =
      _defaultOutOfGeofenceRetriggerMinutes;
  bool _hideNearestWhenFar = true;
  bool _useMetric = true;
  bool _isFetchingCurrentLocation = false;
  DateTime? _lastFixAt;
  SiteDistance? _latestNearest;

  JobSite? _candidateSite;
  JobSite? _pendingSite;
  int _promptCountdown = 0;
  final Map<String, DateTime> _outOfGeofenceSince = <String, DateTime>{};

  bool _isLoadingBatteryUsage = false;
  bool _usageAccessGranted = false;
  String? _batteryUsageError;
  int? _deviceBatteryLevel;
  DateTime? _batteryUsageFetchedAt;
  List<DebugBatteryAppUsage> _batteryUsage = <DebugBatteryAppUsage>[];

  @override
  void initState() {
    super.initState();
    unawaited(_loadDebugMode());
    unawaited(_loadPollingPreferences());
    unawaited(_loadUnitPreference());
    unawaited(_loadTrackingPreference());
    unawaited(_loadSites());
  }

  Future<void> _loadTrackingPreference() async {
    try {
      final String? raw = await _locationChannel.invokeMethod<String>(
        'loadPreference',
        <String, dynamic>{'key': _trackingEnabledPreferenceKey},
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _trackingEnabledPreference = raw != 'false';
        _trackingPreferenceLoaded = true;
      });
    } catch (_) {
      _trackingPreferenceLoaded = true;
    }
    _maybeAutoStartTracking();
  }

  Future<void> _saveTrackingPreference(bool enabled) async {
    _trackingEnabledPreference = enabled;
    try {
      await _locationChannel.invokeMethod<void>(
        'savePreference',
        <String, dynamic>{
          'key': _trackingEnabledPreferenceKey,
          'value': enabled.toString(),
        },
      );
    } catch (_) {
      // Keep local preference value if persistence fails.
    }
  }

  Future<void> _loadDebugMode() async {
    try {
      final String? value = await _locationChannel.invokeMethod<String>(
        'loadPreference',
        <String, dynamic>{'key': _debugModePreferenceKey},
      );
      final String? showBatteryValue =
          await _locationChannel.invokeMethod<String>(
        'loadPreference',
        <String, dynamic>{'key': _showBatteryInfoPreferenceKey},
      );
      if (value == null || !mounted) {
        return;
      }
      setState(() {
        _debugModeEnabled = value == 'true';
        _showBatteryInfo = showBatteryValue != 'false';
      });
    } catch (_) {
      // Keep default if load fails.
    }
  }

  Future<void> _setShowBatteryInfo(bool enabled) async {
    setState(() {
      _showBatteryInfo = enabled;
    });
    try {
      await _locationChannel.invokeMethod<void>(
        'savePreference',
        <String, dynamic>{
          'key': _showBatteryInfoPreferenceKey,
          'value': enabled.toString(),
        },
      );
    } catch (_) {
      // Keep local toggle behavior even if persistence fails.
    }

    if (enabled &&
        _batteryUsage.isEmpty &&
        !_isLoadingBatteryUsage &&
        _debugModeEnabled) {
      unawaited(_loadBatteryUsage());
    }
  }

  Future<void> _loadPollingPreferences() async {
    try {
      final String? closeRaw = await _locationChannel.invokeMethod<String>(
        'loadPreference',
        <String, dynamic>{'key': _closePollSecondsPreferenceKey},
      );
      final String? farRaw = await _locationChannel.invokeMethod<String>(
        'loadPreference',
        <String, dynamic>{'key': _farPollSecondsPreferenceKey},
      );
      final String? distanceRaw = await _locationChannel.invokeMethod<String>(
        'loadPreference',
        <String, dynamic>{'key': _farDistanceMetersPreferenceKey},
      );
      final String? retriggerMinutesRaw =
          await _locationChannel.invokeMethod<String>(
        'loadPreference',
        <String, dynamic>{
          'key': _outOfGeofenceRetriggerMinutesPreferenceKey,
        },
      );
      final String? hideNearestRaw =
          await _locationChannel.invokeMethod<String>(
        'loadPreference',
        <String, dynamic>{'key': _hideNearestWhenFarPreferenceKey},
      );

      final int parsedClose = int.tryParse(closeRaw ?? '') ??
          _defaultClosePollSeconds;
      final int parsedFar =
          int.tryParse(farRaw ?? '') ?? _defaultFarPollSeconds;
      final int parsedDistance = int.tryParse(distanceRaw ?? '') ??
          _defaultFarDistanceMeters;
        final int parsedRetriggerMinutes =
          int.tryParse(retriggerMinutesRaw ?? '') ??
            _defaultOutOfGeofenceRetriggerMinutes;

      if (!mounted) {
        return;
      }

      setState(() {
        _closePollSeconds = _closePollSecondOptions.contains(parsedClose)
            ? parsedClose
            : _defaultClosePollSeconds;
        _farPollSeconds = _farPollSecondOptions.contains(parsedFar)
            ? parsedFar
            : _defaultFarPollSeconds;
        _farDistanceMeters = _farDistanceMeterOptions.contains(parsedDistance)
            ? parsedDistance
            : _defaultFarDistanceMeters;
        _outOfGeofenceRetriggerMinutes =
          _outOfGeofenceRetriggerMinuteOptions
              .contains(parsedRetriggerMinutes)
            ? parsedRetriggerMinutes
            : _defaultOutOfGeofenceRetriggerMinutes;
        _hideNearestWhenFar = hideNearestRaw != 'false';
      });
    } catch (_) {
      // Keep defaults if preference load fails.
    }
  }

  Future<void> _savePollingPreferences() async {
    try {
      await _locationChannel.invokeMethod<void>(
        'savePreference',
        <String, dynamic>{
          'key': _closePollSecondsPreferenceKey,
          'value': _closePollSeconds.toString(),
        },
      );
      await _locationChannel.invokeMethod<void>(
        'savePreference',
        <String, dynamic>{
          'key': _farPollSecondsPreferenceKey,
          'value': _farPollSeconds.toString(),
        },
      );
      await _locationChannel.invokeMethod<void>(
        'savePreference',
        <String, dynamic>{
          'key': _farDistanceMetersPreferenceKey,
          'value': _farDistanceMeters.toString(),
        },
      );
      await _locationChannel.invokeMethod<void>(
        'savePreference',
        <String, dynamic>{
          'key': _outOfGeofenceRetriggerMinutesPreferenceKey,
          'value': _outOfGeofenceRetriggerMinutes.toString(),
        },
      );
      await _locationChannel.invokeMethod<void>(
        'savePreference',
        <String, dynamic>{
          'key': _hideNearestWhenFarPreferenceKey,
          'value': _hideNearestWhenFar.toString(),
        },
      );
    } catch (_) {
      // Keep active runtime values even if persistence fails.
    }
  }

  Future<void> _loadUnitPreference() async {
    try {
      final String? raw = await _locationChannel.invokeMethod<String>(
        'loadPreference',
        <String, dynamic>{'key': _useMetricPreferenceKey},
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _useMetric = raw != 'false';
      });
    } catch (_) {
      // Keep default (metric) if load fails.
    }
  }

  Future<void> _saveUnitPreference() async {
    try {
      await _locationChannel.invokeMethod<void>(
        'savePreference',
        <String, dynamic>{
          'key': _useMetricPreferenceKey,
          'value': _useMetric.toString(),
        },
      );
    } catch (_) {
      // Keep local value even if persistence fails.
    }
  }

  /// Format a metre value for display using current unit setting.
  String _fmtDist(double meters, {int decimals = 1}) {
    if (_useMetric) {
      return '${meters.toStringAsFixed(decimals)} m';
    }
    final double feet = meters * 3.28084;
    if (feet >= 5280) {
      final double miles = feet / 5280;
      return '${miles.toStringAsFixed(2)} mi';
    }
    return '${feet.toStringAsFixed(decimals)} ft';
  }

  /// Format an integer metre value for dropdowns.
  String _fmtDistInt(int meters) {
    if (_useMetric) {
      return '$meters m';
    }
    final double feet = meters * 3.28084;
    if (feet >= 5280) {
      final double miles = feet / 5280;
      return '${miles.toStringAsFixed(2)} mi';
    }
    return '${feet.toStringAsFixed(0)} ft';
  }

  /// Format a speed value (m/s) for display using current unit setting.
  String _fmtSpeed(double metersPerSecond) {
    if (_useMetric) {
      return '${metersPerSecond.toStringAsFixed(1)} m/s';
    }
    final double mph = metersPerSecond * 2.23694;
    return '${mph.toStringAsFixed(1)} mph';
  }

  /// Format an accuracy value (metres) for display.
  String _fmtAccuracy(double meters) => _fmtDist(meters);

  String _formatSecondsOption(int seconds) {
    if (seconds >= 60) {
      final int minutes = (seconds / 60).round();
      return '$minutes min';
    }
    return '${seconds}s';
  }

  String _formatMetersOption(int meters) => _fmtDistInt(meters);

  int _activePollSeconds() {
    if (_currentFix == null || _sites.isEmpty) {
      return _closePollSeconds;
    }
    final SiteDistance nearest = _findNearestSite(_currentFix!, _sites);
    if (nearest.distanceMeters > _farDistanceMeters) {
      return _farPollSeconds;
    }
    return _closePollSeconds;
  }

  String _pollingModeSummary() {
    if (_currentFix == null || _sites.isEmpty) {
      return 'close';
    }
    final SiteDistance nearest = _findNearestSite(_currentFix!, _sites);
    return nearest.distanceMeters > _farDistanceMeters ? 'far' : 'close';
  }

  bool _shouldHideNearestInfo(SiteDistance nearest) {
    return _hideNearestWhenFar && nearest.distanceMeters > _farDistanceMeters;
  }

  Future<void> _pollAndReschedule() async {
    if (!_isTracking) {
      return;
    }
    await _pollCurrentLocation();
    if (!_isTracking) {
      return;
    }
    _scheduleNextPoll();
  }

  void _scheduleNextPoll({bool immediate = false}) {
    if (!_isTracking) {
      return;
    }
    _trackingTimer?.cancel();
    if (immediate) {
      unawaited(_pollAndReschedule());
      return;
    }
    _trackingTimer = Timer(
      Duration(seconds: _activePollSeconds()),
      () => unawaited(_pollAndReschedule()),
    );
  }

  List<JobSite> _defaultSites() {
    return <JobSite>[
      JobSite(
        name: 'Green Valley HOA',
        street: '921 Green Lawn Dr',
        city: 'Dallas',
        state: 'TX',
        zip: '75201',
        lat: 32.77924,
        lng: -96.80011,
        requiredDwellMinutes: 20,
      ),
      JobSite(
        name: 'Oak Family Home',
        street: '413 Oak Ridge Ave',
        city: 'Dallas',
        state: 'TX',
        zip: '75202',
        lat: 32.78163,
        lng: -96.79741,
        requiredDwellMinutes: 15,
      ),
      JobSite(
        name: 'Maple Corner Lot',
        street: '777 Maple Ct',
        city: 'Dallas',
        state: 'TX',
        zip: '75203',
        lat: 32.78402,
        lng: -96.79462,
        requiredDwellMinutes: 30,
      ),
    ];
  }

  Future<void> _loadSites() async {
    try {
      final String? raw =
          await _locationChannel.invokeMethod<String>('loadSites');

      if (raw == null || raw.trim().isEmpty) {
        final List<JobSite> defaults = _defaultSites();
        if (!mounted) {
          return;
        }
        setState(() {
          _sites
            ..clear()
            ..addAll(defaults);
          _sitesLoaded = true;
        });
        await _loadBackgroundLogs();
        await _saveSites();
        _maybeAutoStartTracking();
        return;
      }

      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        if (!mounted) {
          return;
        }
        setState(() {
          _sites
            ..clear()
            ..addAll(_defaultSites());
          _sitesLoaded = true;
        });
        await _loadBackgroundLogs();
        _maybeAutoStartTracking();
        return;
      }

      final List<JobSite> loaded = decoded
          .whereType<Map<String, dynamic>>()
          .map(JobSite.fromJson)
          .toList();

      if (!mounted) {
        return;
      }
      if (loaded.isEmpty) {
        setState(() {
          _sites
            ..clear()
            ..addAll(_defaultSites());
          _sitesLoaded = true;
        });
      } else {
        setState(() {
          _sites
            ..clear()
            ..addAll(loaded);
          _sitesLoaded = true;
        });
      }
      await _loadBackgroundLogs();
      _maybeAutoStartTracking();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sites
          ..clear()
          ..addAll(_defaultSites());
        _sitesLoaded = true;
      });
      await _loadBackgroundLogs();
      _maybeAutoStartTracking();
    }
  }

  void _maybeAutoStartTracking() {
    if (_autoStartTrackingAttempted ||
        !mounted ||
        !_trackingPreferenceLoaded ||
        !_sitesLoaded) {
      return;
    }
    _autoStartTrackingAttempted = true;
    unawaited(_attemptAutoStartTracking());
  }

  Future<void> _attemptAutoStartTracking() async {
    if (_trackingEnabledPreference) {
      await _startScenario();
    }
    if (!mounted || _isTracking || _trackingOffStartupDialogShown) {
      return;
    }
    _trackingOffStartupDialogShown = true;
    await _showTrackingOffStartupDialog();
  }

  Future<void> _showTrackingOffStartupDialog() async {
    final bool? openSettings = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Tracking Is Off'),
          content: const Text(
            'Tracking is currently off.\n\n'
            'To turn it on:\n'
            '1. Open the Settings tab.\n'
            '2. In Tracking Controls, switch Tracking On.\n'
            '3. Allow location permissions and location services if prompted.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );

    if (openSettings == true && mounted) {
      setState(() {
        _selectedTabIndex = 2;
      });
    }
  }

  Future<void> _loadBatteryUsage() async {
    if (!Platform.isAndroid) {
      if (!mounted) {
        return;
      }
      setState(() {
        _batteryUsageError =
            'Battery usage by app is currently available on Android only.';
      });
      return;
    }

    setState(() {
      _isLoadingBatteryUsage = true;
      _batteryUsageError = null;
    });

    try {
      final bool hasUsageAccess = (await _locationChannel
              .invokeMethod<bool>('hasUsageAccessPermission')) ??
          false;

      if (!hasUsageAccess) {
        if (!mounted) {
          return;
        }
        setState(() {
          _usageAccessGranted = false;
          _batteryUsage = <DebugBatteryAppUsage>[];
          _batteryUsageError =
              'Usage access is required. Open Settings and allow Usage Access for this app.';
        });
        return;
      }

      final Map<Object?, Object?>? payload = await _locationChannel
          .invokeMethod<Map<Object?, Object?>>('getAppBatteryUsage');

      if (!mounted) {
        return;
      }

      final List<dynamic> rawApps =
          (payload?['apps'] as List<dynamic>?) ?? <dynamic>[];
      final List<DebugBatteryAppUsage> parsed = rawApps
          .whereType<Map<Object?, Object?>>()
          .map((Map<Object?, Object?> item) {
            return DebugBatteryAppUsage(
              packageName: (item['packageName'] ?? '').toString(),
              appName: (item['appName'] ?? '').toString(),
              foregroundMinutes:
                  ((item['foregroundMinutes'] as num?)?.toDouble() ?? 0),
              estimatedBatterySharePercent:
                  ((item['estimatedBatterySharePercent'] as num?)?.toDouble() ??
                      0),
            );
          })
          .where((DebugBatteryAppUsage item) => item.foregroundMinutes > 0)
          .toList();

      setState(() {
        _usageAccessGranted = true;
        _batteryUsage = parsed;
        _deviceBatteryLevel = (payload?['deviceBatteryLevel'] as num?)?.toInt();
        final int generatedAtEpochMs =
            (payload?['generatedAtEpochMs'] as num?)?.toInt() ??
                DateTime.now().millisecondsSinceEpoch;
        _batteryUsageFetchedAt =
            DateTime.fromMillisecondsSinceEpoch(generatedAtEpochMs);
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _batteryUsageError =
            error.message ?? 'Could not load app battery usage.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _batteryUsageError = 'Could not load app battery usage.';
      });
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingBatteryUsage = false;
      });
    }
  }

  Future<void> _openUsageAccessSettings() async {
    try {
      final bool opened = await _locationChannel
              .invokeMethod<bool>('openUsageAccessSettings') ??
          false;
      if (opened) {
        return;
      }
      await _locationChannel.invokeMethod<bool>('openAppSettings');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Usage Access settings unavailable on this device. Opened app settings instead.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open settings automatically. Please open Usage Access manually in Android settings.',
          ),
        ),
      );
    }
  }

  Future<void> _loadBackgroundLogs() async {
    try {
      await _ensureDeletedLogKeysLoaded();

      final String? raw =
          await _locationChannel.invokeMethod<String>('loadBackgroundLogs');
      if (raw == null || raw.trim().isEmpty) {
        return;
      }

      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        return;
      }

      final List<JobLog> loadedLogs = decoded
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> item) {
        final int timestampMillis =
            ((item['timestamp'] as num?)?.toInt() ??
                DateTime.now().millisecondsSinceEpoch);
        return JobLog(
          name: (item['name'] ?? item['siteName'] ?? item['address'] ?? '')
            .toString(),
          address: (item['address'] ?? '').toString(),
          lat: ((item['lat'] as num?)?.toDouble() ?? 0),
          lng: ((item['lng'] as num?)?.toDouble() ?? 0),
          confidence: ((item['confidence'] as num?)?.toDouble() ?? 100),
          confirmedByUser: (item['confirmedByUser'] as bool?) ?? false,
          autoLogged: (item['autoLogged'] as bool?) ?? true,
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            timestampMillis,
          ),
        );
      }).where((JobLog log) {
        final String key = _logStorageKey(
          address: log.address,
          timestampMillis: log.timestamp.millisecondsSinceEpoch,
        );
        return !_deletedLogKeys.contains(key);
      }).toList();

      if (!mounted || loadedLogs.isEmpty) {
        return;
      }

      final Set<String> existing = _logs
          .map((JobLog log) =>
              '${log.address}|${log.timestamp.millisecondsSinceEpoch}')
          .toSet();

      setState(() {
        for (final JobLog log in loadedLogs) {
          final String key =
              '${log.address}|${log.timestamp.millisecondsSinceEpoch}';
          if (existing.add(key)) {
            _logs.insert(0, log);
          }
        }
      });
    } catch (_) {
      // Ignore background log load errors; they are not fatal.
    }
  }

  String _logStorageKey({
    required String address,
    required int timestampMillis,
  }) {
    return '$address|$timestampMillis';
  }

  Future<void> _ensureDeletedLogKeysLoaded() async {
    if (_deletedLogKeysLoaded) {
      return;
    }

    try {
      final String? raw = await _locationChannel.invokeMethod<String>(
        'loadPreference',
        <String, dynamic>{'key': _deletedLogKeysPreferenceKey},
      );

      if (raw != null && raw.trim().isNotEmpty) {
        final dynamic decoded = jsonDecode(raw);
        if (decoded is List<dynamic>) {
          _deletedLogKeys
            ..clear()
            ..addAll(decoded.whereType<String>());
        }
      }
    } catch (_) {
      // Keep best-effort behavior if preference storage is unavailable.
    }

    _deletedLogKeysLoaded = true;
  }

  Future<void> _saveDeletedLogKeys() async {
    try {
      await _locationChannel.invokeMethod<void>(
        'savePreference',
        <String, dynamic>{
          'key': _deletedLogKeysPreferenceKey,
          'value': jsonEncode(_deletedLogKeys.toList()),
        },
      );
    } catch (_) {
      // Keep local behavior if preference storage is unavailable.
    }
  }

  Future<void> _saveSites() async {
    final String encoded = jsonEncode(
      _sites.map((JobSite site) => site.toJson()).toList(),
    );
    await _locationChannel.invokeMethod<void>('saveSites', <String, dynamic>{
      'key': _sitesStorageKey,
      'value': encoded,
    });
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    _promptTimer?.cancel();
    super.dispose();
  }

  Future<void> _startScenario() async {
    if (_sites.isEmpty) {
      setState(() {
        _status = 'No locations found. Add locations from the Locations tab.';
      });
      return;
    }

    final bool hasLocationAccess = await _ensureLocationAccess();
    if (!hasLocationAccess || !mounted) {
      return;
    }

    _sessionLoggedAddresses.clear();
    _dwellMinutes.clear();
    _outOfGeofenceSince.clear();
    _stableSamples = 0;
    _candidateSite = null;
    _pendingSite = null;
    _latestNearest = null;
    _promptCountdown = 0;
    _lastFixAt = null;
    _promptTimer?.cancel();
    _isTracking = true;
    _status = 'Tracking started. Reading live GPS signal...';

    _scheduleNextPoll(immediate: true);
    setState(() {});
  }

  Future<bool> _confirmStopTracking() async {
    if (!mounted) {
      return false;
    }
    final bool? shouldStop = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Stop Tracking?'),
          content: const Text('Are you sure you want to turn tracking off?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Turn Off'),
            ),
          ],
        );
      },
    );
    return shouldStop == true;
  }

  Future<void> _onTrackingToggleChanged(bool enabled) async {
    if (enabled) {
      await _saveTrackingPreference(true);
      await _startScenario();
      return;
    }

    if (!_isTracking) {
      await _saveTrackingPreference(false);
      return;
    }

    final bool shouldStop = await _confirmStopTracking();
    if (shouldStop) {
      _stopScenario();
      await _saveTrackingPreference(false);
    }
  }

  Future<bool> _ensureLocationAccess() async {
    if (!Platform.isAndroid) {
      setState(() {
        _status = 'Native GPS is implemented for Android in this build.';
      });
      return false;
    }

    bool serviceEnabled = false;
    try {
      serviceEnabled = (await _locationChannel
              .invokeMethod<bool>('isLocationServiceEnabled')) ??
          false;
    } on PlatformException {
      serviceEnabled = false;
    }

    if (!serviceEnabled) {
      setState(() {
        _status = 'Location services are off. Turn on GPS and try again.';
      });
      await _showGoToSettingsDialog(
        title: 'Location Services Off',
        message: 'GPS is turned off. Open Location settings now?',
        openLocationSettings: true,
      );
      return false;
    }

    final bool granted = (await _locationChannel
            .invokeMethod<bool>('checkAndRequestPermission')) ??
        false;
    if (!granted) {
      setState(() {
        _status =
            'Location permission denied. Allow location access to start tracking.';
      });
      await _showGoToSettingsDialog(
        title: 'Location Permission Needed',
        message:
            'Location permission is required. Open app permission settings now?',
        openLocationSettings: false,
      );
      return false;
    }

    final bool backgroundGranted = (await _locationChannel
            .invokeMethod<bool>('hasBackgroundLocationPermission')) ??
        false;
    if (!backgroundGranted) {
      setState(() {
        _status =
            'For app-closed geofencing, set Location permission to "Allow all the time" in Android settings.';
      });
      await _showGoToSettingsDialog(
        title: 'Background Location Needed',
        message:
            'To log when the app is closed, set Location to "Allow all the time". Open app settings now?',
        openLocationSettings: false,
      );
      return false;
    }

    return true;
  }

  Future<void> _openLocationSettings() async {
    try {
      await _locationChannel.invokeMethod<bool>('openLocationSettings');
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Location settings.')),
      );
    }
  }

  Future<void> _openAppSettings() async {
    try {
      await _locationChannel.invokeMethod<bool>('openAppSettings');
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open App settings.')),
      );
    }
  }

  Future<void> _showGoToSettingsDialog({
    required String title,
    required String message,
    required bool openLocationSettings,
  }) async {
    if (!mounted) {
      return;
    }

    final bool? shouldOpen = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );

    if (shouldOpen != true) {
      return;
    }

    if (openLocationSettings) {
      await _openLocationSettings();
    } else {
      await _openAppSettings();
    }
  }

  Future<void> _pollCurrentLocation() async {
    if (!_isTracking) {
      return;
    }

    try {
      final Map<Object?, Object?>? position = await _locationChannel
          .invokeMethod<Map<Object?, Object?>>(
            'getCurrentLocation',
          )
          .timeout(const Duration(seconds: 12));

      if (!_isTracking || !mounted) {
        return;
      }

      final double? lat = (position?['latitude'] as num?)?.toDouble();
      final double? lng = (position?['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) {
        return;
      }

      final LocationFix fix = LocationFix(
        lat: lat,
        lng: lng,
        accuracyMeters: ((position?['accuracy'] as num?)?.toDouble() ?? 999),
        speedMetersPerSecond: max(
          0,
          ((position?['speed'] as num?)?.toDouble() ?? 0),
        ),
      );
      _processFix(fix);
    } catch (_) {
      if (!mounted || !_isTracking) {
        return;
      }
      setState(() {
        _status = 'Unable to read GPS signal. Move outdoors and try again.';
      });
    }
  }

  void _stopScenario() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
    _promptTimer?.cancel();
    unawaited(_cancelLogReminderNotification());
    setState(() {
      _isTracking = false;
      _pendingSite = null;
      _promptCountdown = 0;
      _status = 'Tracking stopped.';
    });
  }

  void _refreshNearestUiFromCurrentFix() {
    final LocationFix? fix = _currentFix;
    if (!mounted || fix == null || _sites.isEmpty) {
      return;
    }

    final SiteDistance nearest = _findNearestSite(fix, _sites);
    final bool goodAccuracy = fix.accuracyMeters <= _maxAccuracyMeters;
    final bool lowSpeed = fix.speedMetersPerSecond <= _maxSpeedForDwell;
    final double effectiveRadius = max(
      _matchRadiusMeters,
      min(_matchRadiusMeters + 80, fix.accuracyMeters + 35),
    );
    final bool inGeofence = nearest.distanceMeters <= effectiveRadius;

    setState(() {
      _latestNearest = nearest;
      _status = _buildStatusText(
        nearest: nearest,
        goodAccuracy: goodAccuracy,
        lowSpeed: lowSpeed,
        inGeofence: inGeofence,
        effectiveRadius: effectiveRadius,
        hideNearestDetails: _shouldHideNearestInfo(nearest),
      );
    });
  }

  void _processFix(LocationFix fix) {
    final DateTime now = DateTime.now();
    final double elapsedMinutes;
    if (_lastFixAt == null) {
      elapsedMinutes = 0;
    } else {
      elapsedMinutes = now.difference(_lastFixAt!).inMilliseconds / 60000;
    }
    _lastFixAt = now;

    _currentFix = fix;
    if (_sites.isEmpty) {
      return;
    }

    final SiteDistance nearest = _findNearestSite(fix, _sites);
    final bool goodAccuracy = fix.accuracyMeters <= _maxAccuracyMeters;
    final bool lowSpeed = fix.speedMetersPerSecond <= _maxSpeedForDwell;
    final double effectiveRadius = max(
      _matchRadiusMeters,
      min(_matchRadiusMeters + 80, fix.accuracyMeters + 35),
    );
    final bool inGeofence = nearest.distanceMeters <= effectiveRadius;

    // Track how long previously-logged sites have stayed outside geofence.
    for (final String address in _sessionLoggedAddresses.toList()) {
      JobSite? loggedSite;
      for (final JobSite site in _sites) {
        if (site.address == address) {
          loggedSite = site;
          break;
        }
      }
      if (loggedSite == null) {
        continue;
      }

      final double distanceToLoggedSite = _distanceMeters(
        fix.lat,
        fix.lng,
        loggedSite.lat,
        loggedSite.lng,
      );
      final bool outsideLoggedSite = distanceToLoggedSite > effectiveRadius;

      if (outsideLoggedSite) {
        _outOfGeofenceSince.putIfAbsent(address, () => now);
      } else {
        _outOfGeofenceSince.remove(address);
      }
    }

    if (inGeofence) {
      _stableSamples += 1;
      _candidateSite = nearest.site;
      final double increment = elapsedMinutes.clamp(0, 3);
      _dwellMinutes[nearest.site.address] =
          (_dwellMinutes[nearest.site.address] ?? 0) + increment;
    } else {
      _stableSamples = 0;
      _candidateSite = null;
    }

    if (_candidateSite != null && _pendingSite == null) {
      final double dwell = _dwellMinutes[_candidateSite!.address] ?? 0;
      bool alreadyLogged =
          _sessionLoggedAddresses.contains(_candidateSite!.address);

      if (alreadyLogged) {
        final DateTime? outSince =
            _outOfGeofenceSince[_candidateSite!.address];
        if (outSince != null) {
          final int outsideMinutes =
              now.difference(outSince).inMinutes;
          if (outsideMinutes >= _outOfGeofenceRetriggerMinutes) {
            _sessionLoggedAddresses.remove(_candidateSite!.address);
            _outOfGeofenceSince.remove(_candidateSite!.address);
            alreadyLogged = false;
          }
        }
      }

      if (!alreadyLogged &&
          dwell >= _candidateSite!.requiredDwellMinutes.toDouble() &&
          _stableSamples >= _requiredStableSamples) {
        _showConfirmationPrompt(_candidateSite!);
      }
    }

    setState(() {
      _latestNearest = nearest;
      _status = _buildStatusText(
        nearest: nearest,
        goodAccuracy: goodAccuracy,
        lowSpeed: lowSpeed,
        inGeofence: inGeofence,
        effectiveRadius: effectiveRadius,
        hideNearestDetails: _shouldHideNearestInfo(nearest),
      );
    });
  }

  double _minutesRemainingToLog(JobSite site) {
    final double dwell = _dwellMinutes[site.address] ?? 0;
    return max(0, site.requiredDwellMinutes.toDouble() - dwell);
  }

  void _showConfirmationPrompt(JobSite site) {
    _pendingSite = site;
    _promptCountdown = 12;
    _promptTimer?.cancel();
    unawaited(_showLogReminderNotification(site, _promptCountdown));
    _promptTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (_pendingSite == null) {
        timer.cancel();
        return;
      }
      if (_promptCountdown <= 1) {
        _logJob(site, confirmedByUser: false, autoLogged: true);
        timer.cancel();
      } else {
        _promptCountdown -= 1;
      }
    });
  }

  void _logJob(
    JobSite site, {
    required bool confirmedByUser,
    required bool autoLogged,
  }) {
    final LocationFix? fix = _currentFix;
    if (fix == null) {
      return;
    }

    _logs.insert(
      0,
      JobLog(
        name: site.name,
        address: site.address,
        lat: fix.lat,
        lng: fix.lng,
        confidence: _confidenceScore(fix, site),
        confirmedByUser: confirmedByUser,
        autoLogged: autoLogged,
        timestamp: DateTime.now(),
      ),
    );

    setState(() {
      _sessionLoggedAddresses.add(site.address);
      _outOfGeofenceSince.remove(site.address);
      _pendingSite = null;
      _promptCountdown = 0;
      _status = autoLogged
          ? 'No response received. Job auto-logged for ${site.address}.'
          : 'Job confirmed and logged for ${site.address}.';
    });
    unawaited(_cancelLogReminderNotification());
  }

  void _debugRetriggerCurrentSite() {
    if (_pendingSite != null) {
      setState(() {
        _status = 'A log reminder is already active.';
      });
      return;
    }

    final JobSite? site = _candidateSite ?? _latestNearest?.site;
    if (site == null) {
      setState(() {
        _status = 'No nearby site available to retrigger.';
      });
      return;
    }

    setState(() {
      _sessionLoggedAddresses.remove(site.address);
      _outOfGeofenceSince.remove(site.address);
      _stableSamples = max(_stableSamples, _requiredStableSamples);
      _dwellMinutes[site.address] = max(
        _dwellMinutes[site.address] ?? 0,
        site.requiredDwellMinutes.toDouble(),
      );
      _status = 'Debug retrigger armed for ${site.address}.';
    });

    _showConfirmationPrompt(site);
  }

  double _confidenceScore(LocationFix fix, JobSite site) {
    final double distance =
        _distanceMeters(fix.lat, fix.lng, site.lat, site.lng);
    final double accuracyScore = (1 - (fix.accuracyMeters / 60)).clamp(0, 1);
    final double distanceScore = (1 - (distance / 120)).clamp(0, 1);
    final double speedScore = (1 - (fix.speedMetersPerSecond / 3)).clamp(0, 1);
    return ((accuracyScore * 0.4) +
            (distanceScore * 0.4) +
            (speedScore * 0.2)) *
        100;
  }

  String _buildStatusText({
    required SiteDistance nearest,
    required bool goodAccuracy,
    required bool lowSpeed,
    required bool inGeofence,
    required double effectiveRadius,
    required bool hideNearestDetails,
  }) {
    final double dwell = _dwellMinutes[nearest.site.address] ?? 0;
    final double remaining = _minutesRemainingToLog(nearest.site);
    final String accuracyLabel =
        goodAccuracy ? 'good' : 'poor (nearest estimate may drift)';

    if (hideNearestDetails) {
      return 'Far from saved locations | '
          'distance: ${_fmtDist(nearest.distanceMeters)} | '
          'accuracy: $accuracyLabel | '
          'motion: ${lowSpeed ? 'stationary' : 'moving'}';
    }

    return 'Nearest: ${nearest.site.address} | '
        'distance: ${_fmtDist(nearest.distanceMeters)} | '
        'target: ${nearest.site.requiredDwellMinutes} min | '
        'dwell: ${dwell.toStringAsFixed(1)} min | '
        'remaining: ${remaining.toStringAsFixed(1)} min | '
        'accuracy: $accuracyLabel | '
        'motion: ${lowSpeed ? 'stationary' : 'moving'} | '
        'geofence: ${inGeofence ? 'inside' : 'outside'} '
        '(${_fmtDist(nearest.distanceMeters, decimals: 0)}/${_fmtDist(effectiveRadius, decimals: 0)})';
  }

  Future<_GeocodePoint?> _lookupCoordinates(_AddLocationInput input) async {
    final String query =
        '${input.street.trim()}, ${input.city.trim()}, ${input.state.trim()} ${input.zip.trim()}, USA';
    final Uri uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      <String, String>{
        'q': query,
        'format': 'json',
        'limit': '1',
      },
    );

    try {
      final http.Response response = await http.get(
        uri,
        headers: <String, String>{
          'User-Agent': 'lokalog-app/1.0 (mobile field logging demo)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        return null;
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! List<dynamic> || decoded.isEmpty) {
        return null;
      }

      final dynamic first = decoded.first;
      if (first is! Map<String, dynamic>) {
        return null;
      }

      final double? lat = double.tryParse(first['lat']?.toString() ?? '');
      final double? lng = double.tryParse(first['lon']?.toString() ?? '');
      if (lat == null || lng == null) {
        return null;
      }

      return _GeocodePoint(lat: lat, lng: lng);
    } catch (_) {
      return null;
    }
  }

  SiteDistance _findNearestSite(LocationFix fix, List<JobSite> sites) {
    JobSite nearest = sites.first;
    double best = _distanceMeters(fix.lat, fix.lng, nearest.lat, nearest.lng);
    for (final JobSite site in sites.skip(1)) {
      final double next = _distanceMeters(fix.lat, fix.lng, site.lat, site.lng);
      if (next < best) {
        nearest = site;
        best = next;
      }
    }
    return SiteDistance(site: nearest, distanceMeters: best);
  }

  double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double deg) => deg * pi / 180;

  String _formatLogTimestamp(DateTime value) {
    const List<String> monthNames = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final DateTime local = value.toLocal();
    final int hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final String minute = local.minute.toString().padLeft(2, '0');
    final String meridiem = local.hour >= 12 ? 'PM' : 'AM';
    return '${monthNames[local.month - 1]} ${local.day}, ${local.year} at '
        '$hour12:$minute $meridiem';
  }

  String _buildShareTextForLog(JobLog log) {
    final String clientName = log.name.trim().isEmpty ? 'Client' : log.name;
    return 'Lokalog Job Log\n'
        'Customer: $clientName\n'
        'Address: ${log.address}\n'
        'Time: ${_formatLogTimestamp(log.timestamp)}\n'
        'Confidence: ${log.confidence.toStringAsFixed(1)}%\n'
        'Type: ${log.confirmedByUser ? 'confirmed' : 'auto-logged'}';
  }

  Future<void> _shareLogEntry(JobLog log) async {
    final String clientName = log.name.trim().isEmpty ? 'Client' : log.name;
    await _shareText(
      text: _buildShareTextForLog(log),
      subject: 'Lokalog: $clientName',
    );
  }

  Future<void> _shareText({
    required String text,
    required String subject,
  }) async {
    try {
      await _locationChannel.invokeMethod<void>(
        'shareText',
        <String, dynamic>{
          'text': text,
          'subject': subject,
        },
      );
    } on MissingPluginException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Share is currently supported on Android only.'),
        ),
      );
    } on PlatformException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open share sheet.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open share sheet.')),
      );
    }
  }

  Future<void> _shareAllLogs() async {
    if (_logs.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No logs available to share.')),
      );
      return;
    }

    final String joined = _logs
        .map((JobLog log) => _buildShareTextForLog(log))
        .join('\n\n----------------\n\n');

    await _shareText(
      text: joined,
      subject: 'Lokalog: ${_logs.length} shared logs',
    );
  }

  Future<void> _showLogReminderNotification(JobSite site, int countdown) async {
    try {
      await _locationChannel.invokeMethod<void>(
        'showLogReminderNotification',
        <String, dynamic>{
          'name': site.name,
          'address': site.address,
          'countdownSeconds': countdown,
        },
      );
    } on MissingPluginException {
      // Notification reminder is Android-only in this build.
    } on PlatformException {
      // Keep core log flow even if notification fails.
    }
  }

  Future<void> _cancelLogReminderNotification() async {
    try {
      await _locationChannel.invokeMethod<void>('cancelLogReminderNotification');
    } on MissingPluginException {
      // Notification reminder is Android-only in this build.
    } on PlatformException {
      // Ignore cancellation errors.
    }
  }

  String get _appBarSectionTitle {
    if (_selectedTabIndex == 0) {
      return 'Location Log';
    }
    if (_selectedTabIndex == 1) {
      return 'Saved Locations';
    }
    if (_selectedTabIndex == 2) {
      return 'Settings';
    }
    return 'Debug Tools';
  }

  IconData get _appBarSectionIcon {
    if (_selectedTabIndex == 0) {
      return Icons.fact_check;
    }
    if (_selectedTabIndex == 1) {
      return Icons.place;
    }
    if (_selectedTabIndex == 2) {
      return Icons.settings;
    }
    return Icons.bug_report;
  }

  bool _hasMissingRequiredLocationFields(_AddLocationInput input) {
    return input.name.trim().isEmpty ||
        input.street.trim().isEmpty ||
        input.city.trim().isEmpty ||
        input.state.trim().isEmpty ||
        input.zip.trim().isEmpty;
  }

  Future<void> _onAddNewLocation() async {
    if (_sites.length >= _maxSavedLocations) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Only $_maxSavedLocations locations are allowed. Delete one to add another.',
          ),
        ),
      );
      return;
    }

    _AddLocationInput? prefill;
    String? sheetError;

    while (true) {
      final _AddLocationInput? result =
          await showModalBottomSheet<_AddLocationInput>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext sheetContext) {
          return _AddLocationSheet(
            title: 'Add New Location',
            submitLabel: 'Add',
            logMinuteOptions: _logMinuteOptions,
            initialInput: prefill,
            errorMessage: sheetError,
          );
        },
      );

      if (result == null || !mounted) {
        return;
      }

      if (_hasMissingRequiredLocationFields(result)) {
        prefill = result;
        sheetError = 'Please fill name, street, city, state, and ZIP.';
        continue;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Looking up latitude/longitude...')),
      );

      final _GeocodePoint? point = await _lookupCoordinates(result);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (point == null) {
        prefill = result;
        sheetError =
            'Could not find that address. Please correct it and try again.';
        continue;
      }

      final JobSite newSite = JobSite(
        name: result.name,
        street: result.street,
        city: result.city,
        state: result.state,
        zip: result.zip,
        lat: point.lat,
        lng: point.lng,
        requiredDwellMinutes: result.requiredMinutes,
      );

      if (_sites.length >= _maxSavedLocations) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Only $_maxSavedLocations locations are allowed. Delete one to add another.',
            ),
          ),
        );
        return;
      }

      setState(() {
        _sites.add(newSite);
        _status =
            'Added location: ${newSite.name} at ${newSite.address} (${result.requiredMinutes}m).';
      });
      unawaited(_saveSites());
      return;
    }
  }

  Future<LocationFix?> _readCurrentLocationForAdd() async {
    if (!Platform.isAndroid) {
      if (!mounted) {
        return null;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Current GPS lookup is available on Android only.'),
        ),
      );
      return null;
    }

    bool serviceEnabled = false;
    try {
      serviceEnabled = (await _locationChannel
              .invokeMethod<bool>('isLocationServiceEnabled')) ??
          false;
    } on PlatformException {
      serviceEnabled = false;
    }
    if (!serviceEnabled) {
      if (!mounted) {
        return null;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Location services are off. Turn on GPS and try again.'),
        ),
      );
      return null;
    }

    final bool granted = (await _locationChannel
            .invokeMethod<bool>('checkAndRequestPermission')) ??
        false;
    if (!granted) {
      if (!mounted) {
        return null;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission is required to use current GPS.'),
        ),
      );
      return null;
    }

    try {
      final Map<Object?, Object?>? position = await _locationChannel
          .invokeMethod<Map<Object?, Object?>>('getCurrentLocation')
          .timeout(const Duration(seconds: 12));
      final double? lat = (position?['latitude'] as num?)?.toDouble();
      final double? lng = (position?['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) {
        return null;
      }
      return LocationFix(
        lat: lat,
        lng: lng,
        accuracyMeters: ((position?['accuracy'] as num?)?.toDouble() ?? 999),
        speedMetersPerSecond: max(
          0,
          ((position?['speed'] as num?)?.toDouble() ?? 0),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<_AddLocationInput?> _reverseLookupAddress(LocationFix fix) async {
    final Uri uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/reverse',
      <String, String>{
        'lat': fix.lat.toString(),
        'lon': fix.lng.toString(),
        'format': 'jsonv2',
        'addressdetails': '1',
      },
    );

    try {
      final http.Response response = await http.get(
        uri,
        headers: <String, String>{
          'User-Agent': 'lokalog-app/1.0 (mobile field logging demo)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        return null;
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final dynamic addressRaw = decoded['address'];
      if (addressRaw is! Map<String, dynamic>) {
        return null;
      }

      final String houseNumber =
          (addressRaw['house_number'] ?? '').toString().trim();
      final String road = ((addressRaw['road'] ??
                  addressRaw['pedestrian'] ??
                  addressRaw['footway'] ??
                  addressRaw['path'] ??
                  addressRaw['residential'] ??
                  '')
              .toString())
          .trim();
      final String street =
          [houseNumber, road].where((String part) => part.isNotEmpty).join(' ');

      final String city = ((addressRaw['city'] ??
                  addressRaw['town'] ??
                  addressRaw['village'] ??
                  addressRaw['hamlet'] ??
                  addressRaw['county'] ??
                  '')
              .toString())
          .trim();

        final String stateCode =
          (addressRaw['state_code'] ?? '').toString().trim().toUpperCase();
        final String stateName = ((addressRaw['state'] ??
              addressRaw['region'] ??
              addressRaw['state_district'] ??
              addressRaw['province'] ??
              '')
            .toString())
          .trim()
          .toUpperCase();
        final String isoStateCode = ((addressRaw['ISO3166-2-lvl4'] ??
              addressRaw['ISO3166-2-lvl5'] ??
              addressRaw['ISO3166-2-lvl6'] ??
              addressRaw['ISO3166-2-lvl7'] ??
              addressRaw['ISO3166-2-lvl8'] ??
              '')
            .toString())
          .trim()
          .toUpperCase();
      String state =
          stateCode.contains('-') ? stateCode.split('-').last : stateCode;
        if (state.isEmpty && isoStateCode.isNotEmpty) {
        state = isoStateCode.contains('-')
          ? isoStateCode.split('-').last
          : isoStateCode;
        }
      if (state.isEmpty) {
        const Map<String, String> usStateCodes = <String, String>{
          'ALABAMA': 'AL',
          'ALASKA': 'AK',
          'ARIZONA': 'AZ',
          'ARKANSAS': 'AR',
          'CALIFORNIA': 'CA',
          'COLORADO': 'CO',
          'CONNECTICUT': 'CT',
          'DELAWARE': 'DE',
          'FLORIDA': 'FL',
          'GEORGIA': 'GA',
          'HAWAII': 'HI',
          'IDAHO': 'ID',
          'ILLINOIS': 'IL',
          'INDIANA': 'IN',
          'IOWA': 'IA',
          'KANSAS': 'KS',
          'KENTUCKY': 'KY',
          'LOUISIANA': 'LA',
          'MAINE': 'ME',
          'MARYLAND': 'MD',
          'MASSACHUSETTS': 'MA',
          'MICHIGAN': 'MI',
          'MINNESOTA': 'MN',
          'MISSISSIPPI': 'MS',
          'MISSOURI': 'MO',
          'MONTANA': 'MT',
          'NEBRASKA': 'NE',
          'NEVADA': 'NV',
          'NEW HAMPSHIRE': 'NH',
          'NEW JERSEY': 'NJ',
          'NEW MEXICO': 'NM',
          'NEW YORK': 'NY',
          'NORTH CAROLINA': 'NC',
          'NORTH DAKOTA': 'ND',
          'OHIO': 'OH',
          'OKLAHOMA': 'OK',
          'OREGON': 'OR',
          'PENNSYLVANIA': 'PA',
          'RHODE ISLAND': 'RI',
          'SOUTH CAROLINA': 'SC',
          'SOUTH DAKOTA': 'SD',
          'TENNESSEE': 'TN',
          'TEXAS': 'TX',
          'UTAH': 'UT',
          'VERMONT': 'VT',
          'VIRGINIA': 'VA',
          'WASHINGTON': 'WA',
          'WEST VIRGINIA': 'WV',
          'WISCONSIN': 'WI',
          'WYOMING': 'WY',
          'DISTRICT OF COLUMBIA': 'DC',
        };
          state = usStateCodes[stateName] ??
            (stateName.length == 2
              ? stateName
              : (stateName.isNotEmpty ? stateName : ''));
      }
      final String zip = (addressRaw['postcode'] ?? '').toString().trim();

      if (street.isEmpty && city.isEmpty && state.isEmpty && zip.isEmpty) {
        return null;
      }

      return _AddLocationInput(
        name: '',
        street: street,
        city: city,
        state: state,
        zip: zip,
        requiredMinutes:
            _logMinuteOptions.contains(20) ? 20 : _logMinuteOptions.first,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _onAddFromCurrentLocation() async {
    if (_sites.length >= _maxSavedLocations || _isFetchingCurrentLocation) {
      if (!mounted) {
        return;
      }
      if (_sites.length >= _maxSavedLocations) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Only $_maxSavedLocations locations are allowed. Delete one to add another.',
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isFetchingCurrentLocation = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reading current GPS location...')),
    );
    final LocationFix? fix = await _readCurrentLocationForAdd();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (fix == null) {
      setState(() {
        _isFetchingCurrentLocation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Could not get current GPS location. Please try again.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Looking up address from GPS...')),
    );
    final _AddLocationInput? reversePrefill = await _reverseLookupAddress(fix);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    _AddLocationInput? prefill = reversePrefill ??
        _AddLocationInput(
          name: '',
          street: '',
          city: '',
          state: '',
          zip: '',
          requiredMinutes:
              _logMinuteOptions.contains(20) ? 20 : _logMinuteOptions.first,
        );
    String? sheetError = reversePrefill == null
        ? 'Could not detect full address from GPS. Please enter or correct it.'
        : 'Confirm the address and enter a name.';

    while (true) {
      final _AddLocationInput? result =
          await showModalBottomSheet<_AddLocationInput>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext sheetContext) {
          return _AddLocationSheet(
            title: 'Add From Current Location',
            submitLabel: 'Add',
            logMinuteOptions: _logMinuteOptions,
            initialInput: prefill,
            errorMessage: sheetError,
          );
        },
      );

      if (result == null || !mounted) {
        setState(() {
          _isFetchingCurrentLocation = false;
        });
        return;
      }

      if (_hasMissingRequiredLocationFields(result)) {
        prefill = result;
        sheetError = 'Please fill name, street, city, state, and ZIP.';
        continue;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verifying address coordinates...')),
      );
      final _GeocodePoint? point = await _lookupCoordinates(result);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (point == null) {
        prefill = result;
        sheetError =
            'Could not find that address. Please correct it and try again.';
        continue;
      }

      if (_sites.length >= _maxSavedLocations) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Only $_maxSavedLocations locations are allowed. Delete one to add another.',
            ),
          ),
        );
        setState(() {
          _isFetchingCurrentLocation = false;
        });
        return;
      }

      final JobSite newSite = JobSite(
        name: result.name,
        street: result.street,
        city: result.city,
        state: result.state,
        zip: result.zip,
        lat: point.lat,
        lng: point.lng,
        requiredDwellMinutes: result.requiredMinutes,
      );

      setState(() {
        _sites.add(newSite);
        _isFetchingCurrentLocation = false;
        _status =
            'Added location from current GPS: ${newSite.name} at ${newSite.address} (${result.requiredMinutes}m).';
      });
      unawaited(_saveSites());
      return;
    }
  }

  Future<void> _onEditLocation(int index, JobSite site) async {
    _AddLocationInput? prefill = _AddLocationInput(
      name: site.name,
      street: site.street,
      city: site.city,
      state: site.state,
      zip: site.zip,
      requiredMinutes: site.requiredDwellMinutes,
    );
    String? sheetError;

    while (true) {
      final _AddLocationInput? result =
          await showModalBottomSheet<_AddLocationInput>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext sheetContext) {
          return _AddLocationSheet(
            title: 'Edit Location',
            submitLabel: 'Save',
            logMinuteOptions: _logMinuteOptions,
            initialInput: prefill,
            errorMessage: sheetError,
          );
        },
      );

      if (result == null || !mounted) {
        return;
      }

      if (_hasMissingRequiredLocationFields(result)) {
        prefill = result;
        sheetError = 'Please fill name, street, city, state, and ZIP.';
        continue;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Looking up updated latitude/longitude...')),
      );

      final _GeocodePoint? point = await _lookupCoordinates(result);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (point == null) {
        prefill = result;
        sheetError = 'Could not geocode address. Please verify and try again.';
        continue;
      }

      final JobSite updatedSite = JobSite(
        name: result.name,
        street: result.street,
        city: result.city,
        state: result.state,
        zip: result.zip,
        lat: point.lat,
        lng: point.lng,
        requiredDwellMinutes: result.requiredMinutes,
      );

      setState(() {
        _sites[index] = updatedSite;
        _status =
            'Updated location: ${updatedSite.name} at ${updatedSite.address} (${result.requiredMinutes}m).';
      });
      unawaited(_saveSites());
      return;
    }
  }

  Future<void> _onDeleteLocation(int index, JobSite site) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Location'),
          content: Text('Delete ${site.name}? This cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmDelete != true || !mounted) {
      return;
    }

    setState(() {
      _sites.removeAt(index);
      _status = 'Deleted location: ${site.name}.';
    });
    unawaited(_saveSites());
  }

  Future<void> _onDeleteLogEntry(int index, JobLog log) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Log Entry'),
          content: Text('Delete log for ${log.address}?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmDelete != true || !mounted) {
      return;
    }

    final String deletedKey = _logStorageKey(
      address: log.address,
      timestampMillis: log.timestamp.millisecondsSinceEpoch,
    );
    _deletedLogKeys.add(deletedKey);
    unawaited(_saveDeletedLogKeys());

    setState(() {
      _logs.removeAt(index);
      _status = 'Deleted one log entry.';
    });

    try {
      await _locationChannel.invokeMethod<void>(
        'deleteBackgroundLog',
        <String, dynamic>{
          'address': log.address,
          'timestamp': log.timestamp.millisecondsSinceEpoch,
        },
      );
    } on MissingPluginException {
      // Desktop/iOS/web may not implement background log persistence.
    } on PlatformException {
      // Keep local delete behavior even if persistence fails.
    }
  }

  Widget _buildLogScreen() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_status),
          ),
        ),
        if (_currentFix != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Current GPS: ${_currentFix!.lat.toStringAsFixed(5)}, '
                '${_currentFix!.lng.toStringAsFixed(5)}\n'
                'Accuracy: ${_fmtAccuracy(_currentFix!.accuracyMeters)} | '
                'Speed: ${_fmtSpeed(_currentFix!.speedMetersPerSecond)}',
              ),
            ),
          ),
        if (_latestNearest != null && !_shouldHideNearestInfo(_latestNearest!))
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Countdown to log ${_latestNearest!.site.name}: '
                '${_minutesRemainingToLog(_latestNearest!.site).toStringAsFixed(1)} minutes remaining',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'Locations Log',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton.icon(
              onPressed: _shareAllLogs,
              icon: const Icon(Icons.share),
              label: const Text('Share All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_logs.isEmpty)
          const Text('No locations logged yet.')
        else
          ..._logs.asMap().entries.map((MapEntry<int, JobLog> entry) {
            final int index = entry.key;
            final JobLog log = entry.value;
            final String clientName =
                log.name.trim().isEmpty ? 'Client' : log.name.trim();
            final String address = log.address.trim();
            final bool showAddressLine =
                address.isNotEmpty && address != clientName;
            return Card(
              child: ListTile(
                title: Text('Customer: $clientName'),
                subtitle: Text(
                  '${showAddressLine ? '$address\n' : ''}'
                  '${_formatLogTimestamp(log.timestamp)}\n'
                  'Confidence: ${log.confidence.toStringAsFixed(1)}% | '
                  '${log.confirmedByUser ? 'confirmed' : 'auto-logged'}',
                ),
                isThreeLine: showAddressLine,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Share log',
                      onPressed: () => _shareLogEntry(log),
                      icon: const Icon(Icons.share),
                    ),
                    IconButton(
                      tooltip: 'Delete log',
                      onPressed: () => _onDeleteLogEntry(index, log),
                      icon: const Icon(Icons.delete),
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildSettingsScreen() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: SwitchListTile(
            title: const Text('Debug Mode'),
            subtitle: const Text('Show or hide the Debug tab and tools.'),
            value: _debugModeEnabled,
            onChanged: (bool enabled) {
              setState(() {
                _debugModeEnabled = enabled;
                if (!_debugModeEnabled && _selectedTabIndex == 3) {
                  _selectedTabIndex = 2;
                }
              });
              unawaited(_locationChannel.invokeMethod<void>(
                'savePreference',
                <String, dynamic>{
                  'key': _debugModePreferenceKey,
                  'value': enabled.toString(),
                },
              ));
            },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SwitchListTile(
            title: const Text('Dark Theme'),
            subtitle: const Text('Toggle between light and dark mode.'),
            value: widget.isDarkMode,
            onChanged: widget.onDarkModeChanged,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SwitchListTile(
            title: const Text('Units'),
            subtitle: Text(_useMetric ? 'Metric (m, m/s)' : 'English (ft, mph)'),
            value: _useMetric,
            onChanged: (bool value) {
              setState(() {
                _useMetric = value;
              });
              unawaited(_saveUnitPreference());
              _refreshNearestUiFromCurrentFix();
            },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Font Size',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Current: ${widget.fontScale.toStringAsFixed(2)}x',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: widget.fontScale <= widget.minFontScale
                          ? null
                          : () {
                              widget.onFontScaleChanged(
                                widget.fontScale - widget.fontScaleStep,
                              );
                            },
                      icon: const Icon(Icons.remove),
                      label: const Text('Decrease'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.fontScale >= widget.maxFontScale
                          ? null
                          : () {
                              widget.onFontScaleChanged(
                                widget.fontScale + widget.fontScaleStep,
                              );
                            },
                      icon: const Icon(Icons.add),
                      label: const Text('Increase'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Tracking Controls',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tracking On'),
                  subtitle: Text(_isTracking
                      ? 'Tracking is active.'
                      : 'Tracking is stopped.'),
                  value: _isTracking,
                  onChanged: (bool value) {
                    unawaited(_onTrackingToggleChanged(value));
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  _isTracking
                      ? 'Current polling: ${_formatSecondsOption(_activePollSeconds())} (${_pollingModeSummary()} mode).'
                      : 'Close polling uses ${_formatSecondsOption(_closePollSeconds)}. Far polling uses ${_formatSecondsOption(_farPollSeconds)} beyond ${_formatMetersOption(_farDistanceMeters)}.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Polling Behavior',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _closePollSeconds,
                  decoration: const InputDecoration(
                    labelText: 'Poll when close to a location',
                    border: OutlineInputBorder(),
                  ),
                  items: _closePollSecondOptions
                      .map(
                        (int value) => DropdownMenuItem<int>(
                          value: value,
                          child: Text(_formatSecondsOption(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (int? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _closePollSeconds = value;
                    });
                    unawaited(_savePollingPreferences());
                    if (_isTracking) {
                      _scheduleNextPoll(immediate: true);
                    }
                    _refreshNearestUiFromCurrentFix();
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _farPollSeconds,
                  decoration: const InputDecoration(
                    labelText: 'Poll when far from any location',
                    border: OutlineInputBorder(),
                  ),
                  items: _farPollSecondOptions
                      .map(
                        (int value) => DropdownMenuItem<int>(
                          value: value,
                          child: Text(_formatSecondsOption(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (int? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _farPollSeconds = value;
                    });
                    unawaited(_savePollingPreferences());
                    if (_isTracking) {
                      _scheduleNextPoll(immediate: true);
                    }
                    _refreshNearestUiFromCurrentFix();
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _farDistanceMeters,
                  decoration: const InputDecoration(
                    labelText: 'Consider far from locations at',
                    border: OutlineInputBorder(),
                  ),
                  items: _farDistanceMeterOptions
                      .map(
                        (int value) => DropdownMenuItem<int>(
                          value: value,
                          child: Text(_formatMetersOption(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (int? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _farDistanceMeters = value;
                    });
                    unawaited(_savePollingPreferences());
                    if (_isTracking) {
                      _scheduleNextPoll(immediate: true);
                    }
                    _refreshNearestUiFromCurrentFix();
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _outOfGeofenceRetriggerMinutes,
                  decoration: const InputDecoration(
                    labelText: 'Out-of-geofence retrigger',
                    border: OutlineInputBorder(),
                  ),
                  items: _outOfGeofenceRetriggerMinuteOptions
                      .map(
                        (int value) => DropdownMenuItem<int>(
                          value: value,
                          child: Text(
                            value == 60 ? '1 hr' : '$value min',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (int? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _outOfGeofenceRetriggerMinutes = value;
                    });
                    unawaited(_savePollingPreferences());
                    _refreshNearestUiFromCurrentFix();
                  },
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hide nearest when far'),
                  subtitle: Text(
                    'Hide nearest-location details when distance is beyond ${_formatMetersOption(_farDistanceMeters)}.',
                  ),
                  value: _hideNearestWhenFar,
                  onChanged: (bool value) {
                    setState(() {
                      _hideNearestWhenFar = value;
                    });
                    unawaited(_savePollingPreferences());
                    _refreshNearestUiFromCurrentFix();
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Permission Shortcuts',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: _openLocationSettings,
                      icon: const Icon(Icons.gps_fixed),
                      label: const Text('Location Settings'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openAppSettings,
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: const Text('App Permissions'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationsScreen() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
          'Locations',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_sites.isEmpty)
          const Text('No locations added yet.')
        else
          ..._sites.asMap().entries.map((MapEntry<int, JobSite> entry) {
            final JobSite site = entry.value;
            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${entry.key + 1}')),
                title: Text(site.name),
                subtitle: Text(
                  '${site.address}\n'
                  'Lat: ${site.lat.toStringAsFixed(5)}, Lng: ${site.lng.toStringAsFixed(5)}\n'
                  'Log after: ${site.requiredDwellMinutes} minutes',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (String action) {
                    if (action == 'edit') {
                      _onEditLocation(entry.key, site);
                    } else if (action == 'delete') {
                      _onDeleteLocation(entry.key, site);
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildDebugScreen() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: SwitchListTile(
            title: const Text('Show Battery Info'),
            subtitle: const Text('Show or hide battery diagnostics below.'),
            value: _showBatteryInfo,
            onChanged: _setShowBatteryInfo,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _isTracking
                  ? 'Position polling: ${_formatSecondsOption(_activePollSeconds())} (${_pollingModeSummary()} mode).'
                  : 'Position polling is inactive. Close: ${_formatSecondsOption(_closePollSeconds)}, Far: ${_formatSecondsOption(_farPollSeconds)} beyond ${_formatMetersOption(_farDistanceMeters)}.',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Retrigger Logging',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Force a new log attempt for the current or nearest site without leaving geofence.',
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _debugRetriggerCurrentSite,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Retrigger Now'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_showBatteryInfo) ...<Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Debug Tools',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed:
                          _isLoadingBatteryUsage ? null : _loadBatteryUsage,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh Battery Usage'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openUsageAccessSettings,
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: const Text('Usage Access Settings'),
                    ),
                  ],
                ),
                if (_isLoadingBatteryUsage) ...<Widget>[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _usageAccessGranted
                      ? 'Usage Access: Granted'
                      : 'Usage Access: Not Granted',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _usageAccessGranted ? Colors.green : Colors.orange,
                  ),
                ),
                if (_deviceBatteryLevel != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text('Current device battery: ${_deviceBatteryLevel!}%'),
                ],
                if (_batteryUsageFetchedAt != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text('Last updated: ${_batteryUsageFetchedAt!.toLocal()}'),
                ],
                if (_batteryUsageError != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    _batteryUsageError!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Battery Usage by App (Estimated)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_batteryUsage.isEmpty && !_isLoadingBatteryUsage)
          const Text('No data yet. Grant Usage Access and tap Refresh.')
        else
          ..._batteryUsage.map((DebugBatteryAppUsage app) {
            final double normalized =
                (app.estimatedBatterySharePercent / 100).clamp(0, 1);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      app.appName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(app.packageName),
                    const SizedBox(height: 6),
                    Text(
                      'Foreground: ${app.foregroundMinutes.toStringAsFixed(1)} min | '
                      'Estimated share: ${app.estimatedBatterySharePercent.toStringAsFixed(1)}%',
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: normalized),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Row(
            key: ValueKey<int>(_selectedTabIndex),
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _appBarSectionIcon,
                  size: 20,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'LokaLog',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                  ),
                  Text(
                    _appBarSectionTitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: <Widget>[
          _buildLogScreen(),
          _buildLocationsScreen(),
          _buildSettingsScreen(),
          if (_debugModeEnabled) _buildDebugScreen(),
        ],
      ),
      floatingActionButton: _selectedTabIndex == 1
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                FloatingActionButton.extended(
                  onPressed: _sites.length >= _maxSavedLocations ||
                          _isFetchingCurrentLocation
                      ? null
                      : _onAddFromCurrentLocation,
                  icon: _isFetchingCurrentLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: const Text('Current Location'),
                ),
                const SizedBox(width: 10),
                FloatingActionButton.extended(
                  onPressed: _sites.length >= _maxSavedLocations
                      ? null
                      : _onAddNewLocation,
                  icon: const Icon(Icons.add_location_alt),
                  label: Text(
                    _sites.length >= _maxSavedLocations
                        ? 'Max 5 Reached'
                        : 'Add New',
                  ),
                ),
              ],
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedTabIndex = index;
          });
          if (_debugModeEnabled &&
              index == 3 &&
              _showBatteryInfo &&
              _batteryUsage.isEmpty &&
              !_isLoadingBatteryUsage) {
            unawaited(_loadBatteryUsage());
          }
        },
        destinations: <NavigationDestination>[
          const NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check),
            label: 'Log',
          ),
          const NavigationDestination(
            icon: Icon(Icons.place_outlined),
            selectedIcon: Icon(Icons.place),
            label: 'Locations',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
          if (_debugModeEnabled)
            const NavigationDestination(
              icon: Icon(Icons.bug_report_outlined),
              selectedIcon: Icon(Icons.bug_report),
              label: 'Debug',
            ),
        ],
      ),
    );
  }
}

class DebugBatteryAppUsage {
  DebugBatteryAppUsage({
    required this.packageName,
    required this.appName,
    required this.foregroundMinutes,
    required this.estimatedBatterySharePercent,
  });

  final String packageName;
  final String appName;
  final double foregroundMinutes;
  final double estimatedBatterySharePercent;
}

class JobSite {
  JobSite({
    required this.name,
    required this.street,
    required this.city,
    required this.state,
    required this.zip,
    required this.lat,
    required this.lng,
    required this.requiredDwellMinutes,
  });

  final String name;
  final String street;
  final String city;
  final String state;
  final String zip;
  final double lat;
  final double lng;
  final int requiredDwellMinutes;

  String get address => '$street, $city, $state $zip';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'street': street,
      'city': city,
      'state': state,
      'zip': zip,
      'lat': lat,
      'lng': lng,
      'requiredDwellMinutes': requiredDwellMinutes,
    };
  }

  factory JobSite.fromJson(Map<String, dynamic> json) {
    return JobSite(
      name: (json['name'] ?? '').toString(),
      street: (json['street'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      zip: (json['zip'] ?? '').toString(),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      requiredDwellMinutes: (json['requiredDwellMinutes'] as num).toInt(),
    );
  }
}

class LocationFix {
  LocationFix({
    required this.lat,
    required this.lng,
    required this.accuracyMeters,
    required this.speedMetersPerSecond,
  });

  final double lat;
  final double lng;
  final double accuracyMeters;
  final double speedMetersPerSecond;
}

class SiteDistance {
  SiteDistance({required this.site, required this.distanceMeters});

  final JobSite site;
  final double distanceMeters;
}

class JobLog {
  JobLog({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.confidence,
    required this.confirmedByUser,
    required this.autoLogged,
    required this.timestamp,
  });

  final String name;
  final String address;
  final double lat;
  final double lng;
  final double confidence;
  final bool confirmedByUser;
  final bool autoLogged;
  final DateTime timestamp;
}

class _AddLocationInput {
  _AddLocationInput({
    required this.name,
    required this.street,
    required this.city,
    required this.state,
    required this.zip,
    required this.requiredMinutes,
  });

  final String name;
  final String street;
  final String city;
  final String state;
  final String zip;
  final int requiredMinutes;
}

class _GeocodePoint {
  _GeocodePoint({required this.lat, required this.lng});

  final double lat;
  final double lng;
}

class _AddLocationSheet extends StatefulWidget {
  const _AddLocationSheet({
    required this.title,
    required this.submitLabel,
    required this.logMinuteOptions,
    this.initialInput,
    this.errorMessage,
  });

  final String title;
  final String submitLabel;
  final List<int> logMinuteOptions;
  final _AddLocationInput? initialInput;
  final String? errorMessage;

  @override
  State<_AddLocationSheet> createState() => _AddLocationSheetState();
}

class _AddLocationSheetState extends State<_AddLocationSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _zipController = TextEditingController();

  int _selectedMinutes = 20;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    final _AddLocationInput? initial = widget.initialInput;
    if (initial != null) {
      _nameController.text = initial.name;
      _streetController.text = initial.street;
      _cityController.text = initial.city;
      _stateController.text = initial.state;
      _zipController.text = initial.zip;
      _selectedMinutes = initial.requiredMinutes;
    }

    if (!widget.logMinuteOptions.contains(_selectedMinutes) &&
        widget.logMinuteOptions.isNotEmpty) {
      _selectedMinutes = widget.logMinuteOptions.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  String _capitalizeWord(String value) {
    if (value.isEmpty) {
      return value;
    }
    final String lower = value.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }

  String _toTitleCase(String input) {
    return input
        .trim()
        .split(RegExp(r'\s+'))
        .where((String segment) => segment.isNotEmpty)
        .map((String token) {
      return token.split('-').map((String part) {
        return part.split("'").map(_capitalizeWord).join("'");
      }).join('-');
    }).join(' ');
  }

  bool _hasMissingRequiredValues(_AddLocationInput input) {
    return input.name.trim().isEmpty ||
        input.street.trim().isEmpty ||
        input.city.trim().isEmpty ||
        input.state.trim().isEmpty ||
        input.zip.trim().isEmpty;
  }

  void _submit() {
    final _AddLocationInput input = _AddLocationInput(
      name: _toTitleCase(_nameController.text),
      street: _toTitleCase(_streetController.text),
      city: _toTitleCase(_cityController.text),
      state: _stateController.text.trim().toUpperCase(),
      zip: _zipController.text.trim(),
      requiredMinutes: _selectedMinutes,
    );

    if (_hasMissingRequiredValues(input)) {
      setState(() {
        _submitError = 'Please fill name, street, city, state, and ZIP.';
      });
      return;
    }

    Navigator.of(context).pop(input);
  }

  @override
  Widget build(BuildContext context) {
    final double keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (_submitError != null ||
                      widget.errorMessage != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      _submitError ?? widget.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    onChanged: (_) {
                      if (_submitError != null) {
                        setState(() {
                          _submitError = null;
                        });
                      }
                    },
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Client Name',
                      hintText: 'Smith Residence',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _streetController,
                    onChanged: (_) {
                      if (_submitError != null) {
                        setState(() {
                          _submitError = null;
                        });
                      }
                    },
                    textInputAction: TextInputAction.next,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Street',
                      hintText: '123 Main St',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _cityController,
                          onChanged: (_) {
                            if (_submitError != null) {
                              setState(() {
                                _submitError = null;
                              });
                            }
                          },
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'City',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _stateController,
                          onChanged: (_) {
                            if (_submitError != null) {
                              setState(() {
                                _submitError = null;
                              });
                            }
                          },
                          textInputAction: TextInputAction.next,
                          maxLength: 2,
                          decoration: const InputDecoration(
                            labelText: 'State',
                            counterText: '',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _zipController,
                    onChanged: (_) {
                      if (_submitError != null) {
                        setState(() {
                          _submitError = null;
                        });
                      }
                    },
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'ZIP',
                      hintText: '75201',
                      border: OutlineInputBorder(),
                    ),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedMinutes,
                    decoration: const InputDecoration(
                      labelText: 'How long to log (minutes)',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.logMinuteOptions.map((int minutes) {
                      return DropdownMenuItem<int>(
                        value: minutes,
                        child: Text('$minutes minutes'),
                      );
                    }).toList(),
                    onChanged: (int? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _selectedMinutes = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _submit,
                        child: Text(widget.submitLabel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
