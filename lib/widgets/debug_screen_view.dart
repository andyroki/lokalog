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
    required this.startupLoggingDiagnosticsSummary,
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
  final String startupLoggingDiagnosticsSummary;
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
        _sectionCard(
          context,
          title: 'System',
          subtitle: 'Build and global debug options',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.info_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'App Version: $appVersionLabel',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show Battery Info'),
                subtitle:
                    const Text('Show or hide battery diagnostics below.'),
                value: showBatteryInfo,
                onChanged: onShowBatteryInfoChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _summaryCard(
          context,
          title: 'Polling',
          subtitle: 'Current polling mode and interval state',
          content: pollingDebugSummary,
        ),
        const SizedBox(height: 12),
        _summaryCard(
          context,
          title: 'App Readiness',
          subtitle: 'Tracking toggles, startup state, and active timers',
          content: appReadinessDebugSummary,
        ),
        const SizedBox(height: 12),
        _summaryCard(
          context,
          title: 'Geofence Decision',
          subtitle: 'Nearest site, stable samples, candidate, and prompt state',
          content: geofenceDecisionDebugSummary,
        ),
        const SizedBox(height: 12),
        _summaryCard(
          context,
          title: 'Startup and Logging Gates',
          subtitle: 'Startup checks and nearest-site logging diagnostics',
          content: startupLoggingDiagnosticsSummary,
        ),
        const SizedBox(height: 12),
        _summaryCard(
          context,
          title: 'Raw GPS',
          subtitle: 'Latest raw GPS payload and read errors',
          content: rawGpsDebugSummary,
        ),
        const SizedBox(height: 12),
        _summaryCard(
          context,
          title: 'Runtime State',
          subtitle: 'Restore/save timing state and tracked-site counts',
          content: trackingRuntimeStateDebugSummary,
        ),
        const SizedBox(height: 12),
        _summaryCard(
          context,
          title: 'Location Tracking States',
          subtitle: 'Per-site in/out/far state with dwell and remaining time',
          content: locationTrackingStatesDebugSummary,
        ),
        const SizedBox(height: 12),
        _sectionCard(
          context,
          title: 'Manual Action',
          subtitle: 'Force retrigger flow for nearest site',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
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
        const SizedBox(height: 12),
        if (showBatteryInfo) ...<Widget>[
          _sectionCard(
            context,
            title: 'Battery Tools',
            subtitle: 'Refresh usage data and open permission shortcuts',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed:
                          isLoadingBatteryUsage ? null : onRefreshBatteryUsage,
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
          const SizedBox(height: 12),
          _sectionCard(
            context,
            title: 'Battery Status',
            subtitle: 'Permission and last refresh state',
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

  Widget _summaryCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String content,
  }) {
    return _sectionCard(
      context,
      title: title,
      subtitle: subtitle,
      child: SelectableText(
        content,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              height: 1.35,
            ),
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
