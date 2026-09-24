package com.smsync

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Telephony
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.material.card.MaterialCardView
import com.google.android.material.button.MaterialButtonToggleGroup
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : AppCompatActivity() {

    private lateinit var permissionActions: MaterialButtonToggleGroup
    private lateinit var btnGrantSms: Button
    private lateinit var btnDefaultSms: Button
    private lateinit var tvConnectionState: TextView
    private lateinit var tvServerStatus: TextView
    private lateinit var statusDot: android.view.View
    private lateinit var tvSmsCount: TextView
    private lateinit var tvContactCount: TextView
    private lateinit var tvLastSync: TextView
    private lateinit var cardPin: MaterialCardView
    private lateinit var tvPin: TextView
    private lateinit var tvPinHint: TextView

    private var authManager: AuthManager? = null
    private var receiverRegistered = false
    private val uiHandler = Handler(Looper.getMainLooper())

    private val statusReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val status = intent.getStringExtra(SmsSyncService.EXTRA_SERVER_STATUS)
            if (status != null) {
                tvServerStatus.text = status
            }
            refreshStatusUi()
        }
    }

    private val refreshRunnable = object : Runnable {
        override fun run() {
            refreshStatusUi()
            refreshCounts()
            uiHandler.postDelayed(this, 3_000)
        }
    }

    companion object {
        private const val SMS_PERMISSION_CODE = 1001
        private const val CONTACTS_PERMISSION_CODE = 1002
        private const val NOTIFICATIONS_PERMISSION_CODE = 1003
        private const val PREFS_NAME = "smsync_prefs"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        permissionActions = findViewById(R.id.permission_actions)
        btnGrantSms = findViewById(R.id.btn_grant_sms)
        btnDefaultSms = findViewById(R.id.btn_default_sms)
        tvConnectionState = findViewById(R.id.tv_connection_state)
        tvServerStatus = findViewById(R.id.tv_server_status)
        statusDot = findViewById(R.id.status_dot)
        tvSmsCount = findViewById(R.id.tv_sms_count)
        tvContactCount = findViewById(R.id.tv_contact_count)
        tvLastSync = findViewById(R.id.tv_last_sync)
        cardPin = findViewById(R.id.card_pin)
        tvPin = findViewById(R.id.tv_pin)
        tvPinHint = findViewById(R.id.tv_pin_hint)

        btnGrantSms.setOnClickListener { requestSmsPermission() }
        btnDefaultSms.setOnClickListener { requestDefaultSmsApp() }
        findViewById<Button>(R.id.btn_pair_pin).setOnClickListener { showPairingPin() }

        registerStatusReceiver()
        checkSmsPermission()
        refreshStatusUi()
        refreshCounts()
    }

    override fun onStart() {
        super.onStart()
        uiHandler.post(refreshRunnable)
    }

    override fun onStop() {
        super.onStop()
        uiHandler.removeCallbacks(refreshRunnable)
    }

    override fun onResume() {
        super.onResume()
        refreshStatusUi()
        checkSmsPermission()
    }

    override fun onDestroy() {
        uiHandler.removeCallbacks(refreshRunnable)
        if (receiverRegistered) {
            unregisterReceiver(statusReceiver)
            receiverRegistered = false
        }
        super.onDestroy()
    }

    private fun registerStatusReceiver() {
        if (receiverRegistered) return
        val filter = IntentFilter(SmsSyncService.ACTION_STATUS)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(statusReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(statusReceiver, filter)
        }
        receiverRegistered = true
    }

    private fun checkSmsPermission() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS)
            == PackageManager.PERMISSION_GRANTED
        ) {
            permissionActions.visibility = android.view.View.GONE
            requestNotificationsPermissionIfNeeded()
            requestContactsPermission()
            startSyncService()
        } else {
            permissionActions.visibility = android.view.View.VISIBLE
            tvConnectionState.text = "SMS permission required"
            tvServerStatus.text = getString(R.string.status_server_stopped)
            setStatusDot(Color.rgb(0xC6, 0x28, 0x28))
        }
    }

    private fun refreshStatusUi() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            permissionActions.visibility = android.view.View.VISIBLE
            tvConnectionState.text = "SMS permission required"
            tvServerStatus.text = getString(R.string.status_server_stopped)
            setStatusDot(Color.rgb(0xC6, 0x28, 0x28))
            return
        }

        permissionActions.visibility = android.view.View.GONE

        val connected = SmsSyncService.isClientConnected
        val syncing = connected && SmsSyncService.lastSyncAt > 0L

        tvConnectionState.text = when {
            syncing -> "Synced with Mac"
            connected -> "Connected to Mac"
            else -> "Waiting for Mac…"
        }
        setStatusDot(
            when {
                syncing -> Color.rgb(0x2E, 0x7D, 0x32)   // green
                connected -> Color.rgb(0xF9, 0xA8, 0x25) // amber
                else -> Color.rgb(0x61, 0x61, 0x61)      // gray
            }
        )

        tvServerStatus.text = SmsSyncService.serverStatus
        updateLastSyncLabel()
    }

    private fun refreshCounts() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        try {
            val smsReader = SmsReader(contentResolver)
            tvSmsCount.text = formatCount(smsReader.getTotalCount())
        } catch (e: Exception) {
            tvSmsCount.text = "–"
        }

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS)
            == PackageManager.PERMISSION_GRANTED
        ) {
            try {
                val contactReader = ContactReader(contentResolver)
                tvContactCount.text = formatCount(contactReader.getAllContacts().size)
            } catch (e: Exception) {
                tvContactCount.text = "–"
            }
        } else {
            tvContactCount.text = "–"
        }

        updateLastSyncLabel()
    }

    private fun updateLastSyncLabel() {
        tvLastSync.text = when {
            SmsSyncService.lastSyncAt <= 0L -> "Never"
            else -> {
                val diff = System.currentTimeMillis() - SmsSyncService.lastSyncAt
                when {
                    diff < 60_000L -> "Just now"
                    diff < 3_600_000L -> "${diff / 60_000L}m ago"
                    diff < 86_400_000L -> "${diff / 3_600_000L}h ago"
                    else -> SimpleDateFormat("MMM d", Locale.getDefault())
                        .format(Date(SmsSyncService.lastSyncAt))
                }
            }
        }
    }

    private fun formatCount(count: Int): String {
        return if (count >= 1_000_000) {
            String.format("%.1fM", count / 1_000_000.0)
        } else if (count >= 10_000) {
            String.format("%.1fk", count / 1_000.0)
        } else {
            count.toString()
        }
    }

    private fun setStatusDot(color: Int) {
        statusDot.background.setTint(color)
    }

    private fun startSyncService() {
        val intent = Intent(this, SmsSyncService::class.java)
            .setAction(SmsSyncService.ACTION_START)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun requestNotificationsPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATIONS_PERMISSION_CODE
            )
        }
    }

    private fun requestDefaultSmsApp() {
        val intent = Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT)
            .putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, packageName)
        startActivity(intent)
    }

    private fun showPairingPin() {
        val manager = authManager ?: run {
            val prefs: SharedPreferences = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            AuthManager(prefs).also { authManager = it }
        }
        val pin = manager.getActivePin() ?: manager.generatePin()
        tvPin.text = pin
        cardPin.visibility = android.view.View.VISIBLE
        tvPinHint.text = "Open SMSync on your Mac and enter this PIN to pair."
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

    private fun requestContactsPermission() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.READ_CONTACTS),
                CONTACTS_PERMISSION_CODE
            )
        }
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
                Toast.makeText(this, "SMS permission is required", Toast.LENGTH_LONG).show()
                checkSmsPermission()
            }
        } else if (requestCode == CONTACTS_PERMISSION_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            Toast.makeText(
                this,
                if (granted) "Contacts permission granted" else "Contacts permission not granted (names will be missing)",
                Toast.LENGTH_LONG
            ).show()
        }
    }
}