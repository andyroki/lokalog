import 'package:flutter/material.dart';

class SettingsScreenView extends StatefulWidget {
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
    required this.locationLimitUnlocked,
    required this.onLocationUnlockCodeSubmitted,
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
  final bool locationLimitUnlocked;
  final ValueChanged<String> onLocationUnlockCodeSubmitted;

  @override
  State<SettingsScreenView> createState() => _SettingsScreenViewState();
}

class _SettingsScreenViewState extends State<SettingsScreenView> {
  final TextEditingController _unlockCodeController = TextEditingController();

  @override
  void dispose() {
    _unlockCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: SwitchListTile(
            title: const Text('Debug Mode'),
            subtitle: const Text('Show or hide the Debug tab and tools.'),
            value: widget.debugModeEnabled,
            onChanged: widget.onDebugModeChanged,
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
            subtitle: Text(
              widget.useMetric ? 'Metric (m, m/s)' : 'English (ft, mph)',
            ),
            value: widget.useMetric,
            onChanged: widget.onUseMetricChanged,
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
                  'Location Limit Unlock',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.locationLimitUnlocked
                      ? 'Unlocked: you can add more than 5 locations.'
                      : 'Enter unlock code to allow more than 5 locations.',
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _unlockCodeController,
                        enabled: !widget.locationLimitUnlocked,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Unlock code',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (String value) {
                          if (value.trim().isEmpty ||
                              widget.locationLimitUnlocked) {
                            return;
                          }
                          widget.onLocationUnlockCodeSubmitted(value);
                          _unlockCodeController.clear();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: widget.locationLimitUnlocked
                          ? null
                          : () {
                              final String value =
                                  _unlockCodeController.text.trim();
                              if (value.isEmpty) {
                                return;
                              }
                              widget.onLocationUnlockCodeSubmitted(value);
                              _unlockCodeController.clear();
                            },
                      child: const Text('Unlock'),
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
                  'Font Size',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Current: ${widget.fontScale.toStringAsFixed(2)}x'),
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
                  subtitle: Text(
                    widget.isTracking
                        ? 'Tracking is active.'
                        : (widget.trackingEnabledPreference
                            ? 'Tracking did not start. ${widget.status}'
                            : 'Tracking is stopped.'),
                  ),
                  value: widget.isTracking,
                  onChanged: widget.isChangingTrackingState
                      ? null
                      : widget.onTrackingToggleChanged,
                ),
                const SizedBox(height: 10),
                Text(widget.trackingSummary),
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
                  initialValue: widget.closePollSeconds,
                  decoration: const InputDecoration(
                    labelText: 'Poll when close to a location',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.closePollSecondOptions
                      .map(
                        (int value) => DropdownMenuItem<int>(
                          value: value,
                          child: Text(widget.formatSecondsOption(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (int? value) {
                    if (value == null) {
                      return;
                    }
                    widget.onClosePollSecondsChanged(value);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: widget.farPollSeconds,
                  decoration: const InputDecoration(
                    labelText: 'Poll when far from any location',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.farPollSecondOptions
                      .map(
                        (int value) => DropdownMenuItem<int>(
                          value: value,
                          child: Text(widget.formatSecondsOption(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (int? value) {
                    if (value == null) {
                      return;
                    }
                    widget.onFarPollSecondsChanged(value);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: widget.farDistanceMeters,
                  decoration: const InputDecoration(
                    labelText: 'Consider far from locations at',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.farDistanceMeterOptions
                      .map(
                        (int value) => DropdownMenuItem<int>(
                          value: value,
                          child: Text(widget.formatMetersOption(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (int? value) {
                    if (value == null) {
                      return;
                    }
                    widget.onFarDistanceMetersChanged(value);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: widget.outOfGeofenceRetriggerMinutes,
                  decoration: const InputDecoration(
                    labelText: 'Out-of-geofence retrigger',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.outOfGeofenceRetriggerMinuteOptions
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
                    widget.onOutOfGeofenceRetriggerMinutesChanged(value);
                  },
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hide nearest when far'),
                  subtitle: Text(
                    'Hide nearest-location details when distance is beyond ${widget.formatMetersOption(widget.farDistanceMeters)}.',
                  ),
                  value: widget.hideNearestWhenFar,
                  onChanged: widget.onHideNearestWhenFarChanged,
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
                      onPressed: widget.onOpenLocationSettings,
                      icon: const Icon(Icons.gps_fixed),
                      label: const Text('Location Settings'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.onOpenAppSettings,
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
