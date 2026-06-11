import 'package:flutter/material.dart';

class ScenarioDialogService {
  static Future<bool> showTrackingOffStartupDialog(BuildContext context) async {
    if (!context.mounted) {
      return false;
    }

    final bool? openSettings = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Tracking Is Off'),
          content: const Text(
            'Tracking is currently off.\n\n'
            'To turn it on:\n'
            '1. Open the Settings tab.\n'
            '2. In Tracking Controls, switch Tracking On.\n'
            '3. Allow location permissions and location services if prompted.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );

    return openSettings == true;
  }

  static Future<bool> confirmStopTracking(BuildContext context) async {
    if (!context.mounted) {
      return false;
    }

    final bool? shouldStop = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Stop Tracking?'),
          content: const Text('Are you sure you want to turn tracking off?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Turn Off'),
            ),
          ],
        );
      },
    );

    return shouldStop == true;
  }

  static Future<bool> confirmAddLocationAction(
    BuildContext context, {
    required bool useCurrentLocation,
  }) async {
    if (!context.mounted) {
      return false;
    }

    final bool? shouldContinue = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Add Location?'),
          content: Text(
            useCurrentLocation
                ? 'Are you sure you want to add a location from current GPS?'
                : 'Are you sure you want to add a new location?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    return shouldContinue == true;
  }

  static Future<bool> confirmResetAllSites(BuildContext context) async {
    if (!context.mounted) {
      return false;
    }

    final bool? shouldReset = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Reset All Sites?'),
          content: const Text(
            'This will remove all saved locations. Are you sure?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reset All'),
            ),
          ],
        );
      },
    );

    return shouldReset == true;
  }

  static Future<bool> confirmDeleteLocation(
    BuildContext context, {
    required String siteName,
  }) async {
    if (!context.mounted) {
      return false;
    }

    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Location'),
          content: Text('Delete $siteName? This cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    return confirmDelete == true;
  }

  static Future<bool> confirmDeleteLogEntry(
    BuildContext context, {
    required String address,
  }) async {
    if (!context.mounted) {
      return false;
    }

    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Log Entry'),
          content: Text('Delete log for $address?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    return confirmDelete == true;
  }

  static Future<bool> showGoToSettingsDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    if (!context.mounted) {
      return false;
    }

    final bool? shouldOpen = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );

    return shouldOpen == true;
  }

  static Future<String?> editLogNotes(
    BuildContext context, {
    required String initialNotes,
  }) async {
    if (!context.mounted) {
      return null;
    }

    String draftNotes = initialNotes;
    final String? updatedNotes = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Edit Log Notes'),
          content: TextFormField(
            initialValue: draftNotes,
            onChanged: (String value) {
              draftNotes = value;
            },
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Add any details for this log entry...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(draftNotes.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    return updatedNotes;
  }
}
