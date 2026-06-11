import 'package:flutter/material.dart';

import '../models/lokalog_models.dart';

class DebugScreenView extends StatelessWidget {
  const DebugScreenView({
    super.key,
    required this.appVersionLabel,
    required this.showBatteryInfo,
    required this.onShowBatteryInfoChanged,
    required this.pollingDebugSummary,
    required this.appReadinessDebugSummary,
    required this.geofenceDecisionDebugSummary,
    required this.rawGpsDebugSummary,
    required this.trackingRuntimeStateDebugSummary,
    required this.locationTrackingStatesDebugSummary,
    required this.onRetriggerCurrentSite,
    required this.isLoadingBatteryUsage,
    required this.onRefreshBatteryUsage,
    required this.onOpenUsageAccessSettings,
    required this.usageAccessGranted,
    required this.deviceBatteryLevel,
    required this.batteryUsageFetchedAt,
    required this.batteryUsageError,
    required this.batteryUsage,
  });

  final String appVersionLabel;
  final bool showBatteryInfo;
  final ValueChanged<bool> onShowBatteryInfoChanged;
  final String pollingDebugSummary;
  final String appReadinessDebugSummary;
  final String geofenceDecisionDebugSummary;
  final String rawGpsDebugSummary;
  final String trackingRuntimeStateDebugSummary;
  final String locationTrackingStatesDebugSummary;
  final VoidCallback onRetriggerCurrentSite;
  final bool isLoadingBatteryUsage;
  final VoidCallback onRefreshBatteryUsage;
  final VoidCallback onOpenUsageAccessSettings;
  final bool usageAccessGranted;
  final int? deviceBatteryLevel;
  final DateTime? batteryUsageFetchedAt;
  final String? batteryUsageError;
  final List<DebugBatteryAppUsage> batteryUsage;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: ListTile(
            title: const Text('App Version'),
            subtitle: Text(appVersionLabel),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SwitchListTile(
            title: const Text('Show Battery Info'),
            subtitle: const Text('Show or hide battery diagnostics below.'),
            value: showBatteryInfo,
            onChanged: onShowBatteryInfoChanged,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(pollingDebugSummary),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(appReadinessDebugSummary),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(geofenceDecisionDebugSummary),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(rawGpsDebugSummary),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(trackingRuntimeStateDebugSummary),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(locationTrackingStatesDebugSummary),
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
                  'Reset dwell timing for the nearest site so it can log again after required in-geofence time.',
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: onRetriggerCurrentSite,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Retrigger Now'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (showBatteryInfo) ...<Widget>[
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
                        onPressed: isLoadingBatteryUsage
                            ? null
                            : onRefreshBatteryUsage,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh Battery Usage'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onOpenUsageAccessSettings,
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                        label: const Text('Usage Access Settings'),
                      ),
                    ],
                  ),
                  if (isLoadingBatteryUsage) ...<Widget>[
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
                    usageAccessGranted
                        ? 'Usage Access: Granted'
                        : 'Usage Access: Not Granted',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: usageAccessGranted ? Colors.green : Colors.orange,
                    ),
                  ),
                  if (deviceBatteryLevel != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text('Current device battery: ${deviceBatteryLevel!}%'),
                  ],
                  if (batteryUsageFetchedAt != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text('Last updated: ${batteryUsageFetchedAt!.toLocal()}'),
                  ],
                  if (batteryUsageError != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      batteryUsageError!,
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
          if (batteryUsage.isEmpty && !isLoadingBatteryUsage)
            const Text('No data yet. Grant Usage Access and tap Refresh.')
          else
            ...batteryUsage.map((DebugBatteryAppUsage app) {
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
}
