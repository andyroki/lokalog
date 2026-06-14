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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(statusText),
          ),
        ),
        if (currentFix != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Current GPS: ${currentFix!.lat.toStringAsFixed(5)}, '
                '${currentFix!.lng.toStringAsFixed(5)}\n'
                'Accuracy: ${_fmtAccuracy(currentFix!.accuracyMeters)} | '
                'Speed: ${_fmtSpeed(currentFix!.speedMetersPerSecond)}',
              ),
            ),
          ),
        if (latestNearest != null)
          Builder(
            builder: (BuildContext context) {
              final SiteDistance nearest = latestNearest!;
              final String message = buildNearestMessage(nearest);

              return Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    message,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              );
            },
          ),
        if (pendingSite != null)
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Ready to log ${pendingSite!.name}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Auto-log in ${promptCountdown}s',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
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
          ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'Locations Log',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            return Card(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.surfaceContainerHigh
                  : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        alignment: WrapAlignment.end,
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
                    ),
                    Text('Customer: $clientName'),
                    const SizedBox(height: 4),
                    Text(
                      '${showAddressLine ? '$address\n' : ''}'
                      '${formatLogTimestamp(log.timestamp)}\n'
                      'Confidence: ${log.confidence.toStringAsFixed(1)}% | '
                      '${log.confirmedByUser ? 'confirmed' : 'auto-logged'}'
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
