package com.smsync

import android.Manifest
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.os.Bundle
import android.provider.Telephony
import android.widget.TextView
import android.widget.LinearLayout
import android.widget.Button
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity : AppCompatActivity() {

    private lateinit var statusText: TextView
    private lateinit var permissionButton: Button
    private lateinit var defaultSmsButton: Button
    private lateinit var serverStatusText: TextView
    private lateinit var pinText: TextView

    private var smsReader: SmsReader? = null
    private var localServer: LocalServer? = null
    private var mdnsAdvertiser: MdnsAdvertiser? = null
    private var contentObserver: SmsContentObserver? = null
    private var authManager: AuthManager? = null

    companion object {
        private const val SMS_PERMISSION_CODE = 1001
        private const val PREFS_NAME = "smsync_prefs"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 48, 48, 48)
        }

        val titleText = TextView(this).apply {
            text = "SMSync"
            textSize = 28f
            setPadding(0, 0, 0, 32)
        }

        statusText = TextView(this).apply {
            text = "Checking permissions..."
            textSize = 16f
            setPadding(0, 0, 0, 16)
        }

        permissionButton = Button(this).apply {
            text = "Grant SMS Permission"
            setOnClickListener { requestSmsPermission() }
        }

        defaultSmsButton = Button(this).apply {
            text = "Set as default SMS app (recommended on Android 13+)"
            setOnClickListener { requestDefaultSmsApp() }
        }

        serverStatusText = TextView(this).apply {
            text = "Server: Stopped"
            textSize = 14f
            setPadding(0, 0, 0, 16)
        }

        val pairButton = Button(this).apply {
            text = "Show Pairing PIN"
            setOnClickListener { showPairingPin() }
        }

        pinText = TextView(this).apply {
            text = "No PIN"
            textSize = 32f
            typeface = android.graphics.Typeface.MONOSPACE
            gravity = android.view.Gravity.CENTER
            setPadding(0, 8, 0, 0)
            visibility = android.view.View.GONE
        }

        layout.addView(titleText)
        layout.addView(statusText)
        layout.addView(permissionButton)
        layout.addView(defaultSmsButton)
        layout.addView(serverStatusText)
        layout.addView(pairButton)
        layout.addView(pinText)

        setContentView(layout)

        checkSmsPermission()
    }

    override fun onResume() {
        super.onResume()
        checkSmsPermission()
    }

    private fun checkSmsPermission() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS)
            == PackageManager.PERMISSION_GRANTED
        ) {
            statusText.text = "SMS permission granted"
            permissionButton.visibility = android.view.View.GONE
            defaultSmsButton.visibility = android.view.View.GONE
            if (smsReader == null) {
                startServices()
            }
        } else {
            statusText.text = "SMS permission not granted"
            permissionButton.visibility = android.view.View.VISIBLE
            defaultSmsButton.visibility = android.view.View.VISIBLE
        }
    }

    private fun requestDefaultSmsApp() {
        val intent = Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT)
            .putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, packageName)
        startActivity(intent)
    }

    private fun showPairingPin() {
        val manager = authManager ?: run {
            Toast.makeText(this, "Start services first", Toast.LENGTH_SHORT).show()
            return
        }
        val pin = manager.getActivePin() ?: manager.generatePin()
        pinText.text = pin
        pinText.visibility = android.view.View.VISIBLE
        Toast.makeText(
            this,
            "Enter this PIN in the SMSync Mac app. Expires in 2 minutes.",
            Toast.LENGTH_LONG
        ).show()
    }

    private fun requestSmsPermission() {
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.READ_SMS),
            SMS_PERMISSION_CODE
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERMISSION_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                checkSmsPermission()
            } else {
                statusText.text = "SMS permission denied"
                Toast.makeText(this, "SMS permission is required", Toast.LENGTH_LONG).show()
            }
        }
    }

    private fun startServices() {
        smsReader = SmsReader(contentResolver)
        val prefs: SharedPreferences = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        authManager = AuthManager(prefs)

        localServer = LocalServer(
            smsReader = smsReader!!,
            authManager = authManager!!,
            onClientConnected = {
                runOnUiThread {
                    serverStatusText.text = "Server: Client connected"
                }
            }
        )

        mdnsAdvertiser = MdnsAdvertiser(this)

        contentObserver = SmsContentObserver(
            smsReader = smsReader!!,
            onNewMessage = { message ->
                localServer?.broadcastMessage(message)
            }
        )

        try {
            localServer?.startServer()
            mdnsAdvertiser?.register()
            contentObserver?.setInitialTimestamp(smsReader?.getLatestTimestamp() ?: 0L)
            contentResolver.registerContentObserver(
                Telephony.Sms.CONTENT_URI,
                true,
                contentObserver!!
            )
            val ip = getLocalIpAddress()
            serverStatusText.text = if (ip != null) {
                "Server: Running at $ip:8484"
            } else {
                "Server: Running on port 8484 (IP unknown)"
            }
            Toast.makeText(this, "SMSync server started", Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            serverStatusText.text = "Server: Failed to start"
            Toast.makeText(this, "Failed to start server: ${e.message}", Toast.LENGTH_LONG).show()
        }
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

    override fun onDestroy() {
        super.onDestroy()
        contentObserver?.let {
            contentResolver.unregisterContentObserver(it)
        }
        mdnsAdvertiser?.deregister()
        localServer?.stop()
    }
}