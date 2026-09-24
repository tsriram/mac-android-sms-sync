package com.smsync

import android.content.ContentResolver
import android.provider.ContactsContract
import com.smsync.models.Contact

class ContactReader(private val contentResolver: ContentResolver) {

    fun getAllContacts(): List<Contact> {
        val contacts = mutableListOf<Contact>()
        val uri = ContactsContract.CommonDataKinds.Phone.CONTENT_URI
        val projection = arrayOf(
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER
        )

        val cursor = contentResolver.query(uri, projection, null, null, null) ?: return contacts

        cursor.use {
            if (!it.moveToFirst()) return contacts
            do {
                val name = it.getString(it.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME))
                val number = it.getString(it.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.NUMBER))
                if (!name.isNullOrBlank() && !number.isNullOrBlank()) {
                    contacts.add(Contact(name = name, number = number))
                }
            } while (it.moveToNext())
        }
        return contacts
    }
}