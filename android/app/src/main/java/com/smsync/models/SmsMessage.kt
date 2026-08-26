package com.smsync.models

data class SmsMessage(
    val id: Long,
    val address: String,
    val body: String,
    val date: Long,
    val type: Int,
    val read: Boolean
) {
    companion object {
        const val TYPE_INBOX = 1
        const val TYPE_SENT = 2
        const val TYPE_DRAFT = 3
        const val TYPE_OUTBOX = 4
    }

    fun toJson(): String {
        return """
            {
                "id": $id,
                "address": "$address",
                "body": "${body.replace("\"", "\\\"").replace("\n", "\\n")}",
                "date": $date,
                "type": $type,
                "read": $read
            }
        """.trimIndent()
    }
}
