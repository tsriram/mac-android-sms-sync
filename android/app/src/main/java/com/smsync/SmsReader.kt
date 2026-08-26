package com.smsync

import android.content.ContentResolver
import android.database.Cursor
import android.provider.Telephony
import com.smsync.models.SmsMessage

class SmsReader(private val contentResolver: ContentResolver) {

    fun getAllSms(offset: Int = 0, limit: Int = 500): List<SmsMessage> {
        val messages = mutableListOf<SmsMessage>()
        val uri = Telephony.Sms.CONTENT_URI
        val projection = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
            Telephony.Sms.TYPE,
            Telephony.Sms.READ
        )

        val cursor: Cursor? = contentResolver.query(
            uri,
            projection,
            null,
            null,
            "${Telephony.Sms.DATE} DESC"
        )

        cursor?.use {
            it.moveToPosition(offset)
            var count = 0
            while (it.moveToNext() && count < limit) {
                val id = it.getLong(it.getColumnIndexOrThrow(Telephony.Sms._ID))
                val address = it.getString(it.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)) ?: ""
                val body = it.getString(it.getColumnIndexOrThrow(Telephony.Sms.BODY)) ?: ""
                val date = it.getLong(it.getColumnIndexOrThrow(Telephony.Sms.DATE))
                val type = it.getInt(it.getColumnIndexOrThrow(Telephony.Sms.TYPE))
                val read = it.getInt(it.getColumnIndexOrThrow(Telephony.Sms.READ)) == 1

                messages.add(SmsMessage(id, address, body, date, type, read))
                count++
            }
        }

        return messages
    }

    fun getSmsSince(timestamp: Long): List<SmsMessage> {
        val messages = mutableListOf<SmsMessage>()
        val uri = Telephony.Sms.CONTENT_URI
        val projection = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
            Telephony.Sms.TYPE,
            Telephony.Sms.READ
        )

        val cursor: Cursor? = contentResolver.query(
            uri,
            projection,
            "${Telephony.Sms.DATE} > ?",
            arrayOf(timestamp.toString()),
            "${Telephony.Sms.DATE} ASC"
        )

        cursor?.use {
            while (it.moveToNext()) {
                val id = it.getLong(it.getColumnIndexOrThrow(Telephony.Sms._ID))
                val address = it.getString(it.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)) ?: ""
                val body = it.getString(it.getColumnIndexOrThrow(Telephony.Sms.BODY)) ?: ""
                val date = it.getLong(it.getColumnIndexOrThrow(Telephony.Sms.DATE))
                val type = it.getInt(it.getColumnIndexOrThrow(Telephony.Sms.TYPE))
                val read = it.getInt(it.getColumnIndexOrThrow(Telephony.Sms.READ)) == 1

                messages.add(SmsMessage(id, address, body, date, type, read))
            }
        }

        return messages
    }

    fun getTotalCount(): Int {
        val uri = Telephony.Sms.CONTENT_URI
        val cursor: Cursor? = contentResolver.query(
            uri,
            arrayOf(Telephony.Sms._ID),
            null,
            null,
            null
        )
        return cursor?.use { it.count } ?: 0
    }

    fun getLatestTimestamp(): Long {
        val uri = Telephony.Sms.CONTENT_URI
        val cursor: Cursor? = contentResolver.query(
            uri,
            arrayOf(Telephony.Sms.DATE),
            null,
            null,
            "${Telephony.Sms.DATE} DESC"
        )
        return cursor?.use {
            if (it.moveToFirst()) it.getLong(0) else 0L
        } ?: 0L
    }
}
