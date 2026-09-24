package com.smsync

import android.os.Handler
import android.os.Looper
import fi.iki.elonen.NanoHTTPD
import fi.iki.elonen.NanoWSD
import org.json.JSONArray
import org.json.JSONObject
import com.smsync.models.SmsMessage
import java.io.IOException

class LocalServer(
    private val smsReader: SmsReader,
    private val contactReader: ContactReader,
    private val authManager: AuthManager,
    private val onClientConnected: () -> Unit
) : NanoWSD(8484) {

    private val wsClients = mutableSetOf<SmsWebSocket>()
    private val handler = Handler(Looper.getMainLooper())

    override fun serve(session: IHTTPSession): NanoHTTPD.Response {
        val uri = session.uri
        val params = session.parms

        return when {
            uri == "/api/info" -> handleInfo()
            uri == "/api/pair/init" -> handlePairInit()
            uri == "/api/pair" -> handlePair(params)
            uri == "/api/sms" -> handleSms(params)
            uri == "/api/contacts" -> handleContacts()
            uri == "/ws" -> super.serve(session)
            else -> newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "Not found")
        }
    }

    override fun openWebSocket(handshake: IHTTPSession): NanoWSD.WebSocket {
        return SmsWebSocket(handshake)
    }

    private fun handleInfo(): NanoHTTPD.Response {
        val json = JSONObject().apply {
            put("deviceName", android.os.Build.MODEL)
            put("totalSMS", smsReader.getTotalCount())
            put("lastMessageTimestamp", smsReader.getLatestTimestamp())
            put("version", "1.0")
        }
        return jsonResponse(json)
    }

    private fun handlePairInit(): NanoHTTPD.Response {
        val pin = authManager.getActivePin() ?: authManager.generatePin()
        val json = JSONObject().apply {
            put("pin", pin)
            put("expiresIn", 120)
        }
        return jsonResponse(json)
    }

    private fun handlePair(params: Map<String, String>): NanoHTTPD.Response {
        val pin = params["pin"] ?: return jsonResponse(
            JSONObject().apply { put("paired", false); put("error", "Missing pin") },
            Response.Status.BAD_REQUEST
        )

        if (authManager.validatePin(pin)) {
            val deviceToken = authManager.generateDeviceToken()
            val json = JSONObject().apply {
                put("paired", true)
                put("deviceToken", deviceToken)
            }
            return jsonResponse(json)
        }

        return jsonResponse(
            JSONObject().apply { put("paired", false); put("error", "Invalid pin") },
            Response.Status.UNAUTHORIZED
        )
    }

    private fun handleSms(params: Map<String, String>): NanoHTTPD.Response {
        val since = params["since"]?.toLongOrNull()
        val offset = params["offset"]?.toIntOrNull() ?: 0
        val limit = params["limit"]?.toIntOrNull() ?: 500

        val messages = if (since != null) {
            smsReader.getSmsSince(since)
        } else {
            smsReader.getAllSms(offset, limit)
        }

        val messagesArray = JSONArray()
        messages.forEach { msg ->
            messagesArray.put(JSONObject().apply {
                put("id", msg.id)
                put("address", msg.address)
                put("body", msg.body)
                put("date", msg.date)
                put("type", msg.type)
                put("read", msg.read)
            })
        }

        val json = JSONObject().apply {
            put("messages", messagesArray)
            put("total", smsReader.getTotalCount())
            put("hasMore", offset + limit < smsReader.getTotalCount())
        }
        return jsonResponse(json)
    }

    private fun handleContacts(): NanoHTTPD.Response {
        val contactsArray = JSONArray()
        contactReader.getAllContacts().forEach { contact ->
            contactsArray.put(JSONObject().apply {
                put("name", contact.name)
                put("number", contact.number)
            })
        }
        return jsonResponse(JSONObject().apply {
            put("contacts", contactsArray)
            put("total", contactsArray.length())
        })
    }

    private fun jsonResponse(json: JSONObject, status: Response.Status = Response.Status.OK): NanoHTTPD.Response {
        return newFixedLengthResponse(status, "application/json", json.toString())
    }

    fun broadcastMessage(message: SmsMessage) {
        val json = JSONObject().apply {
            put("event", "new_sms")
            put("data", JSONObject().apply {
                put("id", message.id)
                put("address", message.address)
                put("body", message.body)
                put("date", message.date)
                put("type", message.type)
                put("read", message.read)
            })
        }
        val messageStr = json.toString()
        val iterator = wsClients.iterator()
        while (iterator.hasNext()) {
            val client = iterator.next()
            try {
                client.send(messageStr)
            } catch (e: Exception) {
                iterator.remove()
            }
        }
    }

    @Throws(IOException::class)
    fun startServer() {
        start(NanoHTTPD.SOCKET_READ_TIMEOUT, false)
    }

    inner class SmsWebSocket(handshake: IHTTPSession) : NanoWSD.WebSocket(handshake) {
        override fun onOpen() {
            wsClients.add(this)
            handler.post { onClientConnected() }
        }

        override fun onClose(
            code: NanoWSD.WebSocketFrame.CloseCode,
            reason: String?,
            initiatedByRemote: Boolean
        ) {
            wsClients.remove(this)
        }

        override fun onPong(frame: NanoWSD.WebSocketFrame?) {}

        override fun onException(exception: IOException) {
            wsClients.remove(this)
        }

        override fun onMessage(message: NanoWSD.WebSocketFrame?) {
            // Client messages not handled in V1
        }
    }
}
