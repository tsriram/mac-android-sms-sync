package com.smsync

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.provider.Telephony
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class SmsSyncService : Service() {

    companion object {
        private const val TAG = "SmsSyncService"
        private const val CHANNEL_ID = "smsync_service_channel"
        private const val NOTIFICATION_ID = 1
        private const val PREFS_NAME = "smsync_prefs"

        const val ACTION_START = "com.smsync.action.START_SERVER"
        const val ACTION_STOP = "com.smsync.action.STOP_SERVER"

        const val ACTION_STATUS = "com.smsync.action.STATUS"
        const val EXTRA_SERVER_STATUS = "server_status"

        @Volatile
        var serverStatus: String = "Server: Stopped"
            private set

        @Volatile
        var isClientConnected: Boolean = false
            private set

        @Volatile
        var lastSyncAt: Long = 0L
            private set
    }

    private var smsReader: SmsReader? = null
    private var contactReader: ContactReader? = null
    private var localServer: LocalServer? = null
    private var mdnsAdvertiser: MdnsAdvertiser? = null
    private var contentObserver: SmsContentObserver? = null
    private var authManager: AuthManager? = null
    private var wifiLock: android.net.wifi.WifiManager.WifiLock? = null

    override fun onBind(intent: Intent): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action

        if (action == ACTION_STOP) {
            stopServer()
            return START_NOT_STICKY
        }

        startServer()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                buildNotification(),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(NOTIFICATION_ID, buildNotification())
        }

        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Keep the sync service alive even if the user swipes the app away.
        // START_STICKY will have us restarted by the system if we're killed.
        super.onTaskRemoved(rootIntent)
    }

    private fun startServer() {
        if (localServer != null) return

        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.READ_SMS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            setStatus("Server: SMS permission not granted")
            stopSelf()
            return
        }

        try {
            smsReader = SmsReader(contentResolver)
            contactReader = ContactReader(contentResolver)
            val prefs: SharedPreferences = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            authManager = AuthManager(prefs)

            val server = LocalServer(
                smsReader = smsReader!!,
                contactReader = contactReader!!,
                authManager = authManager!!,
                onClientConnected = {
                    isClientConnected = true
                    setStatus("Server: Client connected")
                },
                onClientDisconnected = {
                    isClientConnected = false
                    setStatus("Server: Waiting for connection")
                },
                onSyncPerformed = {
                    lastSyncAt = System.currentTimeMillis()
                    setStatus("Server: Synced")
                }
            )
            localServer = server

            mdnsAdvertiser = MdnsAdvertiser(this)

            contentObserver = SmsContentObserver(
                smsReader = smsReader!!,
                onNewMessage = { message ->
                    localServer?.broadcastMessage(message)
                }
            )

            server.startServer()
            mdnsAdvertiser?.register()
            contentObserver?.setInitialTimestamp(smsReader?.getLatestTimestamp() ?: 0L)
            contentResolver.registerContentObserver(
                Telephony.Sms.CONTENT_URI,
                true,
                contentObserver!!
            )
            acquireWifiLock()

            val ip = getLocalIpAddress()
            setStatus(
                if (ip != null) {
                    "Server: Running at $ip:8484"
                } else {
                    "Server: Running on port 8484 (IP unknown)"
                }
            )
            updateNotification()
            Log.d(TAG, "SMSync server started")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start server", e)
            setStatus("Server: Failed to start")
            updateNotification()
        }
    }

    private fun stopServer() {
        try {
            contentObserver?.let {
                contentResolver.unregisterContentObserver(it)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to unregister content observer", e)
        }
        contentObserver = null

        mdnsAdvertiser?.deregister()
        mdnsAdvertiser = null

        localServer?.stop()
        localServer = null

        smsReader = null
        contactReader = null
        authManager = null

        wifiLock?.let {
            if (it.isHeld) {
                try { it.release() } catch (e: Exception) { /* ignore */ }
            }
        }
        wifiLock = null

        isClientConnected = false
        lastSyncAt = 0L
        setStatus("Server: Stopped")
    }

    override fun onDestroy() {
        stopServer()
        super.onDestroy()
    }

    private fun setStatus(status: String) {
        serverStatus = status
        val broadcast = Intent(ACTION_STATUS)
            .setPackage(packageName)
            .putExtra(EXTRA_SERVER_STATUS, status)
        sendBroadcast(broadcast)
    }

    private fun getLocalIpAddress(): String? {
        try {
            val interfaces = java.net.NetworkInterface.getNetworkInterfaces() ?: return null
            for (intf in interfaces) {
                if (intf.name.startsWith("wlan") || intf.isUp) {
                    for (addr in intf.inetAddresses) {
                        val inet4 = addr as? java.net.Inet4Address ?: continue
                        if (inet4.isLoopbackAddress) continue
                        val ip = inet4.hostAddress ?: continue
                        if (ip.startsWith("192.168.") || ip.startsWith("10.") || ip.startsWith("172.")) {
                            return ip
                        }
                    }
                }
            }
        } catch (e: Exception) {
            // ignore
        }
        return null
    }

    private fun acquireWifiLock() {
        try {
            val wifiManager = getSystemService(Context.WIFI_SERVICE) as android.net.wifi.WifiManager
            wifiLock = wifiManager.createWifiLock(
                android.net.wifi.WifiManager.WIFI_MODE_FULL_HIGH_PERF,
                "smsync"
            )
            wifiLock?.setReferenceCounted(false)
            wifiLock?.acquire()
        } catch (e: Exception) {
            // Non-fatal; Wi-Fi may sleep and connections will just be slower
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SMS Sync Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps SMS sync running in the background"
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val openAppIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SMSync running")
            .setContentText(serverStatus)
            .setSmallIcon(R.drawable.ic_stat_smsync)
            .setContentIntent(openAppIntent)
            .setOngoing(true)
            .setSilent(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    private fun updateNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification())
    }
}