package com.smsync

import android.content.SharedPreferences
import android.util.Log
import java.security.MessageDigest
import java.security.SecureRandom

class AuthManager(private val prefs: SharedPreferences) {

    companion object {
        private const val TAG = "AuthManager"
        private const val PREF_PAIRED_DEVICES = "paired_devices"
        private const val PREF_CURRENT_PIN = "current_pin"
        private const val PREF_PIN_EXPIRY = "pin_expiry"
        private const val PIN_EXPIRY_MS = 120_000L // 2 minutes
    }

    private val secureRandom = SecureRandom()

    fun generatePin(): String {
        val pin = String.format("%06d", secureRandom.nextInt(999999))
        prefs.edit()
            .putString(PREF_CURRENT_PIN, pin)
            .putLong(PREF_PIN_EXPIRY, System.currentTimeMillis() + PIN_EXPIRY_MS)
            .apply()
        Log.d(TAG, "Generated PIN: $pin")
        return pin
    }

    fun validatePin(pin: String): Boolean {
        val storedPin = prefs.getString(PREF_CURRENT_PIN, null) ?: return false
        val expiry = prefs.getLong(PREF_PIN_EXPIRY, 0)

        if (System.currentTimeMillis() > expiry) {
            Log.d(TAG, "PIN expired")
            prefs.edit().remove(PREF_CURRENT_PIN).remove(PREF_PIN_EXPIRY).apply()
            return false
        }

        if (storedPin == pin) {
            Log.d(TAG, "PIN validated")
            prefs.edit().remove(PREF_CURRENT_PIN).remove(PREF_PIN_EXPIRY).apply()
            return true
        }

        Log.d(TAG, "Invalid PIN")
        return false
    }

    fun generateDeviceToken(): String {
        val bytes = ByteArray(32)
        secureRandom.nextBytes(bytes)
        return bytes.joinToString("") { "%02x".format(it) }
    }

    fun addPairedDevice(deviceId: String) {
        val devices = getPairedDevices().toMutableSet()
        devices.add(deviceId)
        prefs.edit().putStringSet(PREF_PAIRED_DEVICES, devices).apply()
        Log.d(TAG, "Added paired device: $deviceId")
    }

    fun removePairedDevice(deviceId: String) {
        val devices = getPairedDevices().toMutableSet()
        devices.remove(deviceId)
        prefs.edit().putStringSet(PREF_PAIRED_DEVICES, devices).apply()
        Log.d(TAG, "Removed paired device: $deviceId")
    }

    fun getPairedDevices(): Set<String> {
        return prefs.getStringSet(PREF_PAIRED_DEVICES, emptySet()) ?: emptySet()
    }

    fun isDevicePaired(deviceId: String): Boolean {
        return getPairedDevices().contains(deviceId)
    }

    fun hasPairedDevices(): Boolean {
        return getPairedDevices().isNotEmpty()
    }

    fun clearAll() {
        prefs.edit().clear().apply()
        Log.d(TAG, "All auth data cleared")
    }
}
