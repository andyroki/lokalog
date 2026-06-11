import 'package:flutter/services.dart';

import '../models/lokalog_models.dart';

enum UsageAccessSettingsOpenResult {
  openedUsageAccessSettings,
  openedAppSettingsFallback,
  failed,
}

class BatteryUsageLoadResult {
  BatteryUsageLoadResult({
    required this.usageAccessGranted,
    required this.batteryUsage,
    this.deviceBatteryLevel,
    this.batteryUsageFetchedAt,
    this.errorMessage,
  });

  final bool usageAccessGranted;
  final List<DebugBatteryAppUsage> batteryUsage;
  final int? deviceBatteryLevel;
  final DateTime? batteryUsageFetchedAt;
  final String? errorMessage;
}

class BatteryUsageService {
  static Future<BatteryUsageLoadResult> loadBatteryUsage(
    MethodChannel channel,
  ) async {
    try {
      final bool hasUsageAccess =
          (await channel.invokeMethod<bool>('hasUsageAccessPermission')) ?? false;

      if (!hasUsageAccess) {
        return BatteryUsageLoadResult(
          usageAccessGranted: false,
          batteryUsage: <DebugBatteryAppUsage>[],
          errorMessage:
              'Usage access is required. Open Settings and allow Usage Access for this app.',
        );
      }

      final Map<Object?, Object?>? payload =
          await channel.invokeMethod<Map<Object?, Object?>>('getAppBatteryUsage');

      final List<dynamic> rawApps =
          (payload?['apps'] as List<dynamic>?) ?? <dynamic>[];
      final List<DebugBatteryAppUsage> parsed = rawApps
          .whereType<Map<Object?, Object?>>()
          .map((Map<Object?, Object?> item) {
            return DebugBatteryAppUsage(
              packageName: (item['packageName'] ?? '').toString(),
              appName: (item['appName'] ?? '').toString(),
              foregroundMinutes:
                  ((item['foregroundMinutes'] as num?)?.toDouble() ?? 0),
              estimatedBatterySharePercent:
                  ((item['estimatedBatterySharePercent'] as num?)?.toDouble() ??
                      0),
            );
          })
          .where((DebugBatteryAppUsage item) => item.foregroundMinutes > 0)
          .toList();

      final int generatedAtEpochMs =
          (payload?['generatedAtEpochMs'] as num?)?.toInt() ??
              DateTime.now().millisecondsSinceEpoch;

      return BatteryUsageLoadResult(
        usageAccessGranted: true,
        batteryUsage: parsed,
        deviceBatteryLevel: (payload?['deviceBatteryLevel'] as num?)?.toInt(),
        batteryUsageFetchedAt:
            DateTime.fromMillisecondsSinceEpoch(generatedAtEpochMs),
      );
    } on PlatformException catch (error) {
      return BatteryUsageLoadResult(
        usageAccessGranted: false,
        batteryUsage: <DebugBatteryAppUsage>[],
        errorMessage: error.message ?? 'Could not load app battery usage.',
      );
    } catch (_) {
      return BatteryUsageLoadResult(
        usageAccessGranted: false,
        batteryUsage: <DebugBatteryAppUsage>[],
        errorMessage: 'Could not load app battery usage.',
      );
    }
  }

  static Future<UsageAccessSettingsOpenResult> openUsageAccessSettings(
    MethodChannel channel,
  ) async {
    try {
      final bool opened =
          (await channel.invokeMethod<bool>('openUsageAccessSettings')) ?? false;
      if (opened) {
        return UsageAccessSettingsOpenResult.openedUsageAccessSettings;
      }

      await channel.invokeMethod<bool>('openAppSettings');
      return UsageAccessSettingsOpenResult.openedAppSettingsFallback;
    } catch (_) {
      return UsageAccessSettingsOpenResult.failed;
    }
  }
}
