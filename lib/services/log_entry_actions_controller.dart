import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/lokalog_models.dart';
import 'log_communication_service.dart';
import 'scenario_dialog_service.dart';

typedef AsyncKeyCallback = FutureOr<void> Function(String key);
typedef AsyncVoidCallback = FutureOr<void> Function();

class LogEntryActionsController {
  static Future<void> shareLogEntry({
    required BuildContext context,
    required MethodChannel channel,
    required JobLog log,
    required String Function(DateTime value) formatLogTimestamp,
  }) async {
    await LogCommunicationService.shareLogEntry(
      context: context,
      channel: channel,
      log: log,
      formatLogTimestamp: formatLogTimestamp,
    );
  }

  static Future<void> shareAllLogs({
    required BuildContext context,
    required MethodChannel channel,
    required Iterable<JobLog> logs,
    required String Function(DateTime value) formatLogTimestamp,
  }) async {
    await LogCommunicationService.shareAllLogs(
      context: context,
      channel: channel,
      logs: logs,
      formatLogTimestamp: formatLogTimestamp,
    );
  }

  static Future<void> handleAddLogToCalendar({
    required BuildContext context,
    required MethodChannel channel,
    required JobLog log,
    required AsyncKeyCallback onCalendarMarked,
  }) async {
    final bool opened = await LogCommunicationService.addLogToCalendar(
      context: context,
      channel: channel,
      log: log,
    );
    if (!opened) {
      return;
    }

    final String key = logStorageKey(
      address: log.address,
      timestampMillis: log.timestamp.millisecondsSinceEpoch,
    );
    await onCalendarMarked(key);
  }

  static Future<void> handleDeleteLogEntry({
    required BuildContext context,
    required MethodChannel channel,
    required JobLog log,
    required AsyncKeyCallback onDeletedKey,
    required AsyncKeyCallback onCalendarKeyRemoved,
    required AsyncVoidCallback removeLogFromState,
  }) async {
    final bool confirmDelete = await ScenarioDialogService.confirmDeleteLogEntry(
      context,
      address: log.address,
    );

    if (!confirmDelete) {
      return;
    }

    final String deletedKey = logStorageKey(
      address: log.address,
      timestampMillis: log.timestamp.millisecondsSinceEpoch,
    );

    await onDeletedKey(deletedKey);
    await onCalendarKeyRemoved(deletedKey);
    await removeLogFromState();

    try {
      await channel.invokeMethod<void>(
        'deleteBackgroundLog',
        <String, dynamic>{
          'address': log.address,
          'timestamp': log.timestamp.millisecondsSinceEpoch,
        },
      );
    } on MissingPluginException {
      // Desktop/iOS/web may not implement background log persistence.
    } on PlatformException {
      // Keep local delete behavior even if persistence fails.
    }
  }

  static Future<String?> requestEditedNotes(
    BuildContext context, {
    required JobLog log,
  }) {
    return ScenarioDialogService.editLogNotes(
      context,
      initialNotes: log.notes,
    );
  }

  static String logStorageKey({
    required String address,
    required int timestampMillis,
  }) {
    return '$address|$timestampMillis';
  }
}
