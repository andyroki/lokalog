import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/lokalog_models.dart';

class LogCommunicationService {
  static String buildShareTextForLog(
    JobLog log,
    String Function(DateTime value) formatLogTimestamp,
  ) {
    final String clientName = log.name.trim().isEmpty ? 'Client' : log.name;
    final String notesLine =
      log.notes.trim().isEmpty ? 'Notes: none\n' : 'Notes: ${log.notes.trim()}\n';
    final String firstInGeofenceLine = log.firstInGeofenceAt == null
      ? 'First in geofence: n/a\n'
      : 'First in geofence: ${formatLogTimestamp(log.firstInGeofenceAt!)}\n';
    final String lastInGeofenceLine = log.lastInGeofenceAt == null
      ? 'Last in geofence: n/a\n'
      : 'Last in geofence: ${formatLogTimestamp(log.lastInGeofenceAt!)}\n';
    final String timeInGeofenceLine = log.timeInGeofenceMinutesAtLog == null
      ? 'Time in geofence at log: n/a\n'
      : 'Time in geofence at log: ${log.timeInGeofenceMinutesAtLog!.toStringAsFixed(1)} min\n';
    final String timeRemainingLine = log.timeRemainingMinutesAtLog == null
      ? 'Time remaining at log: n/a\n'
      : 'Time remaining at log: ${log.timeRemainingMinutesAtLog!.toStringAsFixed(1)} min\n';

    return 'Lokalog Job Log\n'
        'Customer: $clientName\n'
        'Address: ${log.address}\n'
        'Time: ${formatLogTimestamp(log.timestamp)}\n'
        'Latitude: ${log.lat.toStringAsFixed(6)}\n'
        'Longitude: ${log.lng.toStringAsFixed(6)}\n'
        'Confidence: ${log.confidence.toStringAsFixed(1)}%\n'
        'Confirmed by user: ${log.confirmedByUser}\n'
        'Auto-logged: ${log.autoLogged}\n'
        'Calendar added: ${log.calendarAdded}\n'
        '$firstInGeofenceLine'
        '$lastInGeofenceLine'
        '$timeInGeofenceLine'
        '$timeRemainingLine'
        '$notesLine'
        'Type: ${log.confirmedByUser ? 'confirmed' : 'auto-logged'}';
  }

  static Future<void> shareLogEntry({
    required BuildContext context,
    required MethodChannel channel,
    required JobLog log,
    required String Function(DateTime value) formatLogTimestamp,
  }) async {
    final String clientName = log.name.trim().isEmpty ? 'Client' : log.name;
    await shareText(
      context: context,
      channel: channel,
      text: buildShareTextForLog(log, formatLogTimestamp),
      subject: 'Lokalog: $clientName',
    );
  }

  static Future<void> shareAllLogs({
    required BuildContext context,
    required MethodChannel channel,
    required Iterable<JobLog> logs,
    required String Function(DateTime value) formatLogTimestamp,
  }) async {
    final List<JobLog> allLogs = logs.toList();
    if (allLogs.isEmpty) {
      _showSnack(context, 'No logs available to share.');
      return;
    }

    final String joined = allLogs
        .map((JobLog log) => buildShareTextForLog(log, formatLogTimestamp))
        .join('\n\n----------------\n\n');

    await shareText(
      context: context,
      channel: channel,
      text: joined,
      subject: 'Lokalog: ${allLogs.length} shared logs',
    );
  }

  static Future<bool> addLogToCalendar({
    required BuildContext context,
    required MethodChannel channel,
    required JobLog log,
  }) async {
    final String clientName = log.name.trim().isEmpty ? 'Client' : log.name;
    final int startMillis = log.timestamp.millisecondsSinceEpoch;
    final int endMillis =
        log.timestamp.add(const Duration(minutes: 30)).millisecondsSinceEpoch;
    final String notesLine =
        log.notes.trim().isEmpty ? '' : '\nNotes: ${log.notes.trim()}';

    try {
      await channel.invokeMethod<void>(
        'addLogToCalendar',
        <String, dynamic>{
          'title': 'LokaLog Visit: $clientName',
          'description':
              'Customer: $clientName\nAddress: ${log.address}\nConfidence: ${log.confidence.toStringAsFixed(1)}%$notesLine',
          'location': log.address,
          'startMillis': startMillis,
          'endMillis': endMillis,
        },
      );
      return true;
    } on MissingPluginException {
      if (!context.mounted) {
        return false;
      }
      _showSnack(
          context, 'Calendar add is currently supported on Android only.');
      return false;
    } on PlatformException catch (error) {
      if (!context.mounted) {
        return false;
      }
      if (error.code == 'CALENDAR_UNAVAILABLE') {
        _showSnack(context, 'No calendar app found on this device.');
      } else {
        _showSnack(context, 'Could not open calendar app.');
      }
      return false;
    } catch (_) {
      if (!context.mounted) {
        return false;
      }
      _showSnack(context, 'Could not open calendar app.');
      return false;
    }
  }

  static Future<void> shareText({
    required BuildContext context,
    required MethodChannel channel,
    required String text,
    required String subject,
  }) async {
    try {
      await channel.invokeMethod<void>(
        'shareText',
        <String, dynamic>{
          'text': text,
          'subject': subject,
        },
      );
    } on MissingPluginException {
      if (!context.mounted) {
        return;
      }
      _showSnack(context, 'Share is currently supported on Android only.');
    } on PlatformException {
      if (!context.mounted) {
        return;
      }
      _showSnack(context, 'Could not open share sheet.');
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      _showSnack(context, 'Could not open share sheet.');
    }
  }

  static Future<void> showLogReminderNotification({
    required MethodChannel channel,
    required JobSite site,
    required int countdown,
  }) async {
    try {
      await channel.invokeMethod<void>(
        'showLogReminderNotification',
        <String, dynamic>{
          'name': site.name,
          'address': site.address,
          'countdownSeconds': countdown,
        },
      );
    } on MissingPluginException {
      // Notification reminder is Android-only in this build.
    } on PlatformException {
      // Keep core log flow even if notification fails.
    }
  }

  static Future<void> cancelLogReminderNotification({
    required MethodChannel channel,
  }) async {
    try {
      await channel.invokeMethod<void>('cancelLogReminderNotification');
    } on MissingPluginException {
      // Notification reminder is Android-only in this build.
    } on PlatformException {
      // Ignore cancellation errors.
    }
  }

  static void _showSnack(BuildContext context, String message) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
