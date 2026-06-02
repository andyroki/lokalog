import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
  static const int _trackingIntervalSeconds = 15;
  static const int _requiredStableSamples = 3;
  static const double _maxAccuracyMeters = 30;
  static const double _maxSpeedForDwell = 1.2;
  static const double _matchRadiusMeters = 80;
  static const List<int> _logMinuteOptions = <int>[10, 15, 20, 30, 45, 60];

  final List<JobSite> _sites = <JobSite>[];
  final List<JobLog> _logs = <JobLog>[];
  final Map<String, double> _dwellMinutes = <String, double>{};

  Timer? _trackingTimer;
  Timer? _promptTimer;

  LocationFix? _currentFix;
  String _status = 'Tap Start Tracking on Logs to begin.';
  int _stableSamples = 0;
  bool _isTracking = false;
  int _selectedTabIndex = 0;

  JobSite? _candidateSite;
  JobSite? _pendingSite;
  int _promptCountdown = 0;

  @override
  void initState() {
    super.initState();
    _sites.addAll(<JobSite>[
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
    ]);
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

    _logs.clear();
    _dwellMinutes.clear();
    _stableSamples = 0;
    _candidateSite = null;
    _pendingSite = null;
    _promptCountdown = 0;
    _promptTimer?.cancel();
    _isTracking = true;
    _status = 'Tracking started. Reading live GPS every $_trackingIntervalSeconds seconds.';

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
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _status = 'Location services are off. Turn on GPS and try again.';
      });
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      setState(() {
        _status = 'Location permission denied. Allow location access to start tracking.';
      });
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _status =
            'Location permission is permanently denied. Enable it from app settings.';
      });
      return false;
    }

    return true;
  }

  Future<void> _pollCurrentLocation() async {
    if (!_isTracking) {
      return;
    }

    try {
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
      );
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      ).timeout(const Duration(seconds: 12));

      if (!_isTracking || !mounted) {
        return;
      }

      final LocationFix fix = LocationFix(
        lat: position.latitude,
        lng: position.longitude,
        accuracyMeters: position.accuracy,
        speedMetersPerSecond: max(0, position.speed),
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
          (_dwellMinutes[nearest.site.address] ?? 0) +
          (_trackingIntervalSeconds / 60);
    } else {
      _stableSamples = 0;
      _candidateSite = null;
    }

    if (_candidateSite != null && _pendingSite == null) {
      final double dwell = _dwellMinutes[_candidateSite!.address] ?? 0;
      final bool alreadyLogged = _logs.any(
        (JobLog log) => log.address == _candidateSite!.address,
      );

      if (!alreadyLogged &&
          dwell >= _candidateSite!.requiredDwellMinutes.toDouble() &&
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
    final double dwell = _dwellMinutes[nearest.site.address] ?? 0;
    return 'Nearest: ${nearest.site.address} | '
        'distance: ${nearest.distanceMeters.toStringAsFixed(1)}m | '
        'target: ${nearest.site.requiredDwellMinutes}m | '
        'dwell: ${dwell.toStringAsFixed(1)}m | '
        'accuracy: ${goodAccuracy ? 'good' : 'poor'} | '
        'motion: ${lowSpeed ? 'stationary' : 'moving'} | '
        'geofence: ${inGeofence ? 'inside' : 'outside'}';
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

  String get _appBarTitle {
    return _selectedTabIndex == 0 ? 'LokaLog - Locations Log' : 'LokaLog - Locations';
  }

  Future<void> _onAddNewLocation() async {
    final _AddLocationInput? result = await showModalBottomSheet<_AddLocationInput>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        int selectedMinutes = 20;
        String nameInput = '';
        String streetInput = '';
        String cityInput = '';
        String stateInput = '';
        String zipInput = '';
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            final double keyboardInset = MediaQuery.of(context).viewInsets.bottom;
            return SafeArea(
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.only(bottom: keyboardInset),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Add New Location',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Client Name',
                            hintText: 'Smith Residence',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (String value) {
                            nameInput = value;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          textInputAction: TextInputAction.next,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Street',
                            hintText: '123 Main St',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (String value) {
                            streetInput = value;
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'City',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (String value) {
                                  cityInput = value;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                textInputAction: TextInputAction.next,
                                maxLength: 2,
                                decoration: const InputDecoration(
                                  labelText: 'State',
                                  counterText: '',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (String value) {
                                  stateInput = value;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'ZIP',
                            hintText: '75201',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (String value) {
                            zipInput = value;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: selectedMinutes,
                          decoration: const InputDecoration(
                            labelText: 'How long to log (minutes)',
                            border: OutlineInputBorder(),
                          ),
                          items: _logMinuteOptions.map((int minutes) {
                            return DropdownMenuItem<int>(
                              value: minutes,
                              child: Text('$minutes minutes'),
                            );
                          }).toList(),
                          onChanged: (int? value) {
                            if (value == null) {
                              return;
                            }
                            setSheetState(() {
                              selectedMinutes = value;
                            });
                          },
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              child: const Text('Cancel'),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: () {
                                Navigator.of(sheetContext).pop(
                                  _AddLocationInput(
                                    name: nameInput.trim(),
                                    street: streetInput.trim(),
                                    city: cityInput.trim(),
                                    state: stateInput.trim().toUpperCase(),
                                    zip: zipInput.trim(),
                                    requiredMinutes: selectedMinutes,
                                  ),
                                );
                              },
                              child: const Text('Add'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
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
        const SnackBar(content: Text('Please fill name, street, city, state, and ZIP.')),
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
          content: Text('Could not geocode address. Please verify and try again.'),
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
                title: Text(site.name),
                subtitle: Text(
                  '${site.address}\n'
                  'Lat: ${site.lat.toStringAsFixed(5)}, Lng: ${site.lng.toStringAsFixed(5)}\n'
                  'Log after: ${site.requiredDwellMinutes} minutes',
                ),
                isThreeLine: true,
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
