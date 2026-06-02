import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

void main() {
  runApp(const LokaLogApp());
}

class LokaLogApp extends StatelessWidget {
  const LokaLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LokaLog Job Confirmation Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
      ),
      home: const ScenarioPage(),
    );
  }
}

class ScenarioPage extends StatefulWidget {
  const ScenarioPage({super.key});

  @override
  State<ScenarioPage> createState() => _ScenarioPageState();
}

class _ScenarioPageState extends State<ScenarioPage> {
  static const int _minutesPerTick = 2;
  static const int _requiredDwellMinutes = 20;
  static const int _requiredStableSamples = 3;
  static const double _maxAccuracyMeters = 30;
  static const double _maxSpeedForDwell = 1.2;
  static const double _matchRadiusMeters = 80;

  final List<JobSite> _sites = <JobSite>[];
  final List<JobLog> _logs = <JobLog>[];
  final Map<String, int> _dwellMinutes = <String, int>{};

  Timer? _trackingTimer;
  Timer? _promptTimer;

  LocationFix? _currentFix;
  String _status = 'Tap Start Tracking on Logs to begin.';
  int _tick = 0;
  int _stableSamples = 0;
  bool _isTracking = false;
  int _selectedTabIndex = 0;

  JobSite? _candidateSite;
  JobSite? _pendingSite;
  int _promptCountdown = 0;

  @override
  void initState() {
    super.initState();
    _sites.addAll(
      _geocodeAddresses(<String>[
        '921 Green Lawn Dr',
        '413 Oak Ridge Ave',
        '777 Maple Ct',
      ]),
    );
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    _promptTimer?.cancel();
    super.dispose();
  }

  void _startScenario() {
    if (_sites.isEmpty) {
      setState(() {
        _status = 'No locations found. Add locations from the Locations tab.';
      });
      return;
    }

    _logs.clear();
    _dwellMinutes.clear();
    _tick = 0;
    _stableSamples = 0;
    _candidateSite = null;
    _pendingSite = null;
    _promptCountdown = 0;
    _promptTimer?.cancel();
    _isTracking = true;
    _status = 'Tracking started. Simulated GPS checks run every 2 minutes.';

    _trackingTimer?.cancel();
    _trackingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _tick += 1;
      final LocationFix fix = _simulateFix(_tick, _sites);
      _processFix(fix);
    });
    setState(() {});
  }

  void _stopScenario() {
    _trackingTimer?.cancel();
    _promptTimer?.cancel();
    setState(() {
      _isTracking = false;
      _pendingSite = null;
      _promptCountdown = 0;
      _status = 'Tracking stopped.';
    });
  }

  void _processFix(LocationFix fix) {
    _currentFix = fix;
    if (_sites.isEmpty) {
      return;
    }

    final SiteDistance nearest = _findNearestSite(fix, _sites);
    final bool goodAccuracy = fix.accuracyMeters <= _maxAccuracyMeters;
    final bool lowSpeed = fix.speedMetersPerSecond <= _maxSpeedForDwell;
    final bool inGeofence = nearest.distanceMeters <= _matchRadiusMeters;

    if (goodAccuracy && lowSpeed && inGeofence) {
      _stableSamples += 1;
      _candidateSite = nearest.site;
      _dwellMinutes[nearest.site.address] =
          (_dwellMinutes[nearest.site.address] ?? 0) + _minutesPerTick;
    } else {
      _stableSamples = 0;
      _candidateSite = null;
    }

    if (_candidateSite != null && _pendingSite == null) {
      final int dwell = _dwellMinutes[_candidateSite!.address] ?? 0;
      final bool alreadyLogged = _logs.any(
        (JobLog log) => log.address == _candidateSite!.address,
      );

      if (!alreadyLogged &&
          dwell >= _requiredDwellMinutes &&
          _stableSamples >= _requiredStableSamples) {
        _showConfirmationPrompt(_candidateSite!);
      }
    }

    setState(() {
      _status = _buildStatusText(
        nearest: nearest,
        goodAccuracy: goodAccuracy,
        lowSpeed: lowSpeed,
        inGeofence: inGeofence,
      );
    });
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
      _pendingSite = null;
      _promptCountdown = 0;
      _status = autoLogged
          ? 'No response received. Job auto-logged for ${site.address}.'
          : 'Job confirmed and logged for ${site.address}.';
    });
  }

  double _confidenceScore(LocationFix fix, JobSite site) {
    final double distance = _distanceMeters(fix.lat, fix.lng, site.lat, site.lng);
    final double accuracyScore = (1 - (fix.accuracyMeters / 60)).clamp(0, 1);
    final double distanceScore = (1 - (distance / 120)).clamp(0, 1);
    final double speedScore = (1 - (fix.speedMetersPerSecond / 3)).clamp(0, 1);
    return ((accuracyScore * 0.4) + (distanceScore * 0.4) + (speedScore * 0.2)) *
        100;
  }

  String _buildStatusText({
    required SiteDistance nearest,
    required bool goodAccuracy,
    required bool lowSpeed,
    required bool inGeofence,
  }) {
    final int dwell = _dwellMinutes[nearest.site.address] ?? 0;
    return 'Nearest: ${nearest.site.address} | '
        'distance: ${nearest.distanceMeters.toStringAsFixed(1)}m | '
        'dwell: ${dwell}m | '
        'accuracy: ${goodAccuracy ? 'good' : 'poor'} | '
        'motion: ${lowSpeed ? 'stationary' : 'moving'} | '
        'geofence: ${inGeofence ? 'inside' : 'outside'}';
  }

  List<JobSite> _geocodeAddresses(List<String> addresses) {
    const double baseLat = 32.7767;
    const double baseLng = -96.7970;
    return addresses.asMap().entries.map((MapEntry<int, String> entry) {
      final int hash = entry.value.codeUnits.fold<int>(0, (int a, int b) => a + b);
      final double latOffset = ((hash % 70) - 35) / 10000;
      final double lngOffset = (((hash ~/ 3) % 70) - 35) / 10000;
      return JobSite(
        address: entry.value,
        lat: baseLat + latOffset + (entry.key * 0.0025),
        lng: baseLng + lngOffset + (entry.key * 0.0025),
      );
    }).toList();
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

  LocationFix _simulateFix(int tick, List<JobSite> sites) {
    final JobSite target = sites.first;
    const double driveLat = 32.7815;
    const double driveLng = -96.8040;

    if (tick < 5) {
      return LocationFix(
        lat: driveLat + (tick * 0.00015),
        lng: driveLng + (tick * 0.0001),
        accuracyMeters: 18 + (tick % 3) * 4,
        speedMetersPerSecond: 8.6,
      );
    }

    final double jitterLat = ((tick % 3) - 1) / 40000;
    final double jitterLng = ((tick % 5) - 2) / 40000;
    return LocationFix(
      lat: target.lat + jitterLat,
      lng: target.lng + jitterLng,
      accuracyMeters: 9 + (tick % 4) * 2,
      speedMetersPerSecond: 0.4,
    );
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

  String get _appBarTitle {
    return _selectedTabIndex == 0 ? 'LokaLog - Locations Log' : 'LokaLog - Locations';
  }

  void _onAddNewLocationPlaceholder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add New Location (live) coming soon.'),
      ),
    );
  }

  Widget _buildLogScreen() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
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
              label: const Text('Stop'),
            ),
          ],
        ),
        const SizedBox(height: 16),
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
          ..._logs.map((JobLog log) {
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
                trailing: log.autoLogged
                    ? const Icon(Icons.flag, color: Colors.orange)
                    : const Icon(Icons.check_circle, color: Colors.green),
              ),
            );
          }),
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
                title: Text(site.address),
                subtitle: Text(
                  'Lat: ${site.lat.toStringAsFixed(5)}, Lng: ${site.lng.toStringAsFixed(5)}',
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
      appBar: AppBar(title: Text(_appBarTitle)),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: <Widget>[
          _buildLogScreen(),
          _buildLocationsScreen(),
        ],
      ),
      floatingActionButton: _selectedTabIndex == 1
          ? FloatingActionButton.extended(
              onPressed: _onAddNewLocationPlaceholder,
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
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check),
            label: 'Log',
          ),
          NavigationDestination(
            icon: Icon(Icons.place_outlined),
            selectedIcon: Icon(Icons.place),
            label: 'Locations',
          ),
        ],
      ),
    );
  }
}

class JobSite {
  JobSite({required this.address, required this.lat, required this.lng});

  final String address;
  final double lat;
  final double lng;
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
