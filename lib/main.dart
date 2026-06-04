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
  ThemeMode _themeMode = ThemeMode.light;

  void _setDarkMode(bool enabled) {
    setState(() {
      _themeMode = enabled ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LokaLog Job Confirmation Demo',
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
      themeMode: _themeMode,
      home: ScenarioPage(
        isDarkMode: _themeMode == ThemeMode.dark,
        onDarkModeChanged: _setDarkMode,
      ),
    );
  }
}

class ScenarioPage extends StatefulWidget {
  const ScenarioPage({
    super.key,
    required this.isDarkMode,
    required this.onDarkModeChanged,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;

  @override
  State<ScenarioPage> createState() => _ScenarioPageState();
}

class _ScenarioPageState extends State<ScenarioPage> {
  static const MethodChannel _locationChannel =
      MethodChannel('lokalog/location');
  static const int _trackingIntervalSeconds = 5;
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

  final List<JobSite> _sites = <JobSite>[];
  final List<JobLog> _logs = <JobLog>[];
  final Set<String> _sessionLoggedAddresses = <String>{};
  final Map<String, double> _dwellMinutes = <String, double>{};

  Timer? _trackingTimer;
  Timer? _promptTimer;

  LocationFix? _currentFix;
  String _status = 'Open Settings to start tracking.';
  int _stableSamples = 0;
  bool _isTracking = false;
  int _selectedTabIndex = 0;
  bool _debugModeEnabled = true;
  DateTime? _lastFixAt;
  SiteDistance? _latestNearest;

  JobSite? _candidateSite;
  JobSite? _pendingSite;
  int _promptCountdown = 0;

  bool _isLoadingBatteryUsage = false;
  bool _usageAccessGranted = false;
  String? _batteryUsageError;
  int? _deviceBatteryLevel;
  DateTime? _batteryUsageFetchedAt;
  List<DebugBatteryAppUsage> _batteryUsage = <DebugBatteryAppUsage>[];

  @override
  void initState() {
    super.initState();
    unawaited(_loadSites());
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
        });
        await _loadBackgroundLogs();
        await _saveSites();
        return;
      }

      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
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
        });
      } else {
        setState(() {
          _sites
            ..clear()
            ..addAll(loaded);
        });
      }
      await _loadBackgroundLogs();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sites
          ..clear()
          ..addAll(_defaultSites());
      });
      await _loadBackgroundLogs();
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
      await _locationChannel.invokeMethod<bool>('openUsageAccessSettings');
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Usage Access settings.')),
      );
    }
  }

  Future<void> _loadBackgroundLogs() async {
    try {
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
        return JobLog(
          address: (item['address'] ?? '').toString(),
          lat: ((item['lat'] as num?)?.toDouble() ?? 0),
          lng: ((item['lng'] as num?)?.toDouble() ?? 0),
          confidence: ((item['confidence'] as num?)?.toDouble() ?? 100),
          confirmedByUser: (item['confirmedByUser'] as bool?) ?? false,
          autoLogged: (item['autoLogged'] as bool?) ?? true,
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            ((item['timestamp'] as num?)?.toInt() ??
                DateTime.now().millisecondsSinceEpoch),
          ),
        );
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
    _stableSamples = 0;
    _candidateSite = null;
    _pendingSite = null;
    _latestNearest = null;
    _promptCountdown = 0;
    _lastFixAt = null;
    _promptTimer?.cancel();
    _isTracking = true;
    _status = 'Tracking started. Reading live GPS signal...';

    _trackingTimer?.cancel();
    _trackingTimer = Timer.periodic(
      const Duration(seconds: _trackingIntervalSeconds),
      (_) {
        _pollCurrentLocation();
      },
    );

    unawaited(_pollCurrentLocation());
    setState(() {});
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
    setState(() {
      _isTracking = false;
      _pendingSite = null;
      _promptCountdown = 0;
      _status = 'Tracking stopped.';
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
      final bool alreadyLogged =
          _sessionLoggedAddresses.contains(_candidateSite!.address);

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
    _promptTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
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
      _pendingSite = null;
      _promptCountdown = 0;
      _status = autoLogged
          ? 'No response received. Job auto-logged for ${site.address}.'
          : 'Job confirmed and logged for ${site.address}.';
    });
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
  }) {
    final double dwell = _dwellMinutes[nearest.site.address] ?? 0;
    final double remaining = _minutesRemainingToLog(nearest.site);
    final String accuracyLabel =
        goodAccuracy ? 'good' : 'poor (nearest estimate may drift)';
    return 'Nearest: ${nearest.site.address} | '
        'distance: ${nearest.distanceMeters.toStringAsFixed(1)}m | '
        'target: ${nearest.site.requiredDwellMinutes}m | '
        'dwell: ${dwell.toStringAsFixed(1)}m | '
        'remaining: ${remaining.toStringAsFixed(1)}m | '
        'accuracy: $accuracyLabel | '
        'motion: ${lowSpeed ? 'stationary' : 'moving'} | '
        'geofence: ${inGeofence ? 'inside' : 'outside'} '
        '(${nearest.distanceMeters.toStringAsFixed(0)}/${effectiveRadius.toStringAsFixed(0)}m)';
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

  Future<void> _onAddNewLocation() async {
    final _AddLocationInput? result =
        await showModalBottomSheet<_AddLocationInput>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return _AddLocationSheet(
          title: 'Add New Location',
          submitLabel: 'Add',
          logMinuteOptions: _logMinuteOptions,
        );
      },
    );

    if (result == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    if (result.name.isEmpty ||
        result.street.isEmpty ||
        result.city.isEmpty ||
        result.state.isEmpty ||
        result.zip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill name, street, city, state, and ZIP.')),
      );
      return;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Could not geocode address. Please verify and try again.'),
        ),
      );
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
      _status =
          'Added location: ${newSite.name} at ${newSite.address} (${result.requiredMinutes}m).';
    });
    unawaited(_saveSites());
  }

  Future<void> _onEditLocation(int index, JobSite site) async {
    final _AddLocationInput? result =
        await showModalBottomSheet<_AddLocationInput>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return _AddLocationSheet(
          title: 'Edit Location',
          submitLabel: 'Save',
          logMinuteOptions: _logMinuteOptions,
          initialInput: _AddLocationInput(
            name: site.name,
            street: site.street,
            city: site.city,
            state: site.state,
            zip: site.zip,
            requiredMinutes: site.requiredDwellMinutes,
          ),
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    if (result.name.isEmpty ||
        result.street.isEmpty ||
        result.city.isEmpty ||
        result.state.isEmpty ||
        result.zip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill name, street, city, state, and ZIP.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Looking up updated latitude/longitude...')),
    );

    final _GeocodePoint? point = await _lookupCoordinates(result);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (point == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Could not geocode address. Please verify and try again.'),
        ),
      );
      return;
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

    setState(() {
      _logs.removeAt(index);
      _status = 'Deleted one log entry.';
    });
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
                'Accuracy: ${_currentFix!.accuracyMeters.toStringAsFixed(1)}m | '
                'Speed: ${_currentFix!.speedMetersPerSecond.toStringAsFixed(1)} m/s',
              ),
            ),
          ),
        if (_latestNearest != null)
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Countdown to log ${_latestNearest!.site.name}: '
                '${_minutesRemainingToLog(_latestNearest!.site).toStringAsFixed(1)} minutes remaining',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        if (_pendingSite != null)
          Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Confirm job at ${_pendingSite!.address}?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text('Auto-log in ${_promptCountdown}s if no response.'),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      FilledButton(
                        onPressed: () => _logJob(
                          _pendingSite!,
                          confirmedByUser: true,
                          autoLogged: false,
                        ),
                        child: const Text('Confirm'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          _promptTimer?.cancel();
                          setState(() {
                            _pendingSite = null;
                            _status = 'User skipped confirmation prompt.';
                          });
                        },
                        child: const Text('Dismiss'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          'Locations Log',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_logs.isEmpty)
          const Text('No locations logged yet.')
        else
          ..._logs.asMap().entries.map((MapEntry<int, JobLog> entry) {
            final int index = entry.key;
            final JobLog log = entry.value;
            return Card(
              child: ListTile(
                title: Text(log.address),
                subtitle: Text(
                  '${log.timestamp.toIso8601String()}\n'
                  'Lat/Lng: ${log.lat.toStringAsFixed(5)}, ${log.lng.toStringAsFixed(5)}\n'
                  'Confidence: ${log.confidence.toStringAsFixed(1)}% | '
                  '${log.confirmedByUser ? 'confirmed' : 'auto-logged'}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (String action) {
                    if (action == 'delete') {
                      _onDeleteLogEntry(index, log);
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                  child: Icon(
                    log.autoLogged ? Icons.flag : Icons.check_circle,
                    color: log.autoLogged ? Colors.orange : Colors.green,
                  ),
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: _isTracking ? null : _startScenario,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Tracking'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isTracking ? _stopScenario : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop Tracking'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(_isTracking
                    ? 'Tracking is active.'
                    : 'Tracking is stopped.'),
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
          ? FloatingActionButton.extended(
              onPressed: _onAddNewLocation,
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Add New'),
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
    required this.address,
    required this.lat,
    required this.lng,
    required this.confidence,
    required this.confirmedByUser,
    required this.autoLogged,
    required this.timestamp,
  });

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
  });

  final String title;
  final String submitLabel;
  final List<int> logMinuteOptions;
  final _AddLocationInput? initialInput;

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

  void _submit() {
    final _AddLocationInput input = _AddLocationInput(
      name: _nameController.text.trim(),
      street: _streetController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim().toUpperCase(),
      zip: _zipController.text.trim(),
      requiredMinutes: _selectedMinutes,
    );
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
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
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
