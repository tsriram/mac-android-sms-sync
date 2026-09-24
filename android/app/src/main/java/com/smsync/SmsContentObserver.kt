package com.smsync

import android.database.ContentObserver
import android.os.Handler
import android.os.Looper
import android.provider.Telephony
import android.util.Log
import com.smsync.models.SmsMessage

class SmsContentObserver(
    private val smsReader: SmsReader,
    private val onNewMessage: (SmsMessage) -> Unit
) : ContentObserver(Handler(Looper.getMainLooper())) {

    companion object {
        private const val TAG = "SmsContentObserver"
    }

    private var lastKnownTimestamp: Long = 0

    fun setInitialTimestamp(timestamp: Long) {
        lastKnownTimestamp = timestamp
        Log.d(TAG, "Initial timestamp set to: $timestamp")
    }

    override fun onChange(selfChange: Boolean) {
        super.onChange(selfChange)
        Log.d(TAG, "SMS content changed")
        checkForNewMessages()
    }

    override fun onChange(selfChange: Boolean, uri: android.net.Uri?) {
        super.onChange(selfChange, uri)
        Log.d(TAG, "SMS content changed at: $uri")
        checkForNewMessages()
    }

    private fun checkForNewMessages() {
        val newMessages = smsReader.getSmsSince(lastKnownTimestamp)
        for (message in newMessages) {
            if (message.date > lastKnownTimestamp) {
                Log.d(TAG, "New message from: ${message.address}")
                lastKnownTimestamp = message.date
                onNewMessage(message)
            }
        }
    }
}
