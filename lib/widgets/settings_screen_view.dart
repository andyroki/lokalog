import 'package:flutter/material.dart';

class SettingsScreenView extends StatelessWidget {
  const SettingsScreenView({
    super.key,
    required this.debugModeEnabled,
    required this.onDebugModeChanged,
    required this.isDarkMode,
    required this.onDarkModeChanged,
    required this.useMetric,
    required this.onUseMetricChanged,
    required this.fontScale,
    required this.minFontScale,
    required this.maxFontScale,
    required this.fontScaleStep,
    required this.onFontScaleChanged,
    required this.isTracking,
    required this.trackingEnabledPreference,
    required this.isChangingTrackingState,
    required this.status,
    required this.trackingSummary,
    required this.onTrackingToggleChanged,
    required this.closePollSeconds,
    required this.farPollSeconds,
    required this.farDistanceMeters,
    required this.outOfGeofenceRetriggerMinutes,
    required this.closePollSecondOptions,
    required this.farPollSecondOptions,
    required this.farDistanceMeterOptions,
    required this.outOfGeofenceRetriggerMinuteOptions,
    required this.hideNearestWhenFar,
    required this.onClosePollSecondsChanged,
    required this.onFarPollSecondsChanged,
    required this.onFarDistanceMetersChanged,
    required this.onOutOfGeofenceRetriggerMinutesChanged,
    required this.onHideNearestWhenFarChanged,
    required this.formatSecondsOption,
    required this.formatMetersOption,
    required this.onOpenLocationSettings,
    required this.onOpenAppSettings,
  });

  final bool debugModeEnabled;
  final ValueChanged<bool> onDebugModeChanged;
  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;
  final bool useMetric;
  final ValueChanged<bool> onUseMetricChanged;
  final double fontScale;
  final double minFontScale;
  final double maxFontScale;
  final double fontScaleStep;
  final ValueChanged<double> onFontScaleChanged;
  final bool isTracking;
  final bool trackingEnabledPreference;
  final bool isChangingTrackingState;
  final String status;
  final String trackingSummary;
  final ValueChanged<bool> onTrackingToggleChanged;
  final int closePollSeconds;
  final int farPollSeconds;
  final int farDistanceMeters;
  final int outOfGeofenceRetriggerMinutes;
  final List<int> closePollSecondOptions;
  final List<int> farPollSecondOptions;
  final List<int> farDistanceMeterOptions;
  final List<int> outOfGeofenceRetriggerMinuteOptions;
  final bool hideNearestWhenFar;
  final ValueChanged<int> onClosePollSecondsChanged;
  final ValueChanged<int> onFarPollSecondsChanged;
  final ValueChanged<int> onFarDistanceMetersChanged;
  final ValueChanged<int> onOutOfGeofenceRetriggerMinutesChanged;
  final ValueChanged<bool> onHideNearestWhenFarChanged;
  final String Function(int) formatSecondsOption;
  final String Function(int) formatMetersOption;
  final VoidCallback onOpenLocationSettings;
  final VoidCallback onOpenAppSettings;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: SwitchListTile(
            title: const Text('Debug Mode'),
            subtitle: const Text('Show or hide the Debug tab and tools.'),
            value: debugModeEnabled,
            onChanged: onDebugModeChanged,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SwitchListTile(
            title: const Text('Dark Theme'),
            subtitle: const Text('Toggle between light and dark mode.'),
            value: isDarkMode,
            onChanged: onDarkModeChanged,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SwitchListTile(
            title: const Text('Units'),
            subtitle: Text(useMetric ? 'Metric (m, m/s)' : 'English (ft, mph)'),
            value: useMetric,
            onChanged: onUseMetricChanged,
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
                Text('Current: ${fontScale.toStringAsFixed(2)}x'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: fontScale <= minFontScale
                          ? null
                          : () {
                              onFontScaleChanged(fontScale - fontScaleStep);
                            },
                      icon: const Icon(Icons.remove),
                      label: const Text('Decrease'),
                    ),
                    OutlinedButton.icon(
                      onPressed: fontScale >= maxFontScale
                          ? null
                          : () {
                              onFontScaleChanged(fontScale + fontScaleStep);
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
                  subtitle: Text(
                    isTracking
                        ? 'Tracking is active.'
                        : (trackingEnabledPreference
                            ? 'Tracking did not start. $status'
                            : 'Tracking is stopped.'),
                  ),
                  value: isTracking,
                  onChanged: isChangingTrackingState
                      ? null
                      : onTrackingToggleChanged,
                ),
                const SizedBox(height: 10),
                Text(trackingSummary),
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
                  initialValue: closePollSeconds,
                  decoration: const InputDecoration(
                    labelText: 'Poll when close to a location',
                    border: OutlineInputBorder(),
                  ),
                  items: closePollSecondOptions
                      .map(
                        (int value) => DropdownMenuItem<int>(
                          value: value,
                          child: Text(formatSecondsOption(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (int? value) {
                    if (value == null) {
                      return;
                    }
                    onClosePollSecondsChanged(value);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: farPollSeconds,
                  decoration: const InputDecoration(
                    labelText: 'Poll when far from any location',
                    border: OutlineInputBorder(),
                  ),
                  items: farPollSecondOptions
                      .map(
                        (int value) => DropdownMenuItem<int>(
                          value: value,
                          child: Text(formatSecondsOption(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (int? value) {
                    if (value == null) {
                      return;
                    }
                    onFarPollSecondsChanged(value);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: farDistanceMeters,
                  decoration: const InputDecoration(
                    labelText: 'Consider far from locations at',
                    border: OutlineInputBorder(),
                  ),
                  items: farDistanceMeterOptions
                      .map(
                        (int value) => DropdownMenuItem<int>(
                          value: value,
                          child: Text(formatMetersOption(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (int? value) {
                    if (value == null) {
                      return;
                    }
                    onFarDistanceMetersChanged(value);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: outOfGeofenceRetriggerMinutes,
                  decoration: const InputDecoration(
                    labelText: 'Out-of-geofence retrigger',
                    border: OutlineInputBorder(),
                  ),
                  items: outOfGeofenceRetriggerMinuteOptions
                      .map(
                        (int value) => DropdownMenuItem<int>(
                          value: value,
                          child: Text(value == 60 ? '1 hr' : '$value min'),
                        ),
                      )
                      .toList(),
                  onChanged: (int? value) {
                    if (value == null) {
                      return;
                    }
                    onOutOfGeofenceRetriggerMinutesChanged(value);
                  },
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hide nearest when far'),
                  subtitle: Text(
                    'Hide nearest-location details when distance is beyond ${formatMetersOption(farDistanceMeters)}.',
                  ),
                  value: hideNearestWhenFar,
                  onChanged: onHideNearestWhenFarChanged,
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
                      onPressed: onOpenLocationSettings,
                      icon: const Icon(Icons.gps_fixed),
                      label: const Text('Location Settings'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onOpenAppSettings,
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
}
