import 'package:flutter/material.dart';

import '../models/lokalog_models.dart';

class LogScreenView extends StatelessWidget {
  const LogScreenView({
    super.key,
    required this.statusText,
    required this.currentFix,
    required this.latestNearest,
    required this.pendingSite,
    required this.promptCountdown,
    required this.logs,
    required this.timeInGeofenceMinutesByAddress,
    required this.outOfGeofenceMinutesByAddress,
    required this.formatElapsedMinutes,
    required this.formatLogTimestamp,
    required this.buildNearestMessage,
    required this.onDismissPendingPrompt,
    required this.onLogNow,
    required this.onShareAllLogs,
    required this.onShareLogEntry,
    required this.onAddLogToCalendar,
    required this.onEditLogEntry,
    required this.onDeleteLogEntry,
  });

  final String statusText;
  final LocationFix? currentFix;
  final SiteDistance? latestNearest;
  final JobSite? pendingSite;
  final int promptCountdown;
  final List<JobLog> logs;
  final Map<String, double> timeInGeofenceMinutesByAddress;
  final Map<String, double> outOfGeofenceMinutesByAddress;
  final String Function(double) formatElapsedMinutes;
  final String Function(DateTime value) formatLogTimestamp;
  final String Function(SiteDistance nearest) buildNearestMessage;
  final VoidCallback onDismissPendingPrompt;
  final ValueChanged<JobSite> onLogNow;
  final VoidCallback onShareAllLogs;
  final ValueChanged<JobLog> onShareLogEntry;
  final ValueChanged<JobLog> onAddLogToCalendar;
  final void Function(int index, JobLog log) onEditLogEntry;
  final void Function(int index, JobLog log) onDeleteLogEntry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _sectionCard(
          context,
          title: 'Live Status',
          icon: Icons.wifi_tethering,
          child: Text(statusText),
        ),
        const SizedBox(height: 12),
        if (currentFix != null)
          _sectionCard(
            context,
            title: 'Current GPS',
            icon: Icons.my_location,
            child: Text(
              '${currentFix!.lat.toStringAsFixed(5)}, ${currentFix!.lng.toStringAsFixed(5)}\n'
              'Accuracy: ${_fmtAccuracy(currentFix!.accuracyMeters)} | '
              'Speed: ${_fmtSpeed(currentFix!.speedMetersPerSecond)}',
            ),
          ),
        if (currentFix != null) const SizedBox(height: 12),
        if (latestNearest != null)
          Builder(
            builder: (BuildContext context) {
              final SiteDistance nearest = latestNearest!;
              final String message = buildNearestMessage(nearest);

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.radar,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        if (latestNearest != null) const SizedBox(height: 12),
        if (pendingSite != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.tertiary.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.timer,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ready to log ${pendingSite!.name}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Auto-log in ${promptCountdown}s',
                  style: TextStyle(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    TextButton(
                      onPressed: onDismissPendingPrompt,
                      child: const Text('Dismiss'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () {
                        final JobSite? site = pendingSite;
                        if (site == null) {
                          return;
                        }
                        onLogNow(site);
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Log Now'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (pendingSite != null) const SizedBox(height: 16),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Locations Log',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onShareAllLogs,
              icon: const Icon(Icons.share),
              label: const Text('Share All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (logs.isEmpty)
          const Text('No locations logged yet.')
        else
          ...logs.asMap().entries.map((MapEntry<int, JobLog> entry) {
            final int index = entry.key;
            final JobLog log = entry.value;
            final String clientName =
                log.name.trim().isEmpty ? 'Client' : log.name.trim();
            final String address = log.address.trim();
            final String notes = log.notes.trim();
            final bool showAddressLine =
                address.isNotEmpty && address != clientName;
            final double timeInGeofence =
                timeInGeofenceMinutesByAddress[address] ?? 0;
            final double outOfGeofence =
                outOfGeofenceMinutesByAddress[address] ?? 0;
            return Card(
              color: isDark ? theme.colorScheme.surfaceContainerHigh : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            clientName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            IconButton(
                              tooltip: 'Share log',
                              onPressed: () => onShareLogEntry(log),
                              icon: const Icon(Icons.share),
                            ),
                            IconButton(
                              tooltip: 'Add to calendar',
                              onPressed: () => onAddLogToCalendar(log),
                              icon: _buildCalendarIcon(log.calendarAdded),
                            ),
                            IconButton(
                              tooltip: 'Edit log notes',
                              onPressed: () => onEditLogEntry(index, log),
                              icon: const Icon(Icons.edit_note),
                            ),
                            IconButton(
                              tooltip: 'Delete log',
                              onPressed: () => onDeleteLogEntry(index, log),
                              icon: const Icon(Icons.delete),
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${showAddressLine ? '$address\n' : ''}'
                      '${formatLogTimestamp(log.timestamp)}\n'
                      'Confidence: ${log.confidence.toStringAsFixed(1)}% | '
                      '${log.confirmedByUser ? 'confirmed' : 'auto-logged'}'
                      '\nTime in geofence: ${formatElapsedMinutes(timeInGeofence)} | '
                      'Time out geofence: ${formatElapsedMinutes(outOfGeofence)}'
                      '${notes.isEmpty ? '' : '\nNotes: $notes'}',
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  String _fmtAccuracy(double meters) {
    return '${meters.toStringAsFixed(1)} m';
  }

  String _fmtSpeed(double metersPerSecond) {
    return '${metersPerSecond.toStringAsFixed(1)} m/s';
  }

  Widget _buildCalendarIcon(bool calendarAdded) {
    if (!calendarAdded) {
      return const Icon(Icons.event_available);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        const Icon(Icons.event_available),
        Positioned(
          right: -2,
          top: -2,
          child: Icon(
            Icons.check_circle,
            size: 14,
            color: Colors.green.shade600,
          ),
        ),
      ],
    );
  }
}
