package com.smsync

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class MmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "MMS delivered: ${intent.action}")
    }

    companion object {
        private const val TAG = "MmsReceiver"
    }
}