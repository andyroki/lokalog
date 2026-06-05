package com.example.lokalog_app

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import org.json.JSONArray
import org.json.JSONObject

private const val STORE_NAME = "lokalog_store"
private const val SITES_KEY = "saved_job_sites_v1"
private const val BACKGROUND_LOGS_KEY = "background_logs_v1"
private const val GEOFENCE_RADIUS_METERS = 100f

object GeofenceBackground {
    fun syncGeofences(context: Context) {
        if (!hasBackgroundLocationPermission(context)) {
            return
        }

        val sites = loadSites(context)
        if (sites.isEmpty()) {
            return
        }

        val geofences = sites.map { site ->
            Geofence.Builder()
                .setRequestId(site.id)
                .setCircularRegion(site.lat, site.lng, GEOFENCE_RADIUS_METERS)
                .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_DWELL)
                .setLoiteringDelay((site.requiredDwellMinutes * 60_000).coerceAtLeast(60_000))
                .setExpirationDuration(Geofence.NEVER_EXPIRE)
                .build()
        }

        val request = GeofencingRequest.Builder()
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .addGeofences(geofences)
            .build()

        val client = LocationServices.getGeofencingClient(context)
        client.removeGeofences(geofencePendingIntent(context)).addOnCompleteListener {
            client.addGeofences(request, geofencePendingIntent(context))
        }
    }

    fun loadBackgroundLogsJson(context: Context): String {
        val prefs = context.getSharedPreferences(STORE_NAME, Context.MODE_PRIVATE)
        return prefs.getString(BACKGROUND_LOGS_KEY, "[]") ?: "[]"
    }

    fun deleteBackgroundLog(context: Context, address: String, timestamp: Long) {
        val prefs = context.getSharedPreferences(STORE_NAME, Context.MODE_PRIVATE)
        val current = JSONArray(prefs.getString(BACKGROUND_LOGS_KEY, "[]") ?: "[]")
        val filtered = JSONArray()

        for (index in 0 until current.length()) {
            val item = current.optJSONObject(index) ?: continue
            val itemAddress = item.optString("address")
            val itemTimestamp = item.optLong("timestamp", Long.MIN_VALUE)
            if (itemAddress == address && itemTimestamp == timestamp) {
                continue
            }
            filtered.put(item)
        }

        prefs.edit().putString(BACKGROUND_LOGS_KEY, filtered.toString()).apply()
    }

    fun hasBackgroundLocationPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return true
        }
        return ContextCompat.checkSelfPermission(
            context,
            android.Manifest.permission.ACCESS_BACKGROUND_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun appendBackgroundLog(context: Context, site: SavedSite) {
        val prefs = context.getSharedPreferences(STORE_NAME, Context.MODE_PRIVATE)
        val current = JSONArray(prefs.getString(BACKGROUND_LOGS_KEY, "[]") ?: "[]")
        val entry = JSONObject().apply {
            put("name", site.name)
            put("address", site.address)
            put("lat", site.lat)
            put("lng", site.lng)
            put("confidence", 100.0)
            put("confirmedByUser", false)
            put("autoLogged", true)
            put("timestamp", System.currentTimeMillis())
            put("source", "geofence")
        }
        current.put(entry)
        prefs.edit().putString(BACKGROUND_LOGS_KEY, current.toString()).apply()
    }

    fun findSiteById(context: Context, id: String): SavedSite? {
        return loadSites(context).firstOrNull { it.id == id }
    }

    private fun loadSites(context: Context): List<SavedSite> {
        val prefs = context.getSharedPreferences(STORE_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(SITES_KEY, null) ?: return emptyList()
        val decoded = JSONArray(raw)
        val sites = mutableListOf<SavedSite>()
        for (index in 0 until decoded.length()) {
            val item = decoded.optJSONObject(index) ?: continue
            sites.add(SavedSite.fromJson(item))
        }
        return sites
    }

    private fun geofencePendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, GeofenceBroadcastReceiver::class.java)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or mutablePendingIntentFlag()
        return PendingIntent.getBroadcast(context, 1001, intent, flags)
    }

    private fun mutablePendingIntentFlag(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_MUTABLE
        } else {
            0
        }
    }
}

class GeofenceBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError()) {
            return
        }

        if (event.geofenceTransition != Geofence.GEOFENCE_TRANSITION_DWELL) {
            return
        }

        val geofences = event.triggeringGeofences ?: return
        geofences.forEach { geofence ->
            val site = GeofenceBackground.findSiteById(context, geofence.requestId) ?: return@forEach
            GeofenceBackground.appendBackgroundLog(context, site)
        }
    }
}

data class SavedSite(
    val id: String,
    val name: String,
    val street: String,
    val city: String,
    val state: String,
    val zip: String,
    val lat: Double,
    val lng: Double,
    val requiredDwellMinutes: Int,
) {
    val address: String
        get() = "$street, $city, $state $zip"

    companion object {
        fun fromJson(json: JSONObject): SavedSite {
            val name = json.optString("name")
            val street = json.optString("street")
            val city = json.optString("city")
            val state = json.optString("state")
            val zip = json.optString("zip")
            return SavedSite(
                id = "$name|$street|$city|$state|$zip",
                name = name,
                street = street,
                city = city,
                state = state,
                zip = zip,
                lat = json.optDouble("lat"),
                lng = json.optDouble("lng"),
                requiredDwellMinutes = json.optInt("requiredDwellMinutes")
            )
        }
    }
}