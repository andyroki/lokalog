import '../models/lokalog_models.dart';

class ScenarioStateController {
  final List<JobSite> sites = <JobSite>[];
  final List<JobLog> logs = <JobLog>[];
  final Set<String> deletedLogKeys = <String>{};
  final Set<String> sessionLoggedAddresses = <String>{};
  final Map<String, double> timeInGeofenceMinutes = <String, double>{};
  final Map<String, DateTime> outOfGeofenceSince = <String, DateTime>{};

  bool isDuplicateLocationName(String name, {int? excludingIndex}) {
    final String normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }

    for (int index = 0; index < sites.length; index++) {
      if (excludingIndex != null && index == excludingIndex) {
        continue;
      }
      if (sites[index].name.trim().toLowerCase() == normalized) {
        return true;
      }
    }
    return false;
  }

  void addSite(JobSite site) {
    sites.add(site);
  }

  void updateSite(int index, JobSite site) {
    sites[index] = site;
  }

  JobSite removeSiteAt(int index) {
    return sites.removeAt(index);
  }

  void clearSites() {
    sites.clear();
  }

  void clearTrackingRuntimeState() {
    sessionLoggedAddresses.clear();
    timeInGeofenceMinutes.clear();
    outOfGeofenceSince.clear();
  }

  void addDeletedLogKey(String key) {
    deletedLogKeys.add(key);
  }

  void removeLogAt(int index) {
    logs.removeAt(index);
  }

  void addLog(JobLog log) {
    logs.insert(0, log);
  }

  void updateLogNotes(int index, String notes) {
    logs[index] = logs[index].copyWith(notes: notes);
  }

  void markLogCalendarAdded(String address, DateTime timestamp) {
    final int index = logs.indexWhere(
      (JobLog log) =>
          log.address == address &&
          log.timestamp.millisecondsSinceEpoch ==
              timestamp.millisecondsSinceEpoch,
    );
    if (index == -1 || logs[index].calendarAdded) {
      return;
    }
    logs[index] = logs[index].copyWith(calendarAdded: true);
  }

  void mergeLoadedLogs(Iterable<JobLog> loadedLogs) {
    final Set<String> existing = logs
        .map((JobLog log) =>
            '${log.address}|${log.timestamp.millisecondsSinceEpoch}')
        .toSet();

    for (final JobLog log in loadedLogs) {
      final String key =
          '${log.address}|${log.timestamp.millisecondsSinceEpoch}';
      if (existing.add(key)) {
        logs.insert(0, log);
      }
    }
  }

  void pruneTrackingStateToKnownSites() {
    final Set<String> validAddresses =
        sites.map((JobSite site) => site.address).toSet();

    sessionLoggedAddresses.removeWhere(
      (String address) => !validAddresses.contains(address),
    );
    timeInGeofenceMinutes.removeWhere(
      (String address, double _) => !validAddresses.contains(address),
    );
    outOfGeofenceSince.removeWhere(
      (String address, DateTime _) => !validAddresses.contains(address),
    );
  }

  void restoreTrackingRuntimeStateFromJson(Map<String, dynamic> decoded) {
    final List<String> loggedAddresses =
        ((decoded['sessionLoggedAddresses'] as List<dynamic>?) ?? <dynamic>[])
            .whereType<String>()
            .toList();

    final Map<String, double> parsedTimeInGeofenceMinutes = <String, double>{};
    final dynamic timeInGeofenceRaw =
        decoded['timeInGeofenceMinutes'] ?? decoded['dwellMinutes'];
    if (timeInGeofenceRaw is Map<String, dynamic>) {
      timeInGeofenceRaw.forEach((String key, dynamic value) {
        final double? parsed = (value as num?)?.toDouble();
        if (parsed != null && parsed >= 0) {
          parsedTimeInGeofenceMinutes[key] = parsed;
        }
      });
    }

    final Map<String, DateTime> parsedOutOfGeofenceSince = <String, DateTime>{};
    final dynamic outRaw = decoded['outOfGeofenceSince'];
    if (outRaw is Map<String, dynamic>) {
      outRaw.forEach((String key, dynamic value) {
        final int? epochMillis = (value as num?)?.toInt();
        if (epochMillis != null && epochMillis > 0) {
          parsedOutOfGeofenceSince[key] =
              DateTime.fromMillisecondsSinceEpoch(epochMillis);
        }
      });
    }

    sessionLoggedAddresses
      ..clear()
      ..addAll(loggedAddresses);
    timeInGeofenceMinutes
      ..clear()
      ..addAll(parsedTimeInGeofenceMinutes);
    outOfGeofenceSince
      ..clear()
      ..addAll(parsedOutOfGeofenceSince);
  }

  Map<String, dynamic> buildTrackingRuntimeStatePayload() {
    return <String, dynamic>{
      'sessionLoggedAddresses': sessionLoggedAddresses.toList(),
      // Keep both keys while migrating naming in persisted payloads.
      'timeInGeofenceMinutes': <String, double>{...timeInGeofenceMinutes},
      'dwellMinutes': <String, double>{...timeInGeofenceMinutes},
      'outOfGeofenceSince': outOfGeofenceSince.map(
        (String key, DateTime value) => MapEntry<String, int>(
          key,
          value.millisecondsSinceEpoch,
        ),
      ),
    };
  }
}
