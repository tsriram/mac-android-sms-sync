package com.smsync

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "SMS delivered: ${intent.action}")
    }

    companion object {
        private const val TAG = "SmsReceiver"
    }
}