import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/lokalog_models.dart';
import 'services/battery_usage_service.dart';
import 'services/location_permission_service.dart';
import 'services/log_communication_service.dart';
import 'services/location_geocoding_service.dart';
import 'services/location_tracking_calculator.dart';
import 'services/scenario_dialog_service.dart';
import 'services/scenario_preferences_service.dart';
import 'services/scenario_state_controller.dart';
import 'services/tracking_controller.dart';
import 'widgets/add_location_sheet.dart';
import 'widgets/debug_screen_view.dart';
import 'widgets/log_screen_view.dart';
import 'widgets/locations_screen_view.dart';
import 'widgets/settings_screen_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    unawaited(_loadThemePreferences());
  }

  Future<void> _loadThemePreferences() async {
    try {
      final ThemePreferences prefs =
          await ScenarioPreferencesService.loadThemePreferences(
        _prefChannel,
        darkModeKey: _darkModePreferenceKey,
        fontScaleKey: _fontScalePreferenceKey,
        defaultFontScale: 1.0,
        minFontScale: _minFontScale,
        maxFontScale: _maxFontScale,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _themeMode = prefs.darkModeEnabled ? ThemeMode.dark : ThemeMode.light;
        _fontScale = prefs.fontScale;
      });
    } catch (_) {
      // Use defaults if load fails.
    }
  }

  void _setDarkMode(bool enabled) {
    setState(() {
      _themeMode = enabled ? ThemeMode.dark : ThemeMode.light;
    });
    unawaited(
      ScenarioPreferencesService.saveBoolPreference(
        _prefChannel,
        key: _darkModePreferenceKey,
        value: enabled,
      ),
    );
  }

  void _setFontScale(double value) {
    final double clamped = value.clamp(_minFontScale, _maxFontScale);
    setState(() {
      _fontScale = clamped;
    });
    unawaited(
      ScenarioPreferencesService.saveFontScalePreference(
        _prefChannel,
        key: _fontScalePreferenceKey,
        value: clamped,
      ),
    );
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
  static const String _trackingRuntimeStatePreferenceKey =
      'pref_tracking_runtime_state_v1';
  static const String _locationLimitUnlockedPreferenceKey =
      'pref_location_limit_unlocked';
  static const String _locationLimitUnlockCode = 'arokicki';
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
  static const Duration _gpsReadTimeout = Duration(seconds: 20);
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

  final ScenarioStateController _state = ScenarioStateController();
  bool _deletedLogKeysLoaded = false;
  bool _autoStartTrackingAttempted = false;
  bool _trackingOffStartupDialogShown = false;
  bool _trackingPreferenceLoaded = false;
  bool _trackingRuntimeStateLoaded = false;
  bool _sitesLoaded = false;
  bool _trackingEnabledPreference = true;
  bool _locationLimitUnlocked = false;

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
  int _outOfGeofenceRetriggerMinutes = _defaultOutOfGeofenceRetriggerMinutes;
  bool _hideNearestWhenFar = true;
  bool _useMetric = true;
  bool _isChangingTrackingState = false;
  bool _isFetchingCurrentLocation = false;
  DateTime? _lastFixAt;
  Map<Object?, Object?>? _lastRawGpsPayload;
  DateTime? _lastRawGpsPayloadAt;
  String? _lastRawGpsReadError;
  SiteDistance? _latestNearest;

  JobSite? _candidateSite;
  JobSite? _pendingSite;
  int _promptCountdown = 0;

  bool _isLoadingBatteryUsage = false;
  bool _usageAccessGranted = false;
  static const String _fallbackVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
  static const String _fallbackBuildNumber =
      String.fromEnvironment('APP_BUILD_NUMBER', defaultValue: '1');
  String _appVersionLabel = '$_fallbackVersion ($_fallbackBuildNumber)';
  String? _batteryUsageError;
  int? _deviceBatteryLevel;
  DateTime? _batteryUsageFetchedAt;
  DateTime? _trackingRuntimeStateLoadedAt;
  DateTime? _trackingRuntimeStateSavedAt;
  List<DebugBatteryAppUsage> _batteryUsage = <DebugBatteryAppUsage>[];

  List<JobSite> get _sites => _state.sites;
  List<JobLog> get _logs => _state.logs;
  Set<String> get _deletedLogKeys => _state.deletedLogKeys;
  Set<String> get _sessionLoggedAddresses => _state.sessionLoggedAddresses;
  Map<String, double> get _timeInGeofenceMinutesBySite =>
      _state.timeInGeofenceMinutes;
  Map<String, DateTime> get _outOfGeofenceSince => _state.outOfGeofenceSince;

  @override
  void initState() {
    super.initState();
    _initializeAppVersionLabel();
    unawaited(_loadDebugMode());
    unawaited(_loadPollingPreferences());
    unawaited(_loadUnitPreference());
    unawaited(_loadTrackingPreference());
    unawaited(_loadLocationLimitUnlockedPreference());
    unawaited(_loadTrackingRuntimeState());
    unawaited(_loadSites());
  }

  void _initializeAppVersionLabel() {
    const String buildDate =
        String.fromEnvironment('BUILD_DATE', defaultValue: '');
    const String buildTime =
        String.fromEnvironment('BUILD_TIME', defaultValue: '');

    final List<String> stampParts = <String>[
      buildDate.trim(),
      buildTime.trim(),
    ].where((String value) => value.isNotEmpty).toList();

    if (stampParts.isEmpty) {
      _appVersionLabel = '$_fallbackVersion ($_fallbackBuildNumber)';
      return;
    }

    _appVersionLabel =
        '$_fallbackVersion ($_fallbackBuildNumber) | Built: ${stampParts.join(' ')}';
  }

  Future<void> _loadTrackingPreference() async {
    try {
      final bool? enabled = await ScenarioPreferencesService.loadBoolPreference(
        _locationChannel,
        key: _trackingEnabledPreferenceKey,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _trackingEnabledPreference = enabled ?? true;
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
      await ScenarioPreferencesService.saveBoolPreference(
        _locationChannel,
        key: _trackingEnabledPreferenceKey,
        value: enabled,
      );
    } catch (_) {
      // Keep local preference value if persistence fails.
    }
  }

  Future<void> _loadTrackingRuntimeState() async {
    try {
      final String? raw = await ScenarioPreferencesService.loadStringPreference(
        _locationChannel,
        key: _trackingRuntimeStatePreferenceKey,
      );

      if (raw != null && raw.trim().isNotEmpty) {
        final dynamic decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _state.restoreTrackingRuntimeStateFromJson(decoded);
          if (mounted) {
            setState(() {
              _trackingRuntimeStateLoaded = true;
              _trackingRuntimeStateLoadedAt = DateTime.now();
            });
          } else {
            _trackingRuntimeStateLoaded = true;
            _trackingRuntimeStateLoadedAt = DateTime.now();
          }
          _maybeAutoStartTracking();
          return;
        }
      }
    } catch (_) {
      // Keep best-effort behavior when runtime state cannot be restored.
    }

    _trackingRuntimeStateLoaded = true;
    _trackingRuntimeStateLoadedAt = DateTime.now();
    _maybeAutoStartTracking();
  }

  Future<void> _saveTrackingRuntimeState() async {
    try {
      final Map<String, dynamic> payload =
          _state.buildTrackingRuntimeStatePayload();

      await ScenarioPreferencesService.saveStringPreference(
        _locationChannel,
        key: _trackingRuntimeStatePreferenceKey,
        value: jsonEncode(payload),
      );
      _trackingRuntimeStateSavedAt = DateTime.now();
    } catch (_) {
      // Keep runtime behavior even if persistence fails.
    }
  }

  Future<void> _loadDebugMode() async {
    try {
      final DebugPreferences prefs =
          await ScenarioPreferencesService.loadDebugPreferences(
        _locationChannel,
        debugModeKey: _debugModePreferenceKey,
        showBatteryInfoKey: _showBatteryInfoPreferenceKey,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _debugModeEnabled = prefs.debugModeEnabled;
        _showBatteryInfo = prefs.showBatteryInfo;
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
      await ScenarioPreferencesService.saveBoolPreference(
        _locationChannel,
        key: _showBatteryInfoPreferenceKey,
        value: enabled,
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
      final PollingPreferences prefs =
          await ScenarioPreferencesService.loadPollingPreferences(
        _locationChannel,
        closePollSecondsKey: _closePollSecondsPreferenceKey,
        farPollSecondsKey: _farPollSecondsPreferenceKey,
        farDistanceMetersKey: _farDistanceMetersPreferenceKey,
        outOfGeofenceRetriggerMinutesKey:
            _outOfGeofenceRetriggerMinutesPreferenceKey,
        hideNearestWhenFarKey: _hideNearestWhenFarPreferenceKey,
        defaultClosePollSeconds: _defaultClosePollSeconds,
        defaultFarPollSeconds: _defaultFarPollSeconds,
        defaultFarDistanceMeters: _defaultFarDistanceMeters,
        defaultOutOfGeofenceRetriggerMinutes:
            _defaultOutOfGeofenceRetriggerMinutes,
        closePollSecondOptions: _closePollSecondOptions,
        farPollSecondOptions: _farPollSecondOptions,
        farDistanceMeterOptions: _farDistanceMeterOptions,
        outOfGeofenceRetriggerMinuteOptions:
            _outOfGeofenceRetriggerMinuteOptions,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _closePollSeconds = prefs.closePollSeconds;
        _farPollSeconds = prefs.farPollSeconds;
        _farDistanceMeters = prefs.farDistanceMeters;
        _outOfGeofenceRetriggerMinutes = prefs.outOfGeofenceRetriggerMinutes;
        _hideNearestWhenFar = prefs.hideNearestWhenFar;
      });
    } catch (_) {
      // Keep defaults if preference load fails.
    }
  }

  Future<void> _savePollingPreferences() async {
    try {
      await ScenarioPreferencesService.savePollingPreferences(
        _locationChannel,
        closePollSecondsKey: _closePollSecondsPreferenceKey,
        closePollSeconds: _closePollSeconds,
        farPollSecondsKey: _farPollSecondsPreferenceKey,
        farPollSeconds: _farPollSeconds,
        farDistanceMetersKey: _farDistanceMetersPreferenceKey,
        farDistanceMeters: _farDistanceMeters,
        outOfGeofenceRetriggerMinutesKey:
            _outOfGeofenceRetriggerMinutesPreferenceKey,
        outOfGeofenceRetriggerMinutes: _outOfGeofenceRetriggerMinutes,
        hideNearestWhenFarKey: _hideNearestWhenFarPreferenceKey,
        hideNearestWhenFar: _hideNearestWhenFar,
      );
    } catch (_) {
      // Keep active runtime values even if persistence fails.
    }
  }

  Future<void> _loadUnitPreference() async {
    try {
      final bool? useMetric =
          await ScenarioPreferencesService.loadBoolPreference(
        _locationChannel,
        key: _useMetricPreferenceKey,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _useMetric = useMetric ?? true;
      });
    } catch (_) {
      // Keep default (metric) if load fails.
    }
  }

  Future<void> _saveUnitPreference() async {
    try {
      await ScenarioPreferencesService.saveBoolPreference(
        _locationChannel,
        key: _useMetricPreferenceKey,
        value: _useMetric,
      );
    } catch (_) {
      // Keep local value even if persistence fails.
    }
  }

  Future<void> _loadLocationLimitUnlockedPreference() async {
    try {
      final bool? unlocked =
          await ScenarioPreferencesService.loadBoolPreference(
        _locationChannel,
        key: _locationLimitUnlockedPreferenceKey,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _locationLimitUnlocked = unlocked ?? false;
      });
    } catch (_) {
      // Keep locked by default when preference storage is unavailable.
    }
  }

  Future<void> _saveLocationLimitUnlockedPreference() async {
    try {
      await ScenarioPreferencesService.saveBoolPreference(
        _locationChannel,
        key: _locationLimitUnlockedPreferenceKey,
        value: _locationLimitUnlocked,
      );
    } catch (_) {
      // Keep local unlock state if persistence fails.
    }
  }

  void _onLocationUnlockCodeSubmitted(String rawCode) {
    final String code = rawCode.trim().toLowerCase();
    if (code != _locationLimitUnlockCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unlock code is not valid.')),
      );
      return;
    }

    if (_locationLimitUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location limit is already unlocked.')),
      );
      return;
    }

    setState(() {
      _locationLimitUnlocked = true;
    });
    unawaited(_saveLocationLimitUnlockedPreference());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location limit unlocked. You can now add more than 5.'),
      ),
    );
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
    final SiteDistance nearest = LocationTrackingCalculator.findNearestSite(
      _currentFix!,
      _sites,
    );
    if (nearest.distanceMeters > _farDistanceMeters) {
      return _farPollSeconds;
    }
    return _closePollSeconds;
  }

  String _pollingModeSummary() {
    if (_currentFix == null || _sites.isEmpty) {
      return 'close';
    }
    final SiteDistance nearest = LocationTrackingCalculator.findNearestSite(
      _currentFix!,
      _sites,
    );
    return nearest.distanceMeters > _farDistanceMeters ? 'far' : 'close';
  }

  String _pollingDebugSummary() {
    if (_isTracking) {
      return 'Position polling: ${_formatSecondsOption(_activePollSeconds())} (${_pollingModeSummary()} mode).';
    }

    if (_trackingEnabledPreference) {
      return 'Position polling should be active, but it is not currently running. Current status: $_status';
    }

    return 'Position polling is inactive. Close: ${_formatSecondsOption(_closePollSeconds)}, Far: ${_formatSecondsOption(_farPollSeconds)} beyond ${_formatMetersOption(_farDistanceMeters)}.';
  }

  List<LocationTrackingState> _buildLocationTrackingStates() {
    return LocationTrackingCalculator.buildLocationTrackingStates(
      sites: _sites,
      fix: _currentFix,
      farDistanceMeters: _farDistanceMeters,
      matchRadiusMeters: _matchRadiusMeters,
      timeInGeofenceMinutes: _timeInGeofenceMinutesBySite,
      sessionLoggedAddresses: _sessionLoggedAddresses,
      pendingSite: _pendingSite,
      candidateSite: _candidateSite,
      now: DateTime.now(),
    );
  }

  String _locationTrackingStatesDebugSummary() {
    final List<LocationTrackingState> states = _buildLocationTrackingStates();
    if (states.isEmpty) {
      return 'Location Tracking State\nNo saved locations.';
    }

    final String lines = states.map((LocationTrackingState state) {
      final String dist = state.distanceMeters == null
          ? 'no fix'
          : _fmtDist(state.distanceMeters!);
        final String timeInGeofence =
          state.timeInGeofenceMinutes.toStringAsFixed(1);
      final String remaining = state.remainingMinutes.toStringAsFixed(1);
      return '${state.name}\n'
          '  in geofence: ${state.inGeofence}  |  out: ${state.outOfGeofence}  |  far: ${state.far}  |  dist: $dist\n'
          '  time in geofence: ${timeInGeofence}m  |  remaining: ${remaining}m\n'
          '  logged: ${state.logged}  |  waiting: ${state.waitingToGetLogged}';
    }).join('\n\n');

    return 'Location Tracking State\n\n$lines';
  }

  String _rawGpsDebugSummary() {
    final String readAt = _lastRawGpsPayloadAt == null
        ? 'No payload received yet'
        : _formatLogTimestamp(_lastRawGpsPayloadAt!);

    final String errorLine = _lastRawGpsReadError == null
        ? 'Last read error: none'
        : 'Last read error: $_lastRawGpsReadError';

    final Map<Object?, Object?>? payload = _lastRawGpsPayload;
    if (payload == null || payload.isEmpty) {
      return 'Raw GPS Data\nLast payload: $readAt\n$errorLine\nPayload: empty';
    }

    final List<MapEntry<String, String>> entries = payload.entries
        .map(
          (MapEntry<Object?, Object?> entry) => MapEntry<String, String>(
            entry.key?.toString() ?? 'null',
            entry.value?.toString() ?? 'null',
          ),
        )
        .toList()
      ..sort(
        (MapEntry<String, String> a, MapEntry<String, String> b) =>
            a.key.compareTo(b.key),
      );

    final String payloadLines = entries
        .map((MapEntry<String, String> entry) => '${entry.key}: ${entry.value}')
        .join('\n');

    return 'Raw GPS Data\nLast payload: $readAt\n$errorLine\n$payloadLines';
  }

  String _trackingRuntimeStateDebugSummary() {
    final String restored = _trackingRuntimeStateLoadedAt == null
        ? 'Not restored yet'
        : _formatLogTimestamp(_trackingRuntimeStateLoadedAt!);
    final String saved = _trackingRuntimeStateSavedAt == null
        ? 'No save in this app session yet'
        : _formatLogTimestamp(_trackingRuntimeStateSavedAt!);

    return 'Runtime timing state\n'
        'Restored: $restored\n'
        'Saved: $saved\n'
        'Tracked sites this session: ${_sessionLoggedAddresses.length}\n'
      'Active geofence timers: ${_timeInGeofenceMinutesBySite.length}';
  }

  String _appReadinessDebugSummary() {
    final String lastFix =
        _lastFixAt == null ? 'none' : _formatLogTimestamp(_lastFixAt!);

    return 'App readiness\n'
        'Tracking running: $_isTracking\n'
        'Tracking preference enabled: $_trackingEnabledPreference\n'
        'Loaded flags: trackingPref=$_trackingPreferenceLoaded, runtimeState=$_trackingRuntimeStateLoaded, sites=$_sitesLoaded\n'
        'Auto-start attempted: $_autoStartTrackingAttempted\n'
        'Changing tracking state: $_isChangingTrackingState\n'
        'Fetching current location: $_isFetchingCurrentLocation\n'
        'Timers active: poll=${_trackingTimer != null}, prompt=${_promptTimer != null}\n'
        'Last accepted fix: $lastFix\n'
        'Sites: ${_sites.length}, Logs: ${_logs.length}, Deleted log keys: ${_deletedLogKeys.length}';
  }

  String _geofenceDecisionDebugSummary() {
    final LocationFix? fix = _currentFix;
    final SiteDistance? nearest = _latestNearest;
    final String nearestLine = nearest == null
        ? 'Nearest: unavailable'
        : 'Nearest: ${nearest.site.name} @ ${_fmtDist(nearest.distanceMeters)}';

    final String fixLine = fix == null
        ? 'Fix: unavailable'
        : 'Fix: acc=${_fmtAccuracy(fix.accuracyMeters)}, speed=${fix.speedMetersPerSecond.toStringAsFixed(2)} m/s';

    final String pending = _pendingSite?.name ?? 'none';
    final String candidate = _candidateSite?.name ?? 'none';

    return 'Geofence decision snapshot\n'
        '$nearestLine\n'
        '$fixLine\n'
        'Stable samples: $_stableSamples / $_requiredStableSamples\n'
        'Candidate: $candidate\n'
        'Pending prompt: $pending (countdown: $_promptCountdown s)\n'
        'Out-of-geofence timers: ${_outOfGeofenceSince.length}';
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
        !_trackingRuntimeStateLoaded ||
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
    final bool openSettings =
        await ScenarioDialogService.showTrackingOffStartupDialog(context);

    if (openSettings && mounted) {
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
      final BatteryUsageLoadResult result =
          await BatteryUsageService.loadBatteryUsage(_locationChannel);

      if (!mounted) {
        return;
      }

      setState(() {
        _usageAccessGranted = result.usageAccessGranted;
        _batteryUsage = result.batteryUsage;
        _deviceBatteryLevel = result.deviceBatteryLevel;
        _batteryUsageFetchedAt = result.batteryUsageFetchedAt;
        _batteryUsageError = result.errorMessage;
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
    final UsageAccessSettingsOpenResult result =
        await BatteryUsageService.openUsageAccessSettings(_locationChannel);
    if (!mounted) {
      return;
    }

    if (result == UsageAccessSettingsOpenResult.openedUsageAccessSettings) {
      return;
    }

    if (result == UsageAccessSettingsOpenResult.openedAppSettingsFallback) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Usage Access settings unavailable on this device. Opened app settings instead.',
          ),
        ),
      );
      return;
    }

    if (result == UsageAccessSettingsOpenResult.failed) {
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
        final int timestampMillis = ((item['timestamp'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch);
        return JobLog(
          name: (item['name'] ?? item['siteName'] ?? item['address'] ?? '')
              .toString(),
          address: (item['address'] ?? '').toString(),
          notes: (item['notes'] ?? '').toString(),
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

      setState(() {
        _state.mergeLoadedLogs(loadedLogs);
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
      final String? raw = await ScenarioPreferencesService.loadStringPreference(
        _locationChannel,
        key: _deletedLogKeysPreferenceKey,
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
      await ScenarioPreferencesService.saveStringPreference(
        _locationChannel,
        key: _deletedLogKeysPreferenceKey,
        value: jsonEncode(_deletedLogKeys.toList()),
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
    final bool hasLocationAccess = await _ensureLocationAccess();
    if (!hasLocationAccess || !mounted) {
      return;
    }

    // Resume persisted runtime timing state instead of resetting on restart.
    _stableSamples = 0;
    _candidateSite = null;
    _pendingSite = null;
    _latestNearest = null;
    _promptCountdown = 0;
    _lastFixAt = null;
    _promptTimer?.cancel();
    _isTracking = true;
    _status = _sites.isEmpty
        ? 'Tracking started. No locations configured yet. Add locations from the Locations tab.'
        : 'Tracking started. Reading live GPS signal...';

    _scheduleNextPoll(immediate: true);
    setState(() {});
    unawaited(_saveTrackingRuntimeState());
  }

  Future<void> _onTrackingToggleChanged(bool enabled) async {
    if (_isChangingTrackingState) {
      return;
    }

    setState(() {
      _isChangingTrackingState = true;
    });

    if (enabled) {
      try {
        await _saveTrackingPreference(true);
        await _startScenario();

        if (!_isTracking && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not start tracking: $_status')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isChangingTrackingState = false;
          });
        } else {
          _isChangingTrackingState = false;
        }
      }
      return;
    }

    try {
      if (!_isTracking) {
        await _saveTrackingPreference(false);
        return;
      }

      final bool shouldStop =
          await ScenarioDialogService.confirmStopTracking(context);
      if (shouldStop) {
        _stopScenario();
        await _saveTrackingPreference(false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChangingTrackingState = false;
        });
      } else {
        _isChangingTrackingState = false;
      }
    }
  }

  Future<bool> _ensureLocationAccess() async {
    if (!Platform.isAndroid) {
      setState(() {
        _status = 'Native GPS is implemented for Android in this build.';
      });
      return false;
    }

    final bool serviceEnabled =
        await LocationPermissionService.isLocationServiceEnabled(
      _locationChannel,
    );

    if (!serviceEnabled) {
      setState(() {
        _status = 'Location services are off. Turn on GPS and try again.';
      });
      final bool shouldOpen =
          await ScenarioDialogService.showGoToSettingsDialog(
        context,
        title: 'Location Services Off',
        message: 'GPS is turned off. Open Location settings now?',
      );
      if (shouldOpen) {
        await _openLocationSettings();
      }
      return false;
    }

    final bool granted =
        await LocationPermissionService.checkAndRequestPermission(
      _locationChannel,
    );
    if (!granted) {
      setState(() {
        _status =
            'Location permission denied. Allow location access to start tracking.';
      });
      final bool shouldOpen =
          await ScenarioDialogService.showGoToSettingsDialog(
        context,
        title: 'Location Permission Needed',
        message:
            'Location permission is required. Open app permission settings now?',
      );
      if (shouldOpen) {
        await _openAppSettings();
      }
      return false;
    }

    final bool backgroundGranted =
        await LocationPermissionService.hasBackgroundLocationPermission(
      _locationChannel,
    );
    if (!backgroundGranted) {
      setState(() {
        _status =
            'For app-closed geofencing, set Location permission to "Allow all the time" in Android settings.';
      });
      final bool shouldOpen =
          await ScenarioDialogService.showGoToSettingsDialog(
        context,
        title: 'Background Location Needed',
        message:
            'To log when the app is closed, set Location to "Allow all the time". Open app settings now?',
      );
      if (shouldOpen) {
        await _openAppSettings();
      }
      return false;
    }

    return true;
  }

  Future<void> _openLocationSettings() async {
    try {
      await LocationPermissionService.openLocationSettings(_locationChannel);
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
      await LocationPermissionService.openAppSettings(_locationChannel);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open App settings.')),
      );
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
          .timeout(_gpsReadTimeout);

      if (!_isTracking || !mounted) {
        return;
      }

      setState(() {
        _lastRawGpsPayload =
            position == null ? null : Map<Object?, Object?>.from(position);
        _lastRawGpsPayloadAt = DateTime.now();
        _lastRawGpsReadError = null;
      });

      final double? lat = (position?['latitude'] as num?)?.toDouble();
      final double? lng = (position?['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) {
        setState(() {
          _status = 'GPS payload missing latitude or longitude.';
        });
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
    } on TimeoutException {
      if (!mounted || !_isTracking) {
        return;
      }
      setState(() {
        _lastRawGpsReadError = 'timeout after ${_gpsReadTimeout.inSeconds}s';
        _status =
            'GPS read timed out. Move outdoors for clearer sky view and try again.';
      });
    } on PlatformException catch (error) {
      if (!mounted || !_isTracking) {
        return;
      }
      setState(() {
        _lastRawGpsReadError =
            '${error.code}: ${error.message ?? 'unknown error'}';
        _status =
            'GPS error (${error.code}): ${error.message ?? 'unknown error'}';
      });
    } catch (_) {
      if (!mounted || !_isTracking) {
        return;
      }
      setState(() {
        _lastRawGpsReadError = 'unexpected read failure';
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
    unawaited(_saveTrackingRuntimeState());
  }

  void _refreshNearestUiFromCurrentFix() {
    final LocationFix? fix = _currentFix;
    if (!mounted || fix == null || _sites.isEmpty) {
      return;
    }

    final SiteDistance nearest = LocationTrackingCalculator.findNearestSite(
      fix,
      _sites,
    );
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
    unawaited(_saveTrackingRuntimeState());
  }

  void _onSitesChanged() {
    _state.pruneTrackingStateToKnownSites();

    if (_sites.isEmpty) {
      _latestNearest = null;
    } else {
      _refreshNearestUiFromCurrentFix();
    }

    if (_isTracking) {
      _scheduleNextPoll(immediate: true);
    }
    unawaited(_saveTrackingRuntimeState());
  }

  void _processFix(LocationFix fix) {
    final DateTime now = DateTime.now();
    final TrackingProcessResult result = TrackingController.processFix(
      fix: fix,
      now: now,
      lastFixAt: _lastFixAt,
      sites: _sites,
      sessionLoggedAddresses: _sessionLoggedAddresses,
      timeInGeofenceMinutes: _timeInGeofenceMinutesBySite,
      outOfGeofenceSince: _outOfGeofenceSince,
      outOfGeofenceRetriggerMinutes: _outOfGeofenceRetriggerMinutes,
      matchRadiusMeters: _matchRadiusMeters,
      maxAccuracyMeters: _maxAccuracyMeters,
      maxSpeedForDwell: _maxSpeedForDwell,
      requiredStableSamples: _requiredStableSamples,
      currentCandidateSite: _candidateSite,
      currentStableSamples: _stableSamples,
      pendingSite: _pendingSite,
    );
    _lastFixAt = now;

    if (_sites.isEmpty) {
      setState(() {
        _currentFix = result.currentFix;
        _candidateSite = result.candidateSite;
        _stableSamples = result.stableSamples;
      });
      return;
    }

    setState(() {
      _currentFix = result.currentFix;
      _candidateSite = result.candidateSite;
      _stableSamples = result.stableSamples;
      _latestNearest = result.latestNearest;
      _status = _buildStatusText(
        nearest: result.latestNearest!,
        goodAccuracy: result.goodAccuracy,
        lowSpeed: result.lowSpeed,
        inGeofence: result.inGeofence,
        effectiveRadius: result.effectiveRadiusMeters,
        hideNearestDetails: _shouldHideNearestInfo(result.latestNearest!),
      );
    });

    // Check whether the candidate has now met the dwell target.
    if (result.shouldPrompt && result.promptSite != null) {
      _showConfirmationPrompt(result.promptSite!);
    }
  }

  double _minutesRemainingToLog(JobSite site) {
    return LocationTrackingCalculator.minutesRemainingToLog(
      site,
      _timeInGeofenceMinutesBySite,
    );
  }

  void _showConfirmationPrompt(JobSite site) {
    setState(() {
      _pendingSite = site;
      _promptCountdown = 12;
    });
    _promptTimer?.cancel();
    unawaited(_showLogReminderNotification(site, _promptCountdown));
    _promptTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_pendingSite == null) {
        timer.cancel();
        return;
      }
      if (_promptCountdown <= 1) {
        _logJob(site, confirmedByUser: false, autoLogged: true);
        timer.cancel();
      } else {
        setState(() {
          _promptCountdown -= 1;
        });
      }
    });
  }

  void _dismissPendingPrompt() {
    if (_pendingSite == null) {
      return;
    }
    _promptTimer?.cancel();
    unawaited(_cancelLogReminderNotification());
    setState(() {
      _pendingSite = null;
      _promptCountdown = 0;
      _status = 'Log reminder dismissed.';
    });
  }

  void _logJob(
    JobSite site, {
    required bool confirmedByUser,
    required bool autoLogged,
    String notes = '',
  }) {
    final LocationFix? fix = _currentFix;
    if (fix == null) {
      return;
    }

    final String cleanNotes = notes.trim();

    _state.addLog(
      JobLog(
        name: site.name,
        address: site.address,
        notes: cleanNotes,
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
    unawaited(_saveTrackingRuntimeState());
  }

  void _debugRetriggerCurrentSite() {
    if (_pendingSite != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A log reminder is already active.')),
        );
      }
      setState(() {
        _status = 'A log reminder is already active.';
      });
      return;
    }

    final LocationFix? fix = _currentFix;
    if (fix == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No GPS fix yet. Wait for location first.'),
          ),
        );
      }
      setState(() {
        _status = 'No GPS fix yet. Wait for location before retrigger.';
      });
      return;
    }

    final JobSite? site = _candidateSite ?? _latestNearest?.site;
    if (site == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No nearby site available to retrigger.')),
        );
      }
      setState(() {
        _status = 'No nearby site available to retrigger.';
      });
      return;
    }

    setState(() {
      _sessionLoggedAddresses.remove(site.address);
      _outOfGeofenceSince.remove(site.address);
      _timeInGeofenceMinutesBySite[site.address] = 0;
      _stableSamples = 0;
      _candidateSite = site;
      _status =
          'Retrigger restarted for ${site.address}. Stay in geofence for ${site.requiredDwellMinutes} min to log again.';
    });
    unawaited(_saveTrackingRuntimeState());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Timer restarted for ${site.name}. Dwell will build from 0.',
          ),
        ),
      );
    }

    if (_isTracking) {
      _scheduleNextPoll(immediate: true);
    }
  }

  double _confidenceScore(LocationFix fix, JobSite site) {
    return LocationTrackingCalculator.confidenceScore(fix, site);
  }

  String _buildStatusText({
    required SiteDistance nearest,
    required bool goodAccuracy,
    required bool lowSpeed,
    required bool inGeofence,
    required double effectiveRadius,
    required bool hideNearestDetails,
  }) {
    final double timeInGeofence =
      _timeInGeofenceMinutesBySite[nearest.site.address] ?? 0;
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
      'time in geofence: ${timeInGeofence.toStringAsFixed(1)} min | '
        'remaining: ${remaining.toStringAsFixed(1)} min | '
        'accuracy: $accuracyLabel | '
        'motion: ${lowSpeed ? 'stationary' : 'moving'} | '
        'geofence: ${inGeofence ? 'inside' : 'outside'} '
        '(${_fmtDist(nearest.distanceMeters, decimals: 0)}/${_fmtDist(effectiveRadius, decimals: 0)})';
  }

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

  Future<void> _shareLogEntry(JobLog log) async {
    await LogCommunicationService.shareLogEntry(
      context: context,
      channel: _locationChannel,
      log: log,
      formatLogTimestamp: _formatLogTimestamp,
    );
  }

  Future<void> _shareAllLogs() async {
    await LogCommunicationService.shareAllLogs(
      context: context,
      channel: _locationChannel,
      logs: _logs,
      formatLogTimestamp: _formatLogTimestamp,
    );
  }

  Future<void> _showLogReminderNotification(JobSite site, int countdown) async {
    await LogCommunicationService.showLogReminderNotification(
      channel: _locationChannel,
      site: site,
      countdown: countdown,
    );
  }

  Future<void> _cancelLogReminderNotification() async {
    await LogCommunicationService.cancelLogReminderNotification(
      channel: _locationChannel,
    );
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

  bool _hasMissingRequiredLocationFields(AddLocationInput input) {
    return input.name.trim().isEmpty ||
        input.street.trim().isEmpty ||
        input.city.trim().isEmpty ||
        input.state.trim().isEmpty ||
        input.zip.trim().isEmpty;
  }

  bool _hasReachedLocationLimit() {
    return !_locationLimitUnlocked && _sites.length >= _maxSavedLocations;
  }

  String _locationLimitReachedMessage() {
    return 'Only $_maxSavedLocations locations are allowed. Enter unlock code in Settings to add more.';
  }

  bool _isDuplicateLocationName(String name, {int? excludingIndex}) {
    return _state.isDuplicateLocationName(
      name,
      excludingIndex: excludingIndex,
    );
  }

  Future<void> _onAddNewLocation() async {
    if (_hasReachedLocationLimit()) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_locationLimitReachedMessage()),
        ),
      );
      return;
    }

    AddLocationInput? prefill;
    String? sheetError;

    while (true) {
      final AddLocationInput? result =
          await showModalBottomSheet<AddLocationInput>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext sheetContext) {
          return AddLocationSheet(
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

      if (_isDuplicateLocationName(result.name)) {
        prefill = result;
        sheetError = 'Location name already exists. Please use a unique name.';
        continue;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Looking up latitude/longitude...')),
      );

      final GeocodePoint? point =
          await LocationGeocodingService.lookupCoordinates(
        result,
      );
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
        name: result.name.trim(),
        street: result.street,
        city: result.city,
        state: result.state,
        zip: result.zip,
        lat: point.lat,
        lng: point.lng,
        requiredDwellMinutes: result.requiredMinutes,
      );

      if (_hasReachedLocationLimit()) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_locationLimitReachedMessage()),
          ),
        );
        return;
      }

      setState(() {
        _state.addSite(newSite);
      });
      unawaited(_saveSites());
      _onSitesChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added location: ${newSite.name} (${result.requiredMinutes}m).',
          ),
        ),
      );
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
          .timeout(_gpsReadTimeout);
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

  Future<void> _onAddFromCurrentLocation() async {
    if (_hasReachedLocationLimit() || _isFetchingCurrentLocation) {
      if (!mounted) {
        return;
      }
      if (_hasReachedLocationLimit()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_locationLimitReachedMessage()),
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
    final AddLocationInput? reversePrefill =
        await LocationGeocodingService.reverseLookupAddress(
      fix,
      defaultRequiredMinutes:
          _logMinuteOptions.contains(20) ? 20 : _logMinuteOptions.first,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    AddLocationInput? prefill = reversePrefill ??
        AddLocationInput(
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
      final AddLocationInput? result =
          await showModalBottomSheet<AddLocationInput>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext sheetContext) {
          return AddLocationSheet(
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

      if (_isDuplicateLocationName(result.name)) {
        prefill = result;
        sheetError = 'Location name already exists. Please use a unique name.';
        continue;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verifying address coordinates...')),
      );
      final GeocodePoint? point =
          await LocationGeocodingService.lookupCoordinates(
        result,
      );
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

      if (_hasReachedLocationLimit()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_locationLimitReachedMessage()),
          ),
        );
        setState(() {
          _isFetchingCurrentLocation = false;
        });
        return;
      }

      final JobSite newSite = JobSite(
        name: result.name.trim(),
        street: result.street,
        city: result.city,
        state: result.state,
        zip: result.zip,
        lat: point.lat,
        lng: point.lng,
        requiredDwellMinutes: result.requiredMinutes,
      );

      setState(() {
        _state.addSite(newSite);
        _isFetchingCurrentLocation = false;
      });
      unawaited(_saveSites());
      _onSitesChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added location from current GPS: ${newSite.name} (${result.requiredMinutes}m).',
          ),
        ),
      );
      return;
    }
  }

  Future<void> _onEditLocation(int index, JobSite site) async {
    AddLocationInput? prefill = AddLocationInput(
      name: site.name,
      street: site.street,
      city: site.city,
      state: site.state,
      zip: site.zip,
      requiredMinutes: site.requiredDwellMinutes,
    );
    String? sheetError;

    while (true) {
      final AddLocationInput? result =
          await showModalBottomSheet<AddLocationInput>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext sheetContext) {
          return AddLocationSheet(
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

      if (_isDuplicateLocationName(result.name, excludingIndex: index)) {
        prefill = result;
        sheetError = 'Location name already exists. Please use a unique name.';
        continue;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Looking up updated latitude/longitude...')),
      );

      final GeocodePoint? point =
          await LocationGeocodingService.lookupCoordinates(
        result,
      );
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
        name: result.name.trim(),
        street: result.street,
        city: result.city,
        state: result.state,
        zip: result.zip,
        lat: point.lat,
        lng: point.lng,
        requiredDwellMinutes: result.requiredMinutes,
      );

      setState(() {
        _state.updateSite(index, updatedSite);
      });
      unawaited(_saveSites());
      _onSitesChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Updated location: ${updatedSite.name} (${result.requiredMinutes}m).',
          ),
        ),
      );
      return;
    }
  }

  Future<void> _onDeleteLocation(int index, JobSite site) async {
    final bool confirmDelete =
        await ScenarioDialogService.confirmDeleteLocation(
      context,
      siteName: site.name,
    );

    if (!confirmDelete || !mounted) {
      return;
    }

    setState(() {
      _state.removeSiteAt(index);
    });
    unawaited(_saveSites());
    _onSitesChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted location: ${site.name}.')),
    );
  }

  Future<void> _onResetAllSites() async {
    if (_sites.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No sites to reset.')),
      );
      return;
    }

    final bool shouldReset =
        await ScenarioDialogService.confirmResetAllSites(context);

    if (!shouldReset || !mounted) {
      return;
    }

    if (_isTracking) {
      _stopScenario();
    }

    setState(() {
      _state.clearSites();
      _latestNearest = null;
      _candidateSite = null;
      _pendingSite = null;
      _promptCountdown = 0;
      _state.clearTrackingRuntimeState();
      _status =
          'All locations were reset. Add locations from the Locations tab.';
    });

    unawaited(_saveSites());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All saved locations were reset.')),
    );
  }

  Future<void> _onDeleteLogEntry(int index, JobLog log) async {
    final bool confirmDelete =
        await ScenarioDialogService.confirmDeleteLogEntry(
      context,
      address: log.address,
    );

    if (!confirmDelete || !mounted) {
      return;
    }

    final String deletedKey = _logStorageKey(
      address: log.address,
      timestampMillis: log.timestamp.millisecondsSinceEpoch,
    );
    _state.addDeletedLogKey(deletedKey);
    unawaited(_saveDeletedLogKeys());

    setState(() {
      _state.removeLogAt(index);
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

  Future<void> _onEditLogEntry(int index, JobLog log) async {
    final String? updatedNotes = await ScenarioDialogService.editLogNotes(
      context,
      initialNotes: log.notes,
    );

    if (updatedNotes == null || !mounted) {
      return;
    }

    setState(() {
      _state.updateLogNotes(index, updatedNotes);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Log notes updated.')),
    );
  }

  Widget _buildLogScreen() {
    return LogScreenView(
      statusText: _status,
      currentFix: _currentFix,
      latestNearest: _latestNearest,
      pendingSite: _pendingSite,
      promptCountdown: _promptCountdown,
      logs: _logs,
      formatLogTimestamp: _formatLogTimestamp,
      buildNearestMessage: (SiteDistance nearest) {
        if (_shouldHideNearestInfo(nearest)) {
          return 'Nearest location is currently far (${_fmtDist(nearest.distanceMeters)}). Move closer to start countdown.';
        }
        return 'Countdown to log ${nearest.site.name}: '
            '${_minutesRemainingToLog(nearest.site).toStringAsFixed(1)} minutes remaining';
      },
      onDismissPendingPrompt: _dismissPendingPrompt,
      onLogNow: (JobSite site) {
        _logJob(
          site,
          confirmedByUser: true,
          autoLogged: false,
        );
      },
      onShareAllLogs: _shareAllLogs,
      onShareLogEntry: _shareLogEntry,
      onEditLogEntry: _onEditLogEntry,
      onDeleteLogEntry: _onDeleteLogEntry,
    );
  }

  Widget _buildSettingsScreen() {
    return SettingsScreenView(
      debugModeEnabled: _debugModeEnabled,
      onDebugModeChanged: (bool enabled) {
        setState(() {
          _debugModeEnabled = enabled;
          if (!_debugModeEnabled && _selectedTabIndex == 3) {
            _selectedTabIndex = 2;
          }
        });
        unawaited(
          ScenarioPreferencesService.saveBoolPreference(
            _locationChannel,
            key: _debugModePreferenceKey,
            value: enabled,
          ),
        );
      },
      isDarkMode: widget.isDarkMode,
      onDarkModeChanged: widget.onDarkModeChanged,
      useMetric: _useMetric,
      onUseMetricChanged: (bool value) {
        setState(() {
          _useMetric = value;
        });
        unawaited(_saveUnitPreference());
        _refreshNearestUiFromCurrentFix();
      },
      fontScale: widget.fontScale,
      minFontScale: widget.minFontScale,
      maxFontScale: widget.maxFontScale,
      fontScaleStep: widget.fontScaleStep,
      onFontScaleChanged: widget.onFontScaleChanged,
      isTracking: _isTracking,
      trackingEnabledPreference: _trackingEnabledPreference,
      isChangingTrackingState: _isChangingTrackingState,
      status: _status,
      trackingSummary: _isTracking
          ? 'Current polling: ${_formatSecondsOption(_activePollSeconds())} (${_pollingModeSummary()} mode).'
          : 'Close polling uses ${_formatSecondsOption(_closePollSeconds)}. Far polling uses ${_formatSecondsOption(_farPollSeconds)} beyond ${_formatMetersOption(_farDistanceMeters)}.',
      onTrackingToggleChanged: (bool value) {
        unawaited(_onTrackingToggleChanged(value));
      },
      closePollSeconds: _closePollSeconds,
      farPollSeconds: _farPollSeconds,
      farDistanceMeters: _farDistanceMeters,
      outOfGeofenceRetriggerMinutes: _outOfGeofenceRetriggerMinutes,
      closePollSecondOptions: _closePollSecondOptions,
      farPollSecondOptions: _farPollSecondOptions,
      farDistanceMeterOptions: _farDistanceMeterOptions,
      outOfGeofenceRetriggerMinuteOptions: _outOfGeofenceRetriggerMinuteOptions,
      hideNearestWhenFar: _hideNearestWhenFar,
      onClosePollSecondsChanged: (int value) {
        setState(() {
          _closePollSeconds = value;
        });
        unawaited(_savePollingPreferences());
        if (_isTracking) {
          _scheduleNextPoll(immediate: true);
        }
        _refreshNearestUiFromCurrentFix();
      },
      onFarPollSecondsChanged: (int value) {
        setState(() {
          _farPollSeconds = value;
        });
        unawaited(_savePollingPreferences());
        if (_isTracking) {
          _scheduleNextPoll(immediate: true);
        }
        _refreshNearestUiFromCurrentFix();
      },
      onFarDistanceMetersChanged: (int value) {
        setState(() {
          _farDistanceMeters = value;
        });
        unawaited(_savePollingPreferences());
        if (_isTracking) {
          _scheduleNextPoll(immediate: true);
        }
        _refreshNearestUiFromCurrentFix();
      },
      onOutOfGeofenceRetriggerMinutesChanged: (int value) {
        setState(() {
          _outOfGeofenceRetriggerMinutes = value;
        });
        unawaited(_savePollingPreferences());
        _refreshNearestUiFromCurrentFix();
      },
      onHideNearestWhenFarChanged: (bool value) {
        setState(() {
          _hideNearestWhenFar = value;
        });
        unawaited(_savePollingPreferences());
        _refreshNearestUiFromCurrentFix();
      },
      formatSecondsOption: _formatSecondsOption,
      formatMetersOption: _formatMetersOption,
      onOpenLocationSettings: _openLocationSettings,
      onOpenAppSettings: _openAppSettings,
      locationLimitUnlocked: _locationLimitUnlocked,
      onLocationUnlockCodeSubmitted: _onLocationUnlockCodeSubmitted,
    );
  }

  Widget _buildLocationsScreen() {
    return Column(
      children: <Widget>[
        Expanded(
          child: LocationsScreenView(
            sites: _sites,
            onResetAllSites: _onResetAllSites,
            onEditLocation: _onEditLocation,
            onDeleteLocation: _onDeleteLocation,
          ),
        ),
        SafeArea(
          top: false,
          child: Material(
            elevation: 8,
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _hasReachedLocationLimit() ||
                              _isFetchingCurrentLocation
                          ? null
                          : () async {
                              final bool shouldContinue =
                                  await ScenarioDialogService
                                      .confirmAddLocationAction(
                                context,
                                useCurrentLocation: true,
                              );
                              if (!shouldContinue) {
                                return;
                              }
                              await _onAddFromCurrentLocation();
                            },
                      icon: _isFetchingCurrentLocation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.my_location),
                      label: const Text('Current Location'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _hasReachedLocationLimit()
                          ? null
                          : () async {
                              final bool shouldContinue =
                                  await ScenarioDialogService
                                      .confirmAddLocationAction(
                                context,
                                useCurrentLocation: false,
                              );
                              if (!shouldContinue) {
                                return;
                              }
                              await _onAddNewLocation();
                            },
                      icon: const Icon(Icons.add_location_alt),
                      label: Text(
                        _hasReachedLocationLimit()
                            ? 'Limit Reached'
                            : 'Add New',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDebugScreen() {
    return DebugScreenView(
      appVersionLabel: _appVersionLabel,
      showBatteryInfo: _showBatteryInfo,
      onShowBatteryInfoChanged: _setShowBatteryInfo,
      pollingDebugSummary: _pollingDebugSummary(),
      appReadinessDebugSummary: _appReadinessDebugSummary(),
      geofenceDecisionDebugSummary: _geofenceDecisionDebugSummary(),
      rawGpsDebugSummary: _rawGpsDebugSummary(),
      trackingRuntimeStateDebugSummary: _trackingRuntimeStateDebugSummary(),
      locationTrackingStatesDebugSummary: _locationTrackingStatesDebugSummary(),
      onRetriggerCurrentSite: _debugRetriggerCurrentSite,
      isLoadingBatteryUsage: _isLoadingBatteryUsage,
      onRefreshBatteryUsage: _loadBatteryUsage,
      onOpenUsageAccessSettings: _openUsageAccessSettings,
      usageAccessGranted: _usageAccessGranted,
      deviceBatteryLevel: _deviceBatteryLevel,
      batteryUsageFetchedAt: _batteryUsageFetchedAt,
      batteryUsageError: _batteryUsageError,
      batteryUsage: _batteryUsage,
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
