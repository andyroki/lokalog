package com.example.lokalog_app

import android.Manifest
import android.os.Build
import android.content.pm.PackageManager
import android.location.LocationManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "lokalog/location"
	private val sitesStorageKey = "saved_job_sites_v1"
	private val locationPermissionRequestCode = 1001
	private var permissionResult: MethodChannel.Result? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
				when (call.method) {
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

					"hasBackgroundLocationPermission" -> {
						result.success(GeofenceBackground.hasBackgroundLocationPermission(this))
					}

					else -> result.notImplemented()
				}
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
							result.error("NO_LOCATION", "No location available", null)
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
