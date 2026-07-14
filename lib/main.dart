import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'constants/app_constants.dart';
import 'controllers/app_preferences_manager.dart';
import 'models/geofence_location_state.dart';
import 'models/gps_fix_state.dart';
import 'models/lokalog_models.dart';
import 'models/tracking_state.dart';
import 'services/battery_usage_service.dart';
import 'services/geofence_calculator.dart';
import 'services/log_entry_actions_controller.dart';
import 'services/location_permission_service.dart';
import 'services/log_communication_service.dart';
import 'services/location_add_workflow_controller.dart';
import 'services/location_tracking_calculator.dart';
import 'services/scenario_dialog_service.dart';
import 'services/scenario_preferences_service.dart';
import 'services/scenario_state_controller.dart';
import 'services/tracking_access_controller.dart';
import 'services/tracking_controller.dart';
import 'services/ui_feedback_service.dart';
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
  static const double _maxFontScale = 1.5;
  static const double _fontScaleStep = 0.1;
  ThemeMode _themeMode = ThemeMode.light;
  double _fontScale = 1.0;

  ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0D1515) : const Color(0xFFF4FAF9),
      cardTheme: CardThemeData(
        elevation: isDark ? 0 : 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        color: isDark ? const Color(0xFF152222) : Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1D2B2B) : const Color(0xFFF7FBFA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (Set<WidgetState> states) {
            final bool selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            );
          },
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
      ),
    );
  }

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
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
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

class _ScenarioPageState extends State<ScenarioPage>
    with WidgetsBindingObserver {
  static const MethodChannel _locationChannel =
      MethodChannel('lokalog/location');
  
  // Storage keys for background log tracking
  static const String _sitesStorageKey = 'saved_job_sites_v1';
  static const String _deletedLogKeysPreferenceKey =
      'deleted_background_log_keys_v1';
  static const String _calendarAddedLogKeysPreferenceKey =
      'calendar_added_log_keys_v1';

  // New controllers and managers
  late AppPreferencesManager _prefsManager;
  late GeofenceCalculator _geofenceCalc;

  final ScenarioStateController _state = ScenarioStateController();
  
  // Grouped state objects for better organization
  late TrackingState _tracking;
  late GeofenceLocationState _geofence;
  late GPSFixState _gpsState;
  
  // Background log tracking load flags
  bool _deletedLogKeysLoaded = false;
  bool _calendarAddedLogKeysLoaded = false;
  
  // Startup and lifecycle flags (continued)
  int _selectedTabIndex = 0;
  bool _isChangingTrackingState = false;
  bool _isFetchingCurrentLocation = false;
  bool _backgroundLocationPermissionGranted = false;

  // Startup and lifecycle flags
  bool _autoStartTrackingAttempted = false;
  bool _trackingOffStartupDialogShown = false;
  bool _trackingPreferenceLoaded = false;
  bool _trackingRuntimeStateLoaded = false;
  bool _sitesLoaded = false;

  // Battery usage display
  bool _isLoadingBatteryUsage = false;
  bool _usageAccessGranted = false;
  String? _batteryUsageError;
  int? _deviceBatteryLevel;
  DateTime? _batteryUsageFetchedAt;
  List<DebugBatteryAppUsage> _batteryUsage = <DebugBatteryAppUsage>[];

  // App version info
  static const String _fallbackVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: '1.0.1');
  static const String _fallbackBuildNumber =
      String.fromEnvironment('APP_BUILD_NUMBER', defaultValue: '3');
  String _appVersionLabel = '$_fallbackVersion ($_fallbackBuildNumber)';

  // Preference values (loaded via _prefsManager)
  bool _debugModeEnabled = false;
  bool _showBatteryInfo = true;
  int _closePollSeconds = AppConstants.closePollSeconds;
  int _farPollSeconds = AppConstants.farPollSeconds;
  int _farDistanceMeters = AppConstants.farDistanceMeters;
  int _inGeofenceDistanceMeters = AppConstants.inGeofenceDistanceMeters;
  int _outOfGeofenceRetriggerMinutes = AppConstants.outOfGeofenceRetriggerMinutes;
  bool _hideNearestWhenFar = true;
  bool _useMetric = true;
  bool _trackingEnabledPreference = true;
  bool _locationLimitUnlocked = false;

  // Geofence and logging state - now using GeofenceLocationState
  final double _maxAccuracyMeters = AppConstants.maxAccuracyMeters;
  final double _maxSpeedForDwell = AppConstants.maxSpeedForDwell;
  final int _requiredStableSamples = AppConstants.requiredStableSamples;
  final List<int> _logMinuteOptions = AppConstants.logMinuteOptions;

  // Preference keys
  static const String _debugModePreferenceKey = 'debug_mode_enabled';

  List<JobSite> get _sites => _state.sites;
  List<JobLog> get _logs => _state.logs;
  Set<String> get _deletedLogKeys => _state.deletedLogKeys;
  Set<String> get _calendarAddedLogKeys => _state.calendarAddedLogKeys;
  Set<String> get _sessionLoggedAddresses => _state.sessionLoggedAddresses;
  Map<String, double> get _timeInGeofenceMinutesBySite =>
      _state.timeInGeofenceMinutes;
  Map<String, DateTime> get _outOfGeofenceSince => _state.outOfGeofenceSince;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize grouped state objects
    _tracking = TrackingState();
    _geofence = GeofenceLocationState();
    _gpsState = GPSFixState();
    
    // Initialize managers
    _prefsManager = AppPreferencesManager(_locationChannel);
    _geofenceCalc = GeofenceCalculator(
      inGeofenceDistanceMeters: _inGeofenceDistanceMeters.toDouble(),
    );
    
    _initializeAppVersionLabel();
    _initializeManagers();
  }

  /// Initializes preference and state managers on app startup.
  /// Loads all persisted preferences asynchronously without blocking UI.
  Future<void> _initializeManagers() async {
    unawaited(_loadDebugMode());
    unawaited(_loadPollingPreferences());
    unawaited(_loadUnitPreference());
    unawaited(_loadTrackingPreference());
    unawaited(_loadLocationLimitUnlockedPreference());
    unawaited(_refreshBackgroundLocationPermissionStatus());
    unawaited(_loadTrackingRuntimeState());
    unawaited(_loadSites());
  }

  // ============================================================================
  // LIFECYCLE & PERMISSIONS: App startup, permissions, and location services
  // ============================================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_saveTrackingRuntimeState());
      return;
    }

    if (state == AppLifecycleState.resumed) {
      unawaited(_loadBackgroundLogs());
    }
  }

  // ============================================================================
  // GROUPED STATE ACCESSORS: Provide DebugMixin access to grouped state objects
  // ============================================================================

  bool get isTracking => _tracking.isTracking;

  String get status => _tracking.status;

  int get stableSamples => _tracking.stableSamples;

  DateTime? get lastFixAt => _tracking.lastFixAt;

  DateTime? get trackingRuntimeStateLoadedAt => _tracking.trackingRuntimeStateLoadedAt;

  DateTime? get trackingRuntimeStateSavedAt => _tracking.trackingRuntimeStateSavedAt;

  LocationFix? get currentFix => _gpsState.currentFix;

  SiteDistance? get latestNearest => _gpsState.latestNearest;

  Map<Object?, Object?>? get lastRawGpsPayload => _gpsState.lastRawGpsPayload;

  DateTime? get lastRawGpsPayloadAt => _gpsState.lastRawGpsPayloadAt;

  String? get lastRawGpsReadError => _gpsState.lastRawGpsReadError;

  JobSite? get candidateSite => _geofence.candidateSite;

  JobSite? get pendingSite => _geofence.pendingSite;

  int get promptCountdown => _geofence.promptCountdown;

  int get requiredStableSamples => _requiredStableSamples;

  int get closePollSeconds => _closePollSeconds;

  int get farPollSeconds => _farPollSeconds;

  Map<String, double> get timeInGeofenceMinutesBySite =>
      _state.timeInGeofenceMinutes;

  Map<String, DateTime> get outOfGeofenceSince => _state.outOfGeofenceSince;

  // ============================================================================
  // PREFERENCES: Loading and saving user preferences
  // ============================================================================

  Future<void> _refreshBackgroundLocationPermissionStatus() async {
    if (!Platform.isAndroid) {
      if (!mounted) {
        return;
      }
      setState(() {
        _backgroundLocationPermissionGranted = false;
      });
      return;
    }

    final bool granted =
        await LocationPermissionService.hasBackgroundLocationPermission(
      _locationChannel,
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _backgroundLocationPermissionGranted = granted;
    });
    if (granted && _trackingEnabledPreference) {
      await _syncBackgroundGeofences();
      return;
    }
    await _clearBackgroundGeofences();
  }

  // ============================================================================
  // ANDROID INTEGRATION: Geofence sync and native platform channel calls
  // ============================================================================

  Future<void> _syncBackgroundGeofences() async {
    try {
      await LocationPermissionService.syncBackgroundGeofences(_locationChannel);
    } catch (_) {
      // Keep app flow even if native geofence sync fails.
    }
  }

  Future<void> _clearBackgroundGeofences() async {
    try {
      await LocationPermissionService.clearBackgroundGeofences(_locationChannel);
    } catch (_) {
      // Keep app flow even if native geofence clear fails.
    }
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

  /// Load tracking enabled preference and sync geofences accordingly.
  /// When preference loads, background geofences are synced if enabled,
  /// or cleared if disabled. Auto-start is triggered if conditions are met.
  Future<void> _loadTrackingPreference() async {
    final bool enabled = await _prefsManager.loadTrackingEnabled();
    if (!mounted) {
      return;
    }
    setState(() {
      _trackingEnabledPreference = enabled;
      _trackingPreferenceLoaded = true;
    });
    if (_trackingEnabledPreference) {
      await _syncBackgroundGeofences();
    } else {
      await _clearBackgroundGeofences();
    }
    _maybeAutoStartTracking();
  }

  Future<void> _saveTrackingPreference(bool enabled) async {
    _trackingEnabledPreference = enabled;
    await _prefsManager.saveTrackingEnabled(enabled);
    if (enabled) {
      await _syncBackgroundGeofences();
    } else {
      await _clearBackgroundGeofences();
    }
  }

  Future<void> _loadTrackingRuntimeState() async {
    final Map<String, dynamic>? state =
        await _prefsManager.loadTrackingRuntimeState();

    if (state != null && state.isNotEmpty) {
      _state.restoreTrackingRuntimeStateFromJson(state);
      if (mounted) {
        setState(() {
          _trackingRuntimeStateLoaded = true;
          _tracking.trackingRuntimeStateLoadedAt = DateTime.now();
        });
      } else {
        _trackingRuntimeStateLoaded = true;
        _tracking.trackingRuntimeStateLoadedAt = DateTime.now();
      }
      _maybeAutoStartTracking();
      return;
    }

    _trackingRuntimeStateLoaded = true;
    _tracking.trackingRuntimeStateLoadedAt = DateTime.now();
    _maybeAutoStartTracking();
  }

  Future<void> _saveTrackingRuntimeState() async {
    final Map<String, dynamic> payload =
        _state.buildTrackingRuntimeStatePayload();
    await _prefsManager.saveTrackingRuntimeState(payload);
    _tracking.trackingRuntimeStateSavedAt = DateTime.now();
  }

  Future<void> _loadDebugMode() async {
    final DebugPreferences prefs = await _prefsManager.loadDebugPreferences();
    if (!mounted) {
      return;
    }
    setState(() {
      _debugModeEnabled = prefs.debugModeEnabled;
      _showBatteryInfo = prefs.showBatteryInfo;
    });
  }

  Future<void> _setShowBatteryInfo(bool enabled) async {
    setState(() {
      _showBatteryInfo = enabled;
    });
    await _prefsManager.setShowBatteryInfo(enabled);

    if (enabled &&
        _batteryUsage.isEmpty &&
        !_isLoadingBatteryUsage &&
        _debugModeEnabled) {
      unawaited(_loadBatteryUsage());
    }
  }

  /// Load polling preferences and reinitialize geofence calculator.
  /// Updates all polling intervals and recreates calculator with new radius.
  Future<void> _loadPollingPreferences() async {
    final PollingPreferences prefs =
        await _prefsManager.loadPollingPreferences();
    if (!mounted) {
      return;
    }
    setState(() {
      _closePollSeconds = prefs.closePollSeconds;
      _farPollSeconds = prefs.farPollSeconds;
      _farDistanceMeters = prefs.farDistanceMeters;
      _inGeofenceDistanceMeters = prefs.inGeofenceDistanceMeters;
      _outOfGeofenceRetriggerMinutes = prefs.outOfGeofenceRetriggerMinutes;
      _hideNearestWhenFar = prefs.hideNearestWhenFar;
      // Reinitialize geofence calculator with new parameters
      _geofenceCalc = GeofenceCalculator(
        inGeofenceDistanceMeters: _inGeofenceDistanceMeters.toDouble(),
      );
    });
  }

  Future<void> _savePollingPreferences() async {
    final prefs = PollingPreferences(
      closePollSeconds: _closePollSeconds,
      farPollSeconds: _farPollSeconds,
      farDistanceMeters: _farDistanceMeters,
      inGeofenceDistanceMeters: _inGeofenceDistanceMeters,
      outOfGeofenceRetriggerMinutes: _outOfGeofenceRetriggerMinutes,
      hideNearestWhenFar: _hideNearestWhenFar,
    );
    await _prefsManager.savePollingPreferences(prefs);
  }

  Future<void> _loadUnitPreference() async {
    final bool useMetric = await _prefsManager.loadUseMetric();
    if (!mounted) {
      return;
    }
    setState(() {
      _useMetric = useMetric;
    });
  }

  Future<void> _saveUnitPreference() async {
    await _prefsManager.saveUseMetric(_useMetric);
  }

  Future<void> _loadLocationLimitUnlockedPreference() async {
    final bool unlocked = await _prefsManager.loadLocationLimitUnlocked();
    if (!mounted) {
      return;
    }
    setState(() {
      _locationLimitUnlocked = unlocked;
    });
  }

  Future<void> _saveLocationLimitUnlockedPreference() async {
    await _prefsManager.saveLocationLimitUnlocked(_locationLimitUnlocked);
  }

  void _onLocationUnlockCodeSubmitted(String rawCode) {
    final String code = rawCode.trim().toLowerCase();
    if (code != AppConstants.locationLimitUnlockCode) {
      _showInfoSnackBar('Unlock code is not valid.');
      return;
    }

    if (_locationLimitUnlocked) {
      _showInfoSnackBar('Location limit is already unlocked.');
      return;
    }

    setState(() {
      _locationLimitUnlocked = true;
    });
    unawaited(_saveLocationLimitUnlockedPreference());

    _showInfoSnackBar('Location limit unlocked. You can now add more than 5.');
  }

  // ============================================================================
  // FORMATTING & DISPLAY: Format values for UI display
  // ============================================================================

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

  /// Format an accuracy value (metres) for display.
  String _fmtAccuracy(double meters) => _fmtDist(meters);

  // ============================================================================
  // HELPER METHODS: Common Patterns & Calculations
  // ============================================================================

  /// Calculate minutes elapsed between two timestamps.
  /// Returns positive minutes even if end is before start.
  double _minutesSince(DateTime start, DateTime end) =>
      max(0, end.difference(start).inMilliseconds / 60000);

  void _setTrackingToggleBusy(bool isBusy) {
    if (!mounted) {
      _isChangingTrackingState = isBusy;
      return;
    }
    setState(() {
      _isChangingTrackingState = isBusy;
    });
  }

  void _showInfoSnackBar(String message) {
    UiFeedbackService.showMessage(context, message);
  }

  /// Reject a log attempt with consistent pattern: update status, dismiss prompt, save state.
  void _rejectLogWithStatus(String reason) {
    setState(() {
      _geofence.dismissPrompt();
      _tracking.status = reason;
    });
    unawaited(_cancelLogReminderNotification());
    unawaited(_saveTrackingRuntimeState());
  }

  /// Find a site in the current site list by its address.
  /// Returns the site if found, otherwise returns the original site.
  JobSite _findSiteByAddress(JobSite site) {
    for (final JobSite savedSite in _sites) {
      if (savedSite.address == site.address) {
        return savedSite;
      }
    }
    return site;
  }

  String _formatSecondsOption(int seconds) {
    if (seconds >= 60) {
      final int minutes = (seconds / 60).round();
      return '$minutes min';
    }
    return '${seconds}s';
  }

  String _formatMetersOption(int meters) => _fmtDistInt(meters);

  /// Determine if should use far polling interval for the nearest logged site.
  /// Returns true if the nearest site has been logged AND is currently in geofence.
  /// This prevents rapid re-logging by keeping close polling active after a log.
  bool _shouldUseFarPollingForNearestLoggedSite(SiteDistance nearest) {
    final LocationFix? fix = _gpsState.currentFix;
    if (fix == null) {
      return false;
    }

    final bool nearestLogged =
        _sessionLoggedAddresses.contains(nearest.site.address);
    if (!nearestLogged) {
      return false;
    }

    final double effectiveRadius = _geofenceCalc.calculateEffectiveRadius(fix.accuracyMeters.toDouble());
    final bool nearestInGeofence = nearest.distanceMeters <= effectiveRadius;
    return nearestInGeofence;
  }

  int _activePollSeconds() {
    if (_gpsState.currentFix == null || _sites.isEmpty) {
      return _closePollSeconds;
    }
    final SiteDistance nearest = LocationTrackingCalculator.findNearestSite(
      _gpsState.currentFix!,
      _sites,
    );
    if (nearest.distanceMeters > _farDistanceMeters ||
        _shouldUseFarPollingForNearestLoggedSite(nearest)) {
      return _farPollSeconds;
    }
    return _closePollSeconds;
  }

  /// Calculate adaptive required stable samples based on current poll interval.
  /// Longer poll intervals need fewer samples to prevent excessive dwell time.
  /// Example: With 5-min polls, one stable sample is enough; with 30-sec polls, need 3.
  int _effectiveRequiredStableSamples() {
    final int activePollSeconds = _activePollSeconds();
    if (activePollSeconds >= 300) {
      // 5+ minute poll: one sample is enough
      return 1;
    }
    if (activePollSeconds >= 120) {
      // 2+ minute poll: two samples
      return 2;
    }
    // Close polling (30-60s): require full samples
    return AppConstants.requiredStableSamples;
  }

  String _pollingModeSummary() {
    if (_gpsState.currentFix == null || _sites.isEmpty) {
      return 'close';
    }
    final SiteDistance nearest = LocationTrackingCalculator.findNearestSite(
      _gpsState.currentFix!,
      _sites,
    );
    if (nearest.distanceMeters > _farDistanceMeters) {
      return 'far';
    }
    if (_shouldUseFarPollingForNearestLoggedSite(nearest)) {
      return 'far (logged in geofence)';
    }
    return 'close';
  }

  String _pollingDebugSummary() {
    if (_tracking.isTracking) {
      return 'Position polling: ${_formatSecondsOption(_activePollSeconds())} (${_pollingModeSummary()} mode).';
    }

    if (_trackingEnabledPreference) {
      return 'Position polling should be active, but it is not currently running. Current status: ${_tracking.status}';
    }

    return 'Position polling is inactive. Close: ${_formatSecondsOption(_closePollSeconds)}, Far: ${_formatSecondsOption(_farPollSeconds)} beyond ${_formatMetersOption(_farDistanceMeters)}.';
  }

  List<LocationTrackingState> _buildLocationTrackingStates() {
    return LocationTrackingCalculator.buildLocationTrackingStates(
      sites: _sites,
      fix: _gpsState.currentFix,
      farDistanceMeters: _farDistanceMeters,
      matchRadiusMeters: _inGeofenceDistanceMeters.toDouble(),
      timeInGeofenceMinutes: _projectedTimeInGeofenceMinutesBySite(),
      sessionLoggedAddresses: _sessionLoggedAddresses,
      pendingSite: _geofence.pendingSite,
      candidateSite: _geofence.candidateSite,
      now: DateTime.now(),
    );
  }

  Map<String, double> _projectedTimeInGeofenceMinutesBySite() {
    return <String, double>{
      for (final JobSite site in _sites)
        site.address: _liveTimeInGeofenceMinutes(site),
    };
  }

  Map<String, double> _projectedOutOfGeofenceMinutesBySite() {
    final DateTime now = DateTime.now();
    return <String, double>{
      for (final JobSite site in _sites)
        site.address: _liveOutOfGeofenceMinutes(site, now),
    };
  }

  double _liveOutOfGeofenceMinutes(JobSite site, DateTime now) {
    final DateTime? outSince = _outOfGeofenceSince[site.address];
    if (outSince == null) {
      return 0;
    }
    // Cap at 24 hours to prevent unreasonable values
    return min(24 * 60, _minutesSince(outSince, now));
  }

  String _locationTrackingStatesDebugSummary() {
    final List<LocationTrackingState> states = _buildLocationTrackingStates();
    final Map<String, double> projectedOutOfGeofenceMinutes =
        _projectedOutOfGeofenceMinutesBySite();
    if (states.isEmpty) {
      return 'Location Tracking State\nNo saved locations.';
    }

    final String lines = states.map((LocationTrackingState state) {
      final String dist = state.distanceMeters == null
          ? 'no fix'
          : _fmtDist(state.distanceMeters!);
        final String timeInGeofence =
          _formatElapsedMinutes(state.timeInGeofenceMinutes);
      final String remaining = state.remainingMinutes.toStringAsFixed(1);
      final String address = _siteAddressByName(state.name);
      final double outMinutes = projectedOutOfGeofenceMinutes[address] ?? 0;
        final String outDuration = _formatElapsedMinutes(outMinutes);
      return '${state.name}\n'
          '  in geofence: ${state.inGeofence}  |  out: ${state.outOfGeofence}  |  far: ${state.far}  |  dist: $dist\n'
          '  time in geofence: $timeInGeofence  |  out-of-geofence: $outDuration  |  remaining: ${remaining}m\n'
          '  logged: ${state.logged}  |  waiting: ${state.waitingToGetLogged}';
    }).join('\n\n');

    return 'Location Tracking State\n\n$lines';
  }

  String _siteAddressByName(String siteName) {
    for (final JobSite site in _sites) {
      if (site.name == siteName) {
        return site.address;
      }
    }
    return '';
  }

  String _formatElapsedMinutes(double minutes) {
    final double safeMinutes = max(0, minutes);
    if (safeMinutes < 60) {
      return '${safeMinutes.toStringAsFixed(1)}m';
    }
    if (safeMinutes < 24 * 60) {
      return '${(safeMinutes / 60).toStringAsFixed(1)}h';
    }
    return '${(safeMinutes / (24 * 60)).toStringAsFixed(1)}d';
  }

  String _rawGpsDebugSummary() {
    final String readAt = _gpsState.lastRawGpsPayloadAt == null
        ? 'No payload received yet'
        : _formatDebugTimestamp(_gpsState.lastRawGpsPayloadAt!);

    final String errorLine = _gpsState.lastRawGpsReadError == null
        ? 'Last read error: none'
        : 'Last read error: ${_gpsState.lastRawGpsReadError}';

    final Map<Object?, Object?>? payload = _gpsState.lastRawGpsPayload;
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
    final String restored = _tracking.trackingRuntimeStateLoadedAt == null
        ? 'Not restored yet'
        : _formatDebugTimestamp(_tracking.trackingRuntimeStateLoadedAt!);
    final String saved = _tracking.trackingRuntimeStateSavedAt == null
        ? 'No save in this app session yet'
        : _formatDebugTimestamp(_tracking.trackingRuntimeStateSavedAt!);

    return 'Runtime timing state\n'
        'Restored: $restored\n'
        'Saved: $saved\n'
        'Tracked sites this session: ${_sessionLoggedAddresses.length}\n'
        'Active geofence timers: ${_timeInGeofenceMinutesBySite.length}';
  }

  String _appReadinessDebugSummary() {
    final String lastFix =
        _tracking.lastFixAt == null ? 'none' : _formatDebugTimestamp(_tracking.lastFixAt!);

    return 'App readiness\n'
        'Tracking running: ${_tracking.isTracking}\n'
        'Tracking preference enabled: $_trackingEnabledPreference\n'
        'Loaded flags: trackingPref=$_trackingPreferenceLoaded, runtimeState=$_trackingRuntimeStateLoaded, sites=$_sitesLoaded\n'
        'Auto-start attempted: $_autoStartTrackingAttempted\n'
        'Changing tracking state: $_isChangingTrackingState\n'
        'Fetching current location: $_isFetchingCurrentLocation\n'
        'Timers active: poll=${_tracking.trackingTimer != null}, prompt=${_tracking.promptTimer != null}\n'
        'Last accepted fix: $lastFix\n'
        'Sites: ${_sites.length}, Logs: ${_logs.length}, Deleted log keys: ${_deletedLogKeys.length}';
  }

  String _geofenceDecisionDebugSummary() {
    final LocationFix? fix = _gpsState.currentFix;
    final SiteDistance? nearest = _gpsState.latestNearest;
    final String nearestLine = nearest == null
        ? 'Nearest: unavailable'
        : 'Nearest: ${nearest.site.name} @ ${_fmtDist(nearest.distanceMeters)}';

    final String fixLine = fix == null
        ? 'Fix: unavailable'
        : 'Fix: acc=${_fmtAccuracy(fix.accuracyMeters)}, speed=${fix.speedMetersPerSecond.toStringAsFixed(2)} m/s';

    final String pending = _geofence.pendingSite?.name ?? 'none';
    final String candidate = _geofence.candidateSite?.name ?? 'none';

    return 'Geofence decision snapshot\n'
        '$nearestLine\n'
        '$fixLine\n'
        'Stable samples: ${_tracking.stableSamples} / ${AppConstants.requiredStableSamples}\n'
        'Effective stable requirement now: ${_effectiveRequiredStableSamples()}\n'
        'Candidate: $candidate\n'
        'Pending prompt: $pending (countdown: ${_geofence.promptCountdown} s)\n'
        'Out-of-geofence timers: ${_outOfGeofenceSince.length}';
  }

  String _startupLoggingDiagnosticsSummary() {
    final DateTime now = DateTime.now();
    final bool startupReady = _trackingPreferenceLoaded &&
        _trackingRuntimeStateLoaded &&
        _sitesLoaded;
    final String lastFixAge = _tracking.lastFixAt == null
        ? 'n/a'
        : '${now.difference(_tracking.lastFixAt!).inSeconds}s ago';
    final SiteDistance? nearest = _gpsState.latestNearest;
    final JobSite? nearestSite = nearest?.site;
    final String nearestDistance =
        nearest == null ? 'n/a' : _fmtDist(nearest.distanceMeters);

    String nearestBlock = 'Nearest logging diagnostics\nNo nearest site yet.';
    if (nearestSite != null) {
      final String address = nearestSite.address;
      final double baseDwell = _timeInGeofenceMinutesBySite[address] ?? 0;
      final double projectedDwell = _liveTimeInGeofenceMinutes(nearestSite);
      final double outMinutes = _liveOutOfGeofenceMinutes(nearestSite, now);
      final bool logged = _sessionLoggedAddresses.contains(address);
      final DateTime? outSince = _outOfGeofenceSince[address];
      final JobLog? latestLogForSite = _logs.cast<JobLog?>().firstWhere(
        (JobLog? log) => log?.address == address,
        orElse: () => null,
        );
      final double? lastLogAgeMinutes = latestLogForSite == null
        ? null
        : _minutesSince(latestLogForSite.timestamp, now);
      final bool retriggerWindowElapsed =
        lastLogAgeMinutes != null &&
        lastLogAgeMinutes >= _outOfGeofenceRetriggerMinutes;

      final LocationFix? fix = _gpsState.currentFix;
      final double? effectiveRadius = fix == null
        ? null
        : _geofenceCalc.calculateEffectiveRadius(fix.accuracyMeters.toDouble());
      final double? currentDistance = nearest?.distanceMeters;
      final double outsideBuffer = fix == null
        ? 0
        : (fix.accuracyMeters * 0.75 < 25
          ? 25
          : fix.accuracyMeters * 0.75);
      final double? retriggerOutsideThreshold =
        effectiveRadius == null ? null : effectiveRadius + outsideBuffer;
      final double requiredOutsideDistance = retriggerOutsideThreshold == null
          ? AppConstants.retriggerMinimumOutsideDistanceMeters
          : (retriggerOutsideThreshold >
                  AppConstants.retriggerMinimumOutsideDistanceMeters
              ? retriggerOutsideThreshold
              : AppConstants.retriggerMinimumOutsideDistanceMeters);
      final bool stillInside = currentDistance != null &&
        effectiveRadius != null &&
        currentDistance <= effectiveRadius;
      final bool confidentlyOutside = currentDistance != null &&
        currentDistance > requiredOutsideDistance;
      final bool retriggerEligible =
        confidentlyOutside && retriggerWindowElapsed;

      final String lastLogAgeLine = lastLogAgeMinutes == null
        ? 'n/a'
        : _formatElapsedMinutes(lastLogAgeMinutes);
      final String outsideThresholdLine = _fmtDist(requiredOutsideDistance);

      nearestBlock = 'Nearest logging diagnostics\n'
          'Site: ${nearestSite.name}\n'
          'Address: $address\n'
          'Distance: $nearestDistance\n'
          'Logged this session: $logged\n'
        'Last log age: $lastLogAgeLine\n'
        'Still inside geofence: $stillInside\n'
        'Outside threshold: $outsideThresholdLine\n'
        'Confidently outside: $confidentlyOutside\n'
        'Retrigger window elapsed (${_outOfGeofenceRetriggerMinutes}m): $retriggerWindowElapsed\n'
        'Retrigger eligible now: $retriggerEligible\n'
          'Required dwell: ${nearestSite.requiredDwellMinutes}m\n'
          'Base dwell map: ${_formatElapsedMinutes(baseDwell)}\n'
          'Projected dwell: ${_formatElapsedMinutes(projectedDwell)}\n'
          'Out-of-geofence: ${_formatElapsedMinutes(outMinutes)}\n'
          'Out since: ${outSince == null ? 'none' : _formatDebugTimestamp(outSince)}';
    }

    return 'Startup and logging gates\n'
        'Startup ready: $startupReady\n'
        'Tracking pref loaded: $_trackingPreferenceLoaded\n'
        'Runtime state loaded: $_trackingRuntimeStateLoaded\n'
        'Sites loaded: $_sitesLoaded\n'
        'Auto-start attempted: $_autoStartTrackingAttempted\n'
        'Tracking-off dialog shown: $_trackingOffStartupDialogShown\n'
        'Tracking enabled pref: $_trackingEnabledPreference\n'
        'Tracking active: ${_tracking.isTracking}\n'
        'Last fix age: $lastFixAge\n'
        'Current status: ${_tracking.status}\n'
        'Candidate site: ${_geofence.candidateSite?.name ?? 'none'}\n'
        'Pending prompt site: ${_geofence.pendingSite?.name ?? 'none'}\n'
        'Stable samples: ${_tracking.stableSamples}/$_requiredStableSamples\n'
        'Effective stable requirement now: ${_effectiveRequiredStableSamples()}\n'
        'Prompt countdown: ${_geofence.promptCountdown}s\n'
        'Close/Far polling sec: $_closePollSeconds/$_farPollSeconds\n\n'
        '$nearestBlock';
  }

  bool _shouldHideNearestInfo(SiteDistance nearest) {
    return _hideNearestWhenFar && nearest.distanceMeters > _farDistanceMeters;
  }

  // ============================================================================
  // GPS POLLING: Schedule, poll, and process location updates
  // ============================================================================

  Future<void> _pollAndReschedule() async {
    if (!_tracking.isTracking) {
      return;
    }
    await _pollCurrentLocation();
    if (!_tracking.isTracking) {
      return;
    }
    _scheduleNextPoll();
  }

  void _scheduleNextPoll({bool immediate = false}) {
    if (!_tracking.isTracking) {
      return;
    }
    _tracking.trackingTimer?.cancel();
    if (immediate) {
      unawaited(_pollAndReschedule());
      return;
    }
    _tracking.trackingTimer = Timer(
      Duration(seconds: _activePollSeconds()),
      () => unawaited(_pollAndReschedule()),
    );
  }

  void _startLiveUiTicker() {
    _tracking.uiRefreshTimer?.cancel();
    _tracking.uiRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_tracking.isTracking) {
        return;
      }
      setState(() {
        // Rebuild to refresh projected countdown values between GPS polls.
      });
    });
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

  // ============================================================================
  // DATA LOADING & STORAGE: Load sites, logs, and runtime state from persistence
  // ============================================================================

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
    if (!mounted || _tracking.isTracking || _trackingOffStartupDialogShown) {
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
      if (mounted) {
        setState(() {
          _isLoadingBatteryUsage = false;
        });
      } else {
        _isLoadingBatteryUsage = false;
      }
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

  /// Load logs from background polling when app resumes.
  /// Loads background logs (tracked by native code), merged log keys, calendar keys,
  /// and out-of-geofence timers. Called on app resume and after permissions granted.
  Future<void> _loadBackgroundLogs() async {
    try {
      await _ensureDeletedLogKeysLoaded();
      await _ensureCalendarAddedLogKeysLoaded();
      await _loadBackgroundOutOfGeofenceSince();

      final String? raw =
          await _locationChannel.invokeMethod<String>('loadBackgroundLogs');
      if (raw == null || raw.trim().isEmpty) {
        return;
      }

      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        return;
      }

      final Map<String, JobSite> siteByAddress = <String, JobSite>{
        for (final JobSite site in _sites) site.address: site,
      };

      final List<JobLog> loadedLogs = decoded
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> item) {
        final int timestampMillis = ((item['timestamp'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch);
        final String address = (item['address'] ?? '').toString();
        final JobSite? site = siteByAddress[address];
        final DateTime timestamp =
            DateTime.fromMillisecondsSinceEpoch(timestampMillis);

        final double? parsedTimeInAtLog =
            (item['timeInGeofenceMinutesAtLog'] as num?)?.toDouble();
        final double inferredTimeInAtLog = parsedTimeInAtLog ??
            (site == null ? 0 : site.requiredDwellMinutes.toDouble());

        final double? parsedTimeRemainingAtLog =
            (item['timeRemainingMinutesAtLog'] as num?)?.toDouble();
        final double inferredTimeRemainingAtLog =
            parsedTimeRemainingAtLog ?? 0;

        final int? parsedFirstInMillis =
            (item['firstInGeofenceAt'] as num?)?.toInt();
        final int? parsedLastInMillis =
            (item['lastInGeofenceAt'] as num?)?.toInt();

        final DateTime lastInGeofenceAt =
            parsedLastInMillis == null || parsedLastInMillis <= 0
                ? timestamp
                : DateTime.fromMillisecondsSinceEpoch(parsedLastInMillis);

        final DateTime firstInGeofenceAt =
            parsedFirstInMillis == null || parsedFirstInMillis <= 0
                ? lastInGeofenceAt.subtract(
                    Duration(
                      milliseconds:
                          (inferredTimeInAtLog * 60000).round().toInt(),
                    ),
                  )
                : DateTime.fromMillisecondsSinceEpoch(parsedFirstInMillis);

        return JobLog(
          name: (item['name'] ?? item['siteName'] ?? item['address'] ?? '')
              .toString(),
          address: address,
          notes: (item['notes'] ?? '').toString(),
          lat: ((item['lat'] as num?)?.toDouble() ?? 0),
          lng: ((item['lng'] as num?)?.toDouble() ?? 0),
          confidence: ((item['confidence'] as num?)?.toDouble() ?? 100),
          confirmedByUser: (item['confirmedByUser'] as bool?) ?? false,
          autoLogged: (item['autoLogged'] as bool?) ?? true,
          calendarAdded: (item['calendarAdded'] as bool?) ??
              false ||
                  _calendarAddedLogKeys.contains(
                    _logStorageKey(
                      address: address,
                      timestampMillis: timestampMillis,
                    ),
                  ),
          firstInGeofenceAt: firstInGeofenceAt,
          lastInGeofenceAt: lastInGeofenceAt,
          timeInGeofenceMinutesAtLog: inferredTimeInAtLog,
          timeRemainingMinutesAtLog: inferredTimeRemainingAtLog,
          timestamp: timestamp,
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

      final Set<String> knownAddresses =
          _sites.map((JobSite site) => site.address).toSet();
      final Set<String> loggedAddresses = loadedLogs
          .map((JobLog log) => log.address)
          .where((String address) =>
              address.isNotEmpty && knownAddresses.contains(address))
          .toSet();

      setState(() {
        _state.mergeLoadedLogs(loadedLogs);
        _sessionLoggedAddresses.addAll(loggedAddresses);
        if (_geofence.pendingSite != null &&
            loggedAddresses.contains(_geofence.pendingSite!.address)) {
          _geofence.dismissPrompt();
        }
      });
    } catch (_) {
      // Ignore background log load errors; they are not fatal.
    }
  }

  Future<void> _loadBackgroundOutOfGeofenceSince() async {
    try {
      final String? raw = await _locationChannel.invokeMethod<String>(
        'loadBackgroundOutOfGeofenceSince',
      );
      if (raw == null || raw.trim().isEmpty) {
        return;
      }

      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final Map<String, DateTime> parsed = <String, DateTime>{};
      decoded.forEach((String address, dynamic value) {
        final int? timestampMillis = (value as num?)?.toInt();
        if (timestampMillis != null && timestampMillis > 0) {
          parsed[address] =
              DateTime.fromMillisecondsSinceEpoch(timestampMillis);
        }
      });

      final Set<String> siteAddresses =
          _sites.map((JobSite site) => site.address).toSet();

      if (!mounted) {
        _outOfGeofenceSince.removeWhere(
          (String address, DateTime _) => siteAddresses.contains(address),
        );
        _outOfGeofenceSince.addAll(parsed);
        return;
      }

      setState(() {
        _outOfGeofenceSince.removeWhere(
          (String address, DateTime _) => siteAddresses.contains(address),
        );
        _outOfGeofenceSince.addAll(parsed);
      });
    } catch (_) {
      // Keep best-effort behavior if native background timing is unavailable.
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

  Future<void> _ensureCalendarAddedLogKeysLoaded() async {
    if (_calendarAddedLogKeysLoaded) {
      return;
    }

    try {
      final String? raw = await ScenarioPreferencesService.loadStringPreference(
        _locationChannel,
        key: _calendarAddedLogKeysPreferenceKey,
      );

      if (raw != null && raw.trim().isNotEmpty) {
        final dynamic decoded = jsonDecode(raw);
        if (decoded is List<dynamic>) {
          _calendarAddedLogKeys
            ..clear()
            ..addAll(decoded.whereType<String>());
        }
      }
    } catch (_) {
      // Keep best-effort behavior if preference storage is unavailable.
    }

    _calendarAddedLogKeysLoaded = true;
  }

  Future<void> _saveCalendarAddedLogKeys() async {
    try {
      await ScenarioPreferencesService.saveStringPreference(
        _locationChannel,
        key: _calendarAddedLogKeysPreferenceKey,
        value: jsonEncode(_calendarAddedLogKeys.toList()),
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
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_saveTrackingRuntimeState());
    _tracking.trackingTimer?.cancel();
    _tracking.promptTimer?.cancel();
    _tracking.uiRefreshTimer?.cancel();
    super.dispose();
  }

  /// Start GPS tracking: ensure permissions, initialize state, schedule first poll.
  /// Resets session state (candidate site, prompt state) but preserves persisted runtime state.
  Future<void> _startScenario() async {
    final bool hasLocationAccess = await _ensureLocationAccess();
    if (!hasLocationAccess || !mounted) {
      return;
    }

    // Resume persisted runtime timing state instead of resetting on restart.
    _tracking.stableSamples = 0;
    _geofence.clear();
    _gpsState.latestNearest = null;
    _tracking.lastFixAt = null;
    _tracking.promptTimer?.cancel();
    _tracking.isTracking = true;
    _tracking.status = _sites.isEmpty
        ? 'Tracking started. No locations configured yet. Add locations from the Locations tab.'
        : 'Tracking started. Reading live GPS signal...';

    _scheduleNextPoll(immediate: true);
    _startLiveUiTicker();
    setState(() {});
    unawaited(_saveTrackingRuntimeState());
  }

  Future<void> _onTrackingToggleChanged(bool enabled) async {
    if (_isChangingTrackingState) {
      return;
    }

    _setTrackingToggleBusy(true);
    try {
      if (enabled) {
        await _saveTrackingPreference(true);
        await _startScenario();

        if (!_tracking.isTracking) {
          _showInfoSnackBar('Could not start tracking: ${_tracking.status}');
        }
        return;
      }

      if (!_tracking.isTracking) {
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
      _setTrackingToggleBusy(false);
    }
  }

  Future<bool> _ensureLocationAccess() async {
    return TrackingAccessController.ensureTrackingAccess(
      context: context,
      channel: _locationChannel,
      syncBackgroundGeofences: _syncBackgroundGeofences,
      setStatus: (String status) {
        if (!mounted) {
          _tracking.status = status;
          return;
        }
        setState(() {
          _tracking.status = status;
        });
      },
      setBackgroundPermissionGranted: (bool granted) {
        if (!mounted) {
          _backgroundLocationPermissionGranted = granted;
          return;
        }
        setState(() {
          _backgroundLocationPermissionGranted = granted;
        });
      },
    );
  }

  Future<void> _openLocationSettings() async {
    try {
      await LocationPermissionService.openLocationSettings(_locationChannel);
    } catch (_) {
      _showInfoSnackBar('Could not open Location settings.');
    }
  }

  Future<void> _openAppSettings() async {
    try {
      await LocationPermissionService.openAppSettings(_locationChannel);
    } catch (_) {
      _showInfoSnackBar('Could not open App settings.');
    }
  }

  /// Poll current GPS location from platform and process the fix.
  /// Handles timeout and platform exceptions gracefully, updating status appropriately.
  Future<void> _pollCurrentLocation() async {
    if (!_tracking.isTracking) {
      return;
    }

    try {
      final Map<Object?, Object?>? position = await _locationChannel
          .invokeMethod<Map<Object?, Object?>>(
            'getCurrentLocation',
          )
          .timeout(AppConstants.gpsReadTimeout);

      if (!_tracking.isTracking || !mounted) {
        return;
      }

      setState(() {
        _gpsState.lastRawGpsPayload =
            position == null ? null : Map<Object?, Object?>.from(position);
        _gpsState.lastRawGpsPayloadAt = DateTime.now();
        _gpsState.lastRawGpsReadError = null;
      });

      final double? lat = (position?['latitude'] as num?)?.toDouble();
      final double? lng = (position?['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) {
        setState(() {
          _tracking.status = 'GPS payload missing latitude or longitude.';
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
      if (!mounted || !_tracking.isTracking) {
        return;
      }
      setState(() {
        _gpsState.lastRawGpsReadError = 'timeout after ${AppConstants.gpsReadTimeout.inSeconds}s';
        _tracking.status =
            'GPS read timed out. Move outdoors for clearer sky view and try again.';
      });
    } on PlatformException catch (error) {
      if (!mounted || !_tracking.isTracking) {
        return;
      }
      setState(() {
        _gpsState.lastRawGpsReadError =
            '${error.code}: ${error.message ?? 'unknown error'}';
        _tracking.status =
            'GPS error (${error.code}): ${error.message ?? 'unknown error'}';
      });
    } catch (_) {
      if (!mounted || !_tracking.isTracking) {
        return;
      }
      setState(() {
        _gpsState.lastRawGpsReadError = 'unexpected read failure';
        _tracking.status = 'Unable to read GPS signal. Move outdoors and try again.';
      });
    }
  }

  /// Stop GPS tracking: cancel all timers, clear pending prompts, and save state.
  void _stopScenario() {
    _tracking.cancelAllTimers();
    unawaited(_cancelLogReminderNotification());
    unawaited(_clearBackgroundGeofences());
    setState(() {
      _tracking.isTracking = false;
      _geofence.dismissPrompt();
      _tracking.status = 'Tracking stopped.';
    });
    unawaited(_saveTrackingRuntimeState());
  }

  void _refreshNearestUiFromCurrentFix() {
    final LocationFix? fix = _gpsState.currentFix;
    if (!mounted || fix == null || _sites.isEmpty) {
      return;
    }

    final SiteDistance nearest = LocationTrackingCalculator.findNearestSite(
      fix,
      _sites,
    );
    final bool goodAccuracy = fix.accuracyMeters <= AppConstants.maxAccuracyMeters;
    final bool lowSpeed = fix.speedMetersPerSecond <= AppConstants.maxSpeedForDwell;
    final double effectiveRadius = _geofenceCalc.calculateEffectiveRadius(fix.accuracyMeters.toDouble());
    final bool inGeofence = nearest.distanceMeters <= effectiveRadius;

    setState(() {
      _gpsState.latestNearest = nearest;
      _tracking.status = _buildStatusText(
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
      _gpsState.latestNearest = null;
    } else {
      _refreshNearestUiFromCurrentFix();
    }

    if (_tracking.isTracking) {
      _scheduleNextPoll(immediate: true);
    }
    unawaited(_saveTrackingRuntimeState());
  }

  /// Process a new GPS fix: update state, check for geofence entry, and handle prompts.
  /// Delegates core geofence logic to TrackingController, then updates UI and decides
  /// whether to show confirmation prompt for logging.
  void _processFix(LocationFix fix) {
    final DateTime now = DateTime.now();
    final TrackingProcessResult result = TrackingController.processFix(
      fix: fix,
      now: now,
      lastFixAt: _tracking.lastFixAt,
      sites: _sites,
      sessionLoggedAddresses: _sessionLoggedAddresses,
      timeInGeofenceMinutes: _timeInGeofenceMinutesBySite,
      outOfGeofenceSince: _outOfGeofenceSince,
      outOfGeofenceRetriggerMinutes: _outOfGeofenceRetriggerMinutes,
      matchRadiusMeters: _inGeofenceDistanceMeters.toDouble(),
      maxAccuracyMeters: _maxAccuracyMeters,
      maxSpeedForDwell: _maxSpeedForDwell,
      requiredStableSamples: _effectiveRequiredStableSamples(),
      currentCandidateSite: _geofence.candidateSite,
      currentStableSamples: _tracking.stableSamples,
      pendingSite: _geofence.pendingSite,
    );
    _tracking.lastFixAt = now;

    if (_sites.isEmpty) {
      setState(() {
        _gpsState.currentFix = result.currentFix;
        _geofence.candidateSite = result.candidateSite;
        _tracking.stableSamples = result.stableSamples;
      });
      return;
    }

    setState(() {
      _gpsState.currentFix = result.currentFix;
      _geofence.candidateSite = result.candidateSite;
      _tracking.stableSamples = result.stableSamples;
      _gpsState.latestNearest = result.latestNearest;
      _tracking.status = _buildStatusText(
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

  // ============================================================================
  // LOGGING & GEOFENCE: Time calculations, prompt management, and job logging
  // ============================================================================

  double _minutesRemainingToLog(JobSite site) {
    final double required = site.requiredDwellMinutes.toDouble();
    final double liveTimeInGeofence = _liveTimeInGeofenceMinutes(site);
    return max(0, required - liveTimeInGeofence);
  }

  /// Calculate live time spent in geofence for a site.
  /// Includes base accumulated time plus ongoing time since last GPS fix.
  /// Returns 0 if currently outside geofence or not tracking.
  double _liveTimeInGeofenceMinutes(JobSite site) {
    final double base = _timeInGeofenceMinutesBySite[site.address] ?? 0;
    if (!_tracking.isTracking || _tracking.lastFixAt == null || _gpsState.currentFix == null) {
      return base;
    }

    final LocationFix fix = _gpsState.currentFix!;
    final bool goodAccuracy = fix.accuracyMeters <= _maxAccuracyMeters;
    final bool lowSpeed = fix.speedMetersPerSecond <= _maxSpeedForDwell;
    if (!goodAccuracy || !lowSpeed) {
      return base;
    }

    final double distance = LocationTrackingCalculator.distanceMetersBetween(
      fix.lat,
      fix.lng,
      site.lat,
      site.lng,
    );
    final double effectiveRadius = _geofenceCalc.calculateEffectiveRadius(fix.accuracyMeters.toDouble());
    if (distance > effectiveRadius) {
      return 0;
    }

    final double elapsedMinutes = _minutesSince(_tracking.lastFixAt!, DateTime.now());
    return base + elapsedMinutes;
  }

  // ============================================================================
  // UI & NOTIFICATIONS: Prompts, dialogs, and notification management
  // ============================================================================

  void _showConfirmationPrompt(JobSite site) {
    setState(() {
      _geofence.setPending(site, 12);
    });
    _tracking.promptTimer?.cancel();
    unawaited(_showLogReminderNotification(site, _geofence.promptCountdown));
    _tracking.promptTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_geofence.pendingSite == null) {
        timer.cancel();
        return;
      }
      if (_geofence.promptCountdown <= 1) {
        _logJob(site, confirmedByUser: false, autoLogged: true);
        timer.cancel();
      } else {
        setState(() {
          _geofence.decrementCountdown();
        });
      }
    });
  }

  void _dismissPendingPrompt() {
    if (_geofence.pendingSite == null) {
      return;
    }
    _tracking.promptTimer?.cancel();
    unawaited(_cancelLogReminderNotification());
    setState(() {
      _geofence.dismissPrompt();
      _tracking.status = 'Log reminder dismissed.';
    });
  }

  /// Log a job at the given site.
  /// Validates eligibility, prevents duplicates, and records the log entry.
  /// Rejects with appropriate message if unable to log (already logged, too recent, etc.).
  void _logJob(
    JobSite site, {
    required bool confirmedByUser,
    required bool autoLogged,
    String notes = '',
  }) {
    final LocationFix? fix = _gpsState.currentFix;
    if (fix == null) {
      return;
    }

    final JobSite activeSite = _findSiteByAddress(site);
    final DateTime now = DateTime.now();

    // Hard guard: a site can log only once per visit.
    // It becomes eligible again only when out-of-geofence retrigger clears
    // sessionLoggedAddresses, or Debug Retrigger explicitly clears it.
    if (_sessionLoggedAddresses.contains(activeSite.address)) {
      _rejectLogWithStatus(
        'Already logged for this visit at ${activeSite.address}. '
        'Leave geofence for retrigger timer or use Debug Retrigger.',
      );
      return;
    }

    // Check if there's a recent log (outside retrigger window)
    final JobLog? latestForSite = _logs.cast<JobLog?>().firstWhere(
          (JobLog? log) => log?.address == activeSite.address,
          orElse: () => null,
        );
    if (latestForSite != null) {
      final double minutesSinceLast = _minutesSince(latestForSite.timestamp, now);
      final double effectiveRadius = _geofenceCalc.calculateEffectiveRadius(fix.accuracyMeters.toDouble());
      final double distance = LocationTrackingCalculator.distanceMetersBetween(
        fix.lat,
        fix.lng,
        activeSite.lat,
        activeSite.lng,
      );
      final bool stillInside = distance <= effectiveRadius;
      final double retriggerOutsideRadius =
          effectiveRadius + (fix.accuracyMeters * 0.75 < 25 ? 25 : fix.accuracyMeters * 0.75);
        final double requiredOutsideDistance =
          retriggerOutsideRadius > AppConstants.retriggerMinimumOutsideDistanceMeters
            ? retriggerOutsideRadius
            : AppConstants.retriggerMinimumOutsideDistanceMeters;
        final bool confidentlyOutside = distance > requiredOutsideDistance;
      final bool retriggerWindowElapsed =
          minutesSinceLast >= _outOfGeofenceRetriggerMinutes;

      // Prevent repeat logs for the same visit unless the user has clearly
      // left the geofence and stayed out for the retrigger window.
      if (stillInside || !confidentlyOutside || !retriggerWindowElapsed) {
        if (stillInside) {
          _rejectLogWithStatus(
            'Skipped repeat log for ${activeSite.address}. Still inside geofence; leave area before logging again.',
          );
          return;
        }

        _rejectLogWithStatus(
          'Skipped repeat log for ${activeSite.address} (retrigger conditions not met yet).',
        );
        return;
      }
    }

    // Log is eligible: build and record it
    final String cleanNotes = notes.trim();
    final double timeInGeofenceAtLog = _liveTimeInGeofenceMinutes(activeSite);
    final double timeRemainingAtLog = max(
      0,
      activeSite.requiredDwellMinutes.toDouble() - timeInGeofenceAtLog,
    );
    final DateTime lastInGeofenceAt = _tracking.lastFixAt ?? now;
    final int inGeofenceMillis = max(0.0, (timeInGeofenceAtLog * 60000)).toInt();
    final DateTime firstInGeofenceAt =
        lastInGeofenceAt.subtract(Duration(milliseconds: inGeofenceMillis));

    _state.addLog(
      JobLog(
        name: activeSite.name,
        address: activeSite.address,
        notes: cleanNotes,
        lat: fix.lat,
        lng: fix.lng,
        confidence: _confidenceScore(fix, activeSite),
        confirmedByUser: confirmedByUser,
        autoLogged: autoLogged,
        firstInGeofenceAt: firstInGeofenceAt,
        lastInGeofenceAt: lastInGeofenceAt,
        timeInGeofenceMinutesAtLog: timeInGeofenceAtLog,
        timeRemainingMinutesAtLog: timeRemainingAtLog,
        timestamp: now,
      ),
    );

    setState(() {
      _sessionLoggedAddresses.add(activeSite.address);
      _outOfGeofenceSince.remove(activeSite.address);
      _geofence.dismissPrompt();
      _tracking.status = autoLogged
          ? 'No response received. Job auto-logged for ${activeSite.address}.'
          : 'Job confirmed and logged for ${activeSite.address}.';
    });
    unawaited(_cancelLogReminderNotification());
    unawaited(_saveTrackingRuntimeState());
  }

  Future<void> _confirmAndDebugRetriggerCurrentSite() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Retrigger'),
          content: const Text(
            'Retrigger Now clears current dwell progress for the nearest site and allows logging again. Continue?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Retrigger'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    _debugRetriggerCurrentSite();
  }

  void _debugRetriggerCurrentSite() {
    if (_geofence.pendingSite != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A log reminder is already active.')),
        );
      }
      setState(() {
        _tracking.status = 'A log reminder is already active.';
      });
      return;
    }

    final LocationFix? fix = _gpsState.currentFix;
    if (fix == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No GPS fix yet. Wait for location first.'),
          ),
        );
      }
      setState(() {
        _tracking.status = 'No GPS fix yet. Wait for location before retrigger.';
      });
      return;
    }

    final JobSite? site = _geofence.candidateSite ?? _gpsState.latestNearest?.site;
    if (site == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No nearby site available to retrigger.')),
        );
      }
      setState(() {
        _tracking.status = 'No nearby site available to retrigger.';
      });
      return;
    }

    setState(() {
      _sessionLoggedAddresses.remove(site.address);
      _outOfGeofenceSince.remove(site.address);
      _timeInGeofenceMinutesBySite[site.address] = 0;
      _tracking.stableSamples = 0;
      _geofence.candidateSite = site;
      _tracking.status =
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

    if (_tracking.isTracking) {
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
    final double timeInGeofence = _liveTimeInGeofenceMinutes(nearest.site);
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
      'time in geofence: ${_formatElapsedMinutes(timeInGeofence)} | '
      'remaining: ${_formatElapsedMinutes(remaining)} | '
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

  String _formatDebugTimestamp(DateTime value) {
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
    final DateTime now = DateTime.now();
    final Duration delta = now.difference(local);
    final Duration absDelta = delta.isNegative ? -delta : delta;

    final int hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final String minute = local.minute.toString().padLeft(2, '0');
    final String meridiem = local.hour >= 12 ? 'PM' : 'AM';

    String relative;
    if (absDelta.inSeconds < 60) {
      relative = delta.isNegative ? 'in <1m' : 'just now';
    } else if (absDelta.inMinutes < 60) {
      final int m = absDelta.inMinutes;
      relative = delta.isNegative ? 'in ${m}m' : '${m}m ago';
    } else if (absDelta.inHours < 24) {
      final int h = absDelta.inHours;
      relative = delta.isNegative ? 'in ${h}h' : '${h}h ago';
    } else {
      final int d = absDelta.inDays;
      relative = delta.isNegative ? 'in ${d}d' : '${d}d ago';
    }

    return '${monthNames[local.month - 1]} ${local.day} $hour12:$minute $meridiem ($relative)';
  }

  Future<void> _shareLogEntry(JobLog log) async {
    await LogEntryActionsController.shareLogEntry(
      context: context,
      channel: _locationChannel,
      log: log,
      formatLogTimestamp: _formatLogTimestamp,
    );
  }

  Future<void> _shareAllLogs() async {
    await LogEntryActionsController.shareAllLogs(
      context: context,
      channel: _locationChannel,
      logs: _logs,
      formatLogTimestamp: _formatLogTimestamp,
    );
  }

  Future<void> _addLogToCalendar(JobLog log) async {
    await LogEntryActionsController.handleAddLogToCalendar(
      context: context,
      channel: _locationChannel,
      log: log,
      onCalendarMarked: (String key) {
        if (!mounted) {
          return;
        }
        setState(() {
          _state.markLogCalendarAdded(log.address, log.timestamp);
          _state.addCalendarAddedLogKey(key);
        });
        unawaited(_saveCalendarAddedLogKeys());
      },
    );
  }

  /// Display countdown notification for pending log confirmation.
  /// Shows notification with site name, address, and countdown seconds remaining
  /// before the prompt is automatically dismissed.
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

  bool _hasReachedLocationLimit() {
    return !_locationLimitUnlocked && _sites.length >= AppConstants.maxSavedLocations;
  }

  String _locationLimitReachedMessage() {
    return 'Only ${AppConstants.maxSavedLocations} locations are allowed. Enter unlock code in Settings to add more.';
  }

  void _showLocationLimitReachedSnackBar() {
    _showInfoSnackBar(_locationLimitReachedMessage());
  }

  bool _isDuplicateLocationName(String name, {int? excludingIndex}) {
    return _state.isDuplicateLocationName(
      name,
      excludingIndex: excludingIndex,
    );
  }

  Future<void> _onAddNewLocation() async {
    if (_hasReachedLocationLimit()) {
      _showLocationLimitReachedSnackBar();
      return;
    }

    final JobSite? newSite =
        await LocationAddWorkflowController.collectLocationFromManualEntry(
      context: context,
      logMinuteOptions: AppConstants.logMinuteOptions,
      isDuplicateLocationName: _isDuplicateLocationName,
      title: 'Add New Location',
      submitLabel: 'Add',
    );
    if (newSite == null || !mounted) {
      return;
    }

    if (_hasReachedLocationLimit()) {
      _showLocationLimitReachedSnackBar();
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
          'Added location: ${newSite.name} (${newSite.requiredDwellMinutes}m).',
        ),
      ),
    );
  }

  Future<void> _onAddFromCurrentLocation() async {
    if (_hasReachedLocationLimit() || _isFetchingCurrentLocation) {
      if (!mounted) {
        return;
      }
      if (_hasReachedLocationLimit()) {
        _showLocationLimitReachedSnackBar();
      }
      return;
    }

    setState(() {
      _isFetchingCurrentLocation = true;
    });

    try {
      _showInfoSnackBar('Reading current GPS location...');
      final LocationFix? fix =
          await TrackingAccessController.readCurrentLocationForAdd(
        context: context,
        channel: _locationChannel,
        timeout: AppConstants.gpsReadTimeout,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (fix == null) {
        return;
      }

      final int defaultMinutes = _logMinuteOptions.contains(20)
          ? 20
          : AppConstants.logMinuteOptions.first;
      final JobSite? newSite =
          await LocationAddWorkflowController.collectLocationFromCurrentFix(
        context: context,
        fix: fix,
        logMinuteOptions: AppConstants.logMinuteOptions,
        defaultRequiredMinutes: defaultMinutes,
        isDuplicateLocationName: _isDuplicateLocationName,
      );
      if (newSite == null || !mounted) {
        return;
      }

      if (_hasReachedLocationLimit()) {
        _showLocationLimitReachedSnackBar();
        return;
      }

      setState(() {
        _state.addSite(newSite);
      });
      unawaited(_saveSites());
      _onSitesChanged();
      _showInfoSnackBar(
        'Added location from current GPS: ${newSite.name} (${newSite.requiredDwellMinutes}m).',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingCurrentLocation = false;
        });
      } else {
        _isFetchingCurrentLocation = false;
      }
    }
  }

  Future<void> _onEditLocation(int index, JobSite site) async {
    final JobSite? updatedSite =
        await LocationAddWorkflowController.collectUpdatedLocation(
      context: context,
      existingSite: site,
      excludingIndex: index,
      logMinuteOptions: AppConstants.logMinuteOptions,
      isDuplicateLocationName: _isDuplicateLocationName,
    );
    if (updatedSite == null || !mounted) {
      return;
    }

    setState(() {
      _state.updateSite(index, updatedSite);
      _state.updateLogNameByAddress(site.address, updatedSite.name);
      if (_geofence.candidateSite?.address == site.address) {
        _geofence.candidateSite = updatedSite;
      }
      if (_geofence.pendingSite?.address == site.address) {
        _geofence.pendingSite = updatedSite;
      }
      if (_gpsState.latestNearest?.site.address == site.address) {
        _gpsState.latestNearest = SiteDistance(
          site: updatedSite,
          distanceMeters: _gpsState.latestNearest!.distanceMeters,
        );
      }
    });
    unawaited(_saveSites());
    _onSitesChanged();
    _showInfoSnackBar(
      'Updated location: ${updatedSite.name} (${updatedSite.requiredDwellMinutes}m).',
    );
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
    _showInfoSnackBar('Deleted location: ${site.name}.');
  }

  Future<void> _onResetAllSites() async {
    if (_sites.isEmpty) {
      if (!mounted) {
        return;
      }
      _showInfoSnackBar('No sites to reset.');
      return;
    }

    final bool shouldReset =
        await ScenarioDialogService.confirmResetAllSites(context);

    if (!shouldReset || !mounted) {
      return;
    }

    if (_tracking.isTracking) {
      _stopScenario();
    }

    setState(() {
      _state.clearSites();
      _gpsState.latestNearest = null;
      _geofence.clear();
      _state.clearTrackingRuntimeState();
      _tracking.status =
          'All locations were reset. Add locations from the Locations tab.';
    });

    unawaited(_saveSites());
    _showInfoSnackBar('All saved locations were reset.');
  }

  Future<void> _onDeleteLogEntry(int index, JobLog log) async {
    await LogEntryActionsController.handleDeleteLogEntry(
      context: context,
      channel: _locationChannel,
      log: log,
      onDeletedKey: (String deletedKey) {
        _state.addDeletedLogKey(deletedKey);
        unawaited(_saveDeletedLogKeys());
      },
      onCalendarKeyRemoved: (String deletedKey) {
        _state.removeCalendarAddedLogKey(deletedKey);
        unawaited(_saveCalendarAddedLogKeys());
      },
      removeLogFromState: () {
        if (!mounted) {
          return;
        }
        setState(() {
          _state.removeLogAt(index);
        });
      },
    );
  }

  Future<void> _onEditLogEntry(int index, JobLog log) async {
    final String? updatedNotes = await LogEntryActionsController.requestEditedNotes(
      context,
      log: log,
    );

    if (updatedNotes == null || !mounted) {
      return;
    }

    setState(() {
      _state.updateLogNotes(index, updatedNotes);
    });
  }

  Widget _buildLogScreen() {
    return LogScreenView(
      statusText: _tracking.status,
      currentFix: _gpsState.currentFix,
      latestNearest: _gpsState.latestNearest,
      pendingSite: _geofence.pendingSite,
      promptCountdown: _geofence.promptCountdown,
      logs: _logs,
      timeInGeofenceMinutesByAddress: _projectedTimeInGeofenceMinutesBySite(),
      outOfGeofenceMinutesByAddress: _projectedOutOfGeofenceMinutesBySite(),
      formatElapsedMinutes: _formatElapsedMinutes,
      formatLogTimestamp: _formatLogTimestamp,
      buildNearestMessage: (SiteDistance nearest) {
        if (_shouldHideNearestInfo(nearest)) {
          return 'Nearest location is currently far (${_fmtDist(nearest.distanceMeters)}). Move closer to start countdown.';
        }
        final double timeInGeofence =
            _projectedTimeInGeofenceMinutesBySite()[nearest.site.address] ?? 0;
        final double timeOutGeofence =
            _liveOutOfGeofenceMinutes(nearest.site, DateTime.now());
        return 'Countdown to log ${nearest.site.name}: '
            '${_minutesRemainingToLog(nearest.site).toStringAsFixed(1)} minutes remaining\n'
            'Time in geofence: ${timeInGeofence.toStringAsFixed(1)} min | '
            'Time out geofence: ${timeOutGeofence.toStringAsFixed(1)} min';
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
      onAddLogToCalendar: _addLogToCalendar,
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
      isTracking: _tracking.isTracking,
      trackingEnabledPreference: _trackingEnabledPreference,
      isChangingTrackingState: _isChangingTrackingState,
      status: _tracking.status,
      trackingSummary: _tracking.isTracking
          ? 'Current polling: ${_formatSecondsOption(_activePollSeconds())} (${_pollingModeSummary()} mode).'
          : 'Close polling uses ${_formatSecondsOption(_closePollSeconds)}. Far polling uses ${_formatSecondsOption(_farPollSeconds)} beyond ${_formatMetersOption(_farDistanceMeters)}.',
      onTrackingToggleChanged: (bool value) {
        unawaited(_onTrackingToggleChanged(value));
      },
      closePollSeconds: _closePollSeconds,
      farPollSeconds: _farPollSeconds,
      farDistanceMeters: _farDistanceMeters,
      inGeofenceDistanceMeters: _inGeofenceDistanceMeters,
      outOfGeofenceRetriggerMinutes: _outOfGeofenceRetriggerMinutes,
      closePollSecondOptions: AppConstants.closePollSecondOptions,
      farPollSecondOptions: AppConstants.farPollSecondOptions,
      farDistanceMeterOptions: AppConstants.farDistanceMeterOptions,
      inGeofenceDistanceMeterOptions: AppConstants.inGeofenceDistanceMeterOptions,
      outOfGeofenceRetriggerMinuteOptions: AppConstants.outOfGeofenceRetriggerMinuteOptions,
      hideNearestWhenFar: _hideNearestWhenFar,
      onClosePollSecondsChanged: (int value) {
        setState(() {
          _closePollSeconds = value;
        });
        unawaited(_savePollingPreferences());
        if (_tracking.isTracking) {
          _scheduleNextPoll(immediate: true);
        }
        _refreshNearestUiFromCurrentFix();
      },
      onFarPollSecondsChanged: (int value) {
        setState(() {
          _farPollSeconds = value;
        });
        unawaited(_savePollingPreferences());
        if (_tracking.isTracking) {
          _scheduleNextPoll(immediate: true);
        }
        _refreshNearestUiFromCurrentFix();
      },
      onFarDistanceMetersChanged: (int value) {
        setState(() {
          _farDistanceMeters = value;
        });
        unawaited(_savePollingPreferences());
        if (_tracking.isTracking) {
          _scheduleNextPoll(immediate: true);
        }
        _refreshNearestUiFromCurrentFix();
      },
      onInGeofenceDistanceMetersChanged: (int value) {
        setState(() {
          _inGeofenceDistanceMeters = value;
        });
        unawaited(_savePollingPreferences());
        if (_tracking.isTracking) {
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
      backgroundLocationPermissionGranted: _backgroundLocationPermissionGranted,
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
      startupLoggingDiagnosticsSummary: _startupLoggingDiagnosticsSummary(),
      rawGpsDebugSummary: _rawGpsDebugSummary(),
      trackingRuntimeStateDebugSummary: _trackingRuntimeStateDebugSummary(),
      locationTrackingStatesDebugSummary: _locationTrackingStatesDebugSummary(),
      onRetriggerCurrentSite: () {
        unawaited(_confirmAndDebugRetriggerCurrentSite());
      },
      isLoadingBatteryUsage: _isLoadingBatteryUsage,
      onRefreshBatteryUsage: _loadBatteryUsage,
      onOpenUsageAccessSettings: _openUsageAccessSettings,
      usageAccessGranted: _usageAccessGranted,
      deviceBatteryLevel: _deviceBatteryLevel,
      batteryUsageFetchedAt: _batteryUsageFetchedAt,
      batteryUsageError: _batteryUsageError,
      batteryUsage: _batteryUsage,
      formatDebugTimestamp: _formatDebugTimestamp,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 12,
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
      body: Stack(
        children: <Widget>[
          Positioned(
            top: -90,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(
                  alpha: isDark ? 0.12 : 0.09,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -110,
            right: -70,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.tertiary.withValues(
                  alpha: isDark ? 0.09 : 0.08,
                ),
              ),
            ),
          ),
          IndexedStack(
            index: _selectedTabIndex,
            children: <Widget>[
              _buildLogScreen(),
              _buildLocationsScreen(),
              _buildSettingsScreen(),
              if (_debugModeEnabled) _buildDebugScreen(),
            ],
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 72,
        elevation: 0,
        backgroundColor: theme.colorScheme.surface.withValues(
          alpha: isDark ? 0.92 : 0.96,
        ),
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedTabIndex = index;
          });
          if (index == 2) {
            unawaited(_refreshBackgroundLocationPermissionStatus());
          }
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
