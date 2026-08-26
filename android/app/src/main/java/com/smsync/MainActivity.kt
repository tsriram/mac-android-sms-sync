package com.smsync

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
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

    companion object {
        private const val SMS_PERMISSION_CODE = 1001
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

        layout.addView(titleText)
        layout.addView(statusText)
        layout.addView(permissionButton)

        setContentView(layout)

        checkSmsPermission()
    }

    private fun checkSmsPermission() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS)
            == PackageManager.PERMISSION_GRANTED
        ) {
            onPermissionGranted()
        } else {
            statusText.text = "SMS permission not granted"
            permissionButton.visibility = android.view.View.VISIBLE
        }
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
                onPermissionGranted()
            } else {
                statusText.text = "SMS permission denied"
                Toast.makeText(this, "SMS permission is required", Toast.LENGTH_LONG).show()
            }
        }
    }

    private fun onPermissionGranted() {
        statusText.text = "SMS permission granted ✓"
        permissionButton.visibility = android.view.View.GONE
        Toast.makeText(this, "SMS permission granted. Server will start in next step.", Toast.LENGTH_SHORT).show()
    }
}
