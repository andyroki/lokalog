package com.lokalog_app

import android.Manifest
import android.app.AppOpsManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.os.Build
import android.content.pm.PackageManager
import android.net.Uri
import android.os.BatteryManager
import android.os.Looper
import android.provider.CalendarContract
import android.provider.Settings
import android.location.LocationManager
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
	private val channelName = "lokalog/location"
	private val sitesStorageKey = "saved_job_sites_v1"
	private val locationPermissionRequestCode = 1001
	private val logReminderChannelId = "lokalog_log_reminder_channel"
	private val logReminderNotificationId = 7301
	private var permissionResult: MethodChannel.Result? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
				when (call.method) {
					"loadPreference" -> {
						val key = call.argument<String>("key")
						if (key.isNullOrBlank()) {
							result.error("INVALID_ARGUMENT", "Missing key", null)
							return@setMethodCallHandler
						}
						val prefs = getSharedPreferences("lokalog_store", MODE_PRIVATE)
						result.success(prefs.getString(key, null))
					}

					"savePreference" -> {
						val key = call.argument<String>("key")
						val value = call.argument<String>("value")
						if (key.isNullOrBlank() || value == null) {
							result.error("INVALID_ARGUMENT", "Missing key or value", null)
							return@setMethodCallHandler
						}
						val prefs = getSharedPreferences("lokalog_store", MODE_PRIVATE)
						prefs.edit().putString(key, value).apply()
						result.success(null)
					}

					"isLocationServiceEnabled" -> {
						result.success(isLocationServiceEnabled())
					}

					"checkAndRequestPermission" -> {
						checkAndRequestPermission(result)
					}

					"getCurrentLocation" -> {
						getCurrentLocation(result)
					}

					"loadSites" -> {
						val prefs = getSharedPreferences("lokalog_store", MODE_PRIVATE)
						val sitesJson = prefs.getString(sitesStorageKey, null)
						result.success(sitesJson)
						GeofenceBackground.syncGeofences(this)
					}

					"saveSites" -> {
						val key = call.argument<String>("key") ?: sitesStorageKey
						val value = call.argument<String>("value")
						if (value == null) {
							result.error("INVALID_ARGUMENT", "Missing value", null)
							return@setMethodCallHandler
						}
						val prefs = getSharedPreferences("lokalog_store", MODE_PRIVATE)
						prefs.edit().putString(key, value).apply()
						GeofenceBackground.syncGeofences(this)
						result.success(null)
					}

					"loadBackgroundLogs" -> {
						result.success(GeofenceBackground.loadBackgroundLogsJson(this))
					}

					"deleteBackgroundLog" -> {
						val address = call.argument<String>("address")
						val timestamp = call.argument<Number>("timestamp")?.toLong()
						if (address.isNullOrBlank() || timestamp == null) {
							result.error("INVALID_ARGUMENT", "Missing address or timestamp", null)
							return@setMethodCallHandler
						}
						GeofenceBackground.deleteBackgroundLog(this, address, timestamp)
						result.success(null)
					}

					"hasBackgroundLocationPermission" -> {
						result.success(GeofenceBackground.hasBackgroundLocationPermission(this))
					}

					"openLocationSettings" -> {
						openLocationSettings(result)
					}

					"openAppSettings" -> {
						openAppSettings(result)
					}

					"hasUsageAccessPermission" -> {
						result.success(hasUsageStatsPermission())
					}

					"openUsageAccessSettings" -> {
						openUsageAccessSettings(result)
					}

					"getAppBatteryUsage" -> {
						getAppBatteryUsage(result)
					}

					"shareText" -> {
						val text = call.argument<String>("text")
						val subject = call.argument<String>("subject")
						if (text.isNullOrBlank()) {
							result.error("INVALID_ARGUMENT", "Missing text", null)
							return@setMethodCallHandler
						}
						shareText(text, subject)
						result.success(true)
					}

					"addLogToCalendar" -> {
						val title = call.argument<String>("title")
						val description = call.argument<String>("description")
						val location = call.argument<String>("location")
						val startMillis = call.argument<Number>("startMillis")?.toLong()
						val endMillis = call.argument<Number>("endMillis")?.toLong()
						if (title.isNullOrBlank() || startMillis == null || endMillis == null) {
							result.error("INVALID_ARGUMENT", "Missing title/startMillis/endMillis", null)
							return@setMethodCallHandler
						}
						addLogToCalendar(
							title = title,
							description = description,
							location = location,
							startMillis = startMillis,
							endMillis = endMillis,
							result = result
						)
					}

					"showLogReminderNotification" -> {
						val address = call.argument<String>("address")
						val name = call.argument<String>("name")
						val countdownSeconds = call.argument<Number>("countdownSeconds")?.toInt() ?: 12
						if (address.isNullOrBlank()) {
							result.error("INVALID_ARGUMENT", "Missing address", null)
							return@setMethodCallHandler
						}
						showLogReminderNotification(
							address = address,
							name = name,
							countdownSeconds = countdownSeconds
						)
						result.success(true)
					}

					"cancelLogReminderNotification" -> {
						cancelLogReminderNotification()
						result.success(true)
					}

					else -> result.notImplemented()
				}
			}
	}

	private fun shareText(text: String, subject: String?) {
		val intent = Intent(Intent.ACTION_SEND).apply {
			type = "text/plain"
			putExtra(Intent.EXTRA_TEXT, text)
			if (!subject.isNullOrBlank()) {
				putExtra(Intent.EXTRA_SUBJECT, subject)
			}
		}
		val chooser = Intent.createChooser(intent, "Share log")
		chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
		startActivity(chooser)
	}

	private fun addLogToCalendar(
		title: String,
		description: String?,
		location: String?,
		startMillis: Long,
		endMillis: Long,
		result: MethodChannel.Result
	) {
		val withDataUri = Intent(Intent.ACTION_INSERT).apply {
			data = CalendarContract.Events.CONTENT_URI
			putExtra(CalendarContract.Events.TITLE, title)
			if (!description.isNullOrBlank()) {
				putExtra(CalendarContract.Events.DESCRIPTION, description)
			}
			if (!location.isNullOrBlank()) {
				putExtra(CalendarContract.Events.EVENT_LOCATION, location)
			}
			putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, startMillis)
			putExtra(CalendarContract.EXTRA_EVENT_END_TIME, endMillis)
			addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
		}

		val withEventType = Intent(Intent.ACTION_INSERT).apply {
			type = "vnd.android.cursor.item/event"
			putExtra(CalendarContract.Events.TITLE, title)
			if (!description.isNullOrBlank()) {
				putExtra(CalendarContract.Events.DESCRIPTION, description)
			}
			if (!location.isNullOrBlank()) {
				putExtra(CalendarContract.Events.EVENT_LOCATION, location)
			}
			putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, startMillis)
			putExtra(CalendarContract.EXTRA_EVENT_END_TIME, endMillis)
			addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
		}

		try {
			startActivity(withDataUri)
			result.success(true)
		} catch (_: ActivityNotFoundException) {
			try {
				startActivity(withEventType)
				result.success(true)
			} catch (_: ActivityNotFoundException) {
				result.error("CALENDAR_UNAVAILABLE", "No calendar app available", null)
			} catch (error: Exception) {
				result.error("CALENDAR_FAILED", error.message, null)
			}
		} catch (error: Exception) {
			result.error("CALENDAR_FAILED", error.message, null)
		}
	}

	private fun showLogReminderNotification(address: String, name: String?, countdownSeconds: Int) {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
			val granted = ContextCompat.checkSelfPermission(
				this,
				Manifest.permission.POST_NOTIFICATIONS
			) == PackageManager.PERMISSION_GRANTED
			if (!granted) {
				return
			}
		}

		ensureLogReminderNotificationChannel()
		val customerLabel = if (name.isNullOrBlank()) "Client" else name
		val message = "$customerLabel at $address. Auto-log in ${countdownSeconds}s if no response."

		val notification = NotificationCompat.Builder(this, logReminderChannelId)
			.setSmallIcon(android.R.drawable.ic_dialog_info)
			.setContentTitle("Lokalog reminder")
			.setContentText(message)
			.setStyle(NotificationCompat.BigTextStyle().bigText(message))
			.setPriority(NotificationCompat.PRIORITY_HIGH)
			.setAutoCancel(true)
			.build()

		NotificationManagerCompat.from(this).notify(logReminderNotificationId, notification)
	}

	private fun cancelLogReminderNotification() {
		NotificationManagerCompat.from(this).cancel(logReminderNotificationId)
	}

	private fun ensureLogReminderNotificationChannel() {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
			return
		}

		val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
		val existing = manager.getNotificationChannel(logReminderChannelId)
		if (existing != null) {
			return
		}

		val channel = NotificationChannel(
			logReminderChannelId,
			"Log reminders",
			NotificationManager.IMPORTANCE_HIGH
		).apply {
			description = "Reminders to confirm nearby location logs."
		}
		manager.createNotificationChannel(channel)
	}

	private fun openLocationSettings(result: MethodChannel.Result) {
		try {
			val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
			intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
			startActivity(intent)
			result.success(true)
		} catch (error: Exception) {
			result.error("OPEN_SETTINGS_FAILED", error.message, null)
		}
	}

	private fun openAppSettings(result: MethodChannel.Result) {
		try {
			val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
			intent.data = Uri.parse("package:$packageName")
			intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
			startActivity(intent)
			result.success(true)
		} catch (error: Exception) {
			result.error("OPEN_SETTINGS_FAILED", error.message, null)
		}
	}

	private fun openUsageAccessSettings(result: MethodChannel.Result) {
		try {
			val intents = listOf(
				Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS),
				Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
					data = Uri.parse("package:$packageName")
				},
				Intent(Settings.ACTION_SECURITY_SETTINGS),
				Intent(Settings.ACTION_MANAGE_APPLICATIONS_SETTINGS),
				Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
					data = Uri.parse("package:$packageName")
				}
			)

			for (intent in intents) {
				intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
				if (intent.resolveActivity(packageManager) != null) {
					startActivity(intent)
					result.success(true)
					return
				}
			}

			result.success(false)
		} catch (error: Exception) {
			Log.w("LokaLog", "Failed to open Usage Access settings", error)
			result.success(false)
		}
	}

	private fun isLocationServiceEnabled(): Boolean {
		val manager = getSystemService(LOCATION_SERVICE) as LocationManager
		return manager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
			manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
	}

	private fun hasLocationPermission(): Boolean {
		val fine = ContextCompat.checkSelfPermission(
			this,
			Manifest.permission.ACCESS_FINE_LOCATION
		) == PackageManager.PERMISSION_GRANTED
		val coarse = ContextCompat.checkSelfPermission(
			this,
			Manifest.permission.ACCESS_COARSE_LOCATION
		) == PackageManager.PERMISSION_GRANTED
		return fine || coarse
	}

	private fun hasBackgroundLocationPermission(): Boolean {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
			return true
		}
		return ContextCompat.checkSelfPermission(
			this,
			Manifest.permission.ACCESS_BACKGROUND_LOCATION
		) == PackageManager.PERMISSION_GRANTED
	}

	private fun hasUsageStatsPermission(): Boolean {
		val appOps = getSystemService(APP_OPS_SERVICE) as AppOpsManager
		val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
			appOps.unsafeCheckOpNoThrow(
				AppOpsManager.OPSTR_GET_USAGE_STATS,
				android.os.Process.myUid(),
				packageName
			)
		} else {
			@Suppress("DEPRECATION")
			appOps.checkOpNoThrow(
				AppOpsManager.OPSTR_GET_USAGE_STATS,
				android.os.Process.myUid(),
				packageName
			)
		}
		return mode == AppOpsManager.MODE_ALLOWED
	}

	private fun checkAndRequestPermission(result: MethodChannel.Result) {
		if (hasLocationPermission()) {
			result.success(true)
			return
		}

		if (permissionResult != null) {
			result.error("PERMISSION_IN_PROGRESS", "Permission request already running", null)
			return
		}

		permissionResult = result
		ActivityCompat.requestPermissions(
			this,
			arrayOf(
				Manifest.permission.ACCESS_FINE_LOCATION,
				Manifest.permission.ACCESS_COARSE_LOCATION
			),
			locationPermissionRequestCode
		)
	}

	override fun onRequestPermissionsResult(
		requestCode: Int,
		permissions: Array<out String>,
		grantResults: IntArray
	) {
		super.onRequestPermissionsResult(requestCode, permissions, grantResults)
		if (requestCode != locationPermissionRequestCode) {
			return
		}

		val granted = grantResults.any { it == PackageManager.PERMISSION_GRANTED }
		permissionResult?.success(granted)
		permissionResult = null
		if (granted && hasBackgroundLocationPermission()) {
			GeofenceBackground.syncGeofences(this)
		}
	}

	private fun getCurrentLocation(result: MethodChannel.Result) {
		if (!hasLocationPermission()) {
			result.error("PERMISSION_DENIED", "Location permission not granted", null)
			return
		}

		val fused = LocationServices.getFusedLocationProviderClient(this)
		val tokenSource = CancellationTokenSource()
		fused.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, tokenSource.token)
			.addOnSuccessListener { location ->
				if (location != null) {
					sendLocationResult(location.latitude, location.longitude, location.accuracy.toDouble(), location.speed.toDouble(), result)
					return@addOnSuccessListener
				}

				fused.lastLocation
					.addOnSuccessListener { fallback ->
						if (fallback == null) {
							requestSingleFreshLocation(fused, result)
							return@addOnSuccessListener
						}
						sendLocationResult(
							fallback.latitude,
							fallback.longitude,
							fallback.accuracy.toDouble(),
							fallback.speed.toDouble(),
							result
						)
					}
					.addOnFailureListener { error ->
						result.error("LOCATION_ERROR", error.message, null)
					}
			}
			.addOnFailureListener { error ->
				result.error("LOCATION_ERROR", error.message, null)
			}
	}

	private fun requestSingleFreshLocation(
		fused: com.google.android.gms.location.FusedLocationProviderClient,
		result: MethodChannel.Result
	) {
		val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 1000L)
			.setWaitForAccurateLocation(true)
			.setMaxUpdates(1)
			.setDurationMillis(15000L)
			.build()

		val callback = object : LocationCallback() {
			override fun onLocationResult(locationResult: LocationResult) {
				fused.removeLocationUpdates(this)
				val location = locationResult.lastLocation
				if (location == null) {
					result.error("NO_LOCATION", "No location available", null)
					return
				}
				sendLocationResult(
					location.latitude,
					location.longitude,
					location.accuracy.toDouble(),
					location.speed.toDouble(),
					result
				)
			}
		}

		fused.requestLocationUpdates(request, callback, Looper.getMainLooper())
			.addOnFailureListener { error ->
				fused.removeLocationUpdates(callback)
				result.error("LOCATION_ERROR", error.message, null)
			}
	}

	private fun getAppBatteryUsage(result: MethodChannel.Result) {
		if (!hasUsageStatsPermission()) {
			result.error(
				"USAGE_ACCESS_DENIED",
				"Usage Access is required to read app activity stats.",
				null
			)
			return
		}

		try {
			val usageStatsManager =
				getSystemService(USAGE_STATS_SERVICE) as UsageStatsManager
			val end = System.currentTimeMillis()
			val start = end - 24L * 60L * 60L * 1000L
			val stats = usageStatsManager.queryUsageStats(
				UsageStatsManager.INTERVAL_DAILY,
				start,
				end
			)

			if (stats.isNullOrEmpty()) {
				result.success(
					mapOf(
						"generatedAtEpochMs" to end,
						"windowHours" to 24,
						"deviceBatteryLevel" to readBatteryLevel(),
						"apps" to emptyList<Map<String, Any>>()
					)
				)
				return
			}

			val filtered = mutableListOf<UsageStats>()
			for (item in stats) {
				val foregroundMs = item.totalTimeInForeground
				if (foregroundMs <= 0L) {
					continue
				}
				try {
					val info = packageManager.getApplicationInfo(item.packageName, 0)
					val isSystemApp = (info.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0
					if (!isSystemApp || item.packageName == packageName) {
						filtered.add(item)
					}
				} catch (_: Exception) {
					filtered.add(item)
				}
			}

			val sorted = filtered.sortedByDescending { it.totalTimeInForeground }.take(25)
			val totalForegroundMs = sorted.sumOf { it.totalTimeInForeground }.toDouble().coerceAtLeast(1.0)

			val apps = sorted.map { item ->
				val foregroundMinutes = item.totalTimeInForeground.toDouble() / 60000.0
				val sharePercent = (item.totalTimeInForeground.toDouble() / totalForegroundMs) * 100.0
				mapOf(
					"packageName" to item.packageName,
					"appName" to resolveAppName(item.packageName),
					"foregroundMinutes" to roundToOneDecimal(foregroundMinutes),
					"estimatedBatterySharePercent" to roundToOneDecimal(sharePercent)
				)
			}

			result.success(
				mapOf(
					"generatedAtEpochMs" to end,
					"windowHours" to 24,
					"deviceBatteryLevel" to readBatteryLevel(),
					"apps" to apps
				)
			)
		} catch (error: Exception) {
			Log.e("MainActivity", "Failed to load app battery usage", error)
			result.error("BATTERY_USAGE_ERROR", error.message, null)
		}
	}

	private fun resolveAppName(packageId: String): String {
		return try {
			val info = packageManager.getApplicationInfo(packageId, 0)
			packageManager.getApplicationLabel(info).toString()
		} catch (_: Exception) {
			packageId
		}
	}

	private fun readBatteryLevel(): Int? {
		return try {
			val batteryManager = getSystemService(BATTERY_SERVICE) as BatteryManager
			val battery = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
			if (battery in 0..100) battery else null
		} catch (_: Exception) {
			null
		}
	}

	private fun roundToOneDecimal(value: Double): Double {
		return (value * 10.0).roundToInt() / 10.0
	}

	private fun sendLocationResult(
		latitude: Double,
		longitude: Double,
		accuracy: Double,
		speed: Double,
		result: MethodChannel.Result
	) {
		val payload = mapOf(
			"latitude" to latitude,
			"longitude" to longitude,
			"accuracy" to accuracy,
			"speed" to speed
		)
		result.success(payload)
	}
}
