package com.smsync

import android.content.Context
import android.net.wifi.WifiManager
import android.util.Log
import java.net.InetAddress
import java.util.Enumeration
import javax.jmdns.JmDNS
import javax.jmdns.ServiceInfo

class MdnsAdvertiser(private val context: Context) {

    companion object {
        private const val TAG = "MdnsAdvertiser"
        private const val SERVICE_TYPE = "_smsync._tcp.local."
        private const val SERVICE_NAME = "SMSync"
        private const val PORT = 8484

        private const val SERVICE_TEXT = "syncmode=background"
    }

    private var jmdns: JmDNS? = null
    private var serviceInfo: ServiceInfo? = null
    private var multicastLock: WifiManager.MulticastLock? = null

    fun register(port: Int = PORT) {
        if (jmdns != null) return

        try {
            val ip = getWifiIpAddress()
            Log.d(TAG, "Registering JmDNS service on IP: $ip")

            jmdns = if (ip != null) {
                JmDNS.create(InetAddress.getByName(ip), "SMSyncPollerSpec")
            } else {
                JmDNS.create()
            }

            serviceInfo = ServiceInfo.create(
                SERVICE_TYPE,
                SERVICE_NAME,
                port,
                0,
                0,
                SERVICE_TEXT
            )
            jmdns?.registerService(serviceInfo)
            joinMulticastGroup(ip)
            Log.d(TAG, "JmDNS service registered: $SERVICE_NAME.$SERVICE_TYPE:$port")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register JmDNS service: ${e.message}")
            deregister()
        }
    }

    fun deregister() {
        try {
            jmdns?.unregisterAllServices()
            jmdns?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to unregister JmDNS: ${e.message}")
        }
        jmdns = null
        serviceInfo = null

        multicastLock?.let { lock ->
            if (lock.isHeld) {
                try {
                    lock.release()
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to release multicast lock: ${e.message}")
                }
            }
        }
        multicastLock = null
    }

    private fun joinMulticastGroup(ip: String?) {
        try {
            val wifiManager = context.getSystemService(Context.WIFI_SERVICE) as WifiManager
            multicastLock = wifiManager.createMulticastLock("smsync")
            multicastLock?.setReferenceCounted(false)
            multicastLock?.acquire()
            Log.d(TAG, "Multicast lock acquired")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire multicast lock: ${e.message}")
        }
    }

    private fun getWifiIpAddress(): String? {
        return try {
            val wifiManager = context.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val dhcp = wifiManager.dhcpInfo ?: return null
            intToIpAddress(dhcp.ipAddress)
        } catch (e: Exception) {
            getLocalIpAddress()
        }
    }

    private fun intToIpAddress(ip: Int): String {
        return "%d.%d.%d.%d".format(
            (ip and 0xff),
            (ip shr 8) and 0xff,
            (ip shr 16) and 0xff,
            (ip shr 24) and 0xff
        )
    }

    private fun getLocalIpAddress(): String? {
        try {
            val interfaces = java.net.NetworkInterface.getNetworkInterfaces() ?: return null
            val en: Enumeration<InetAddress>
            while (interfaces.hasMoreElements()) {
                val intf = interfaces.nextElement()
                if (!intf.name.startsWith("wlan") && !intf.isUp) continue
                val addresses: Enumeration<InetAddress> = intf.inetAddresses
                while (addresses.hasMoreElements()) {
                    val inet = addresses.nextElement()
                    if (!inet.isLoopbackAddress && inet is java.net.Inet4Address) {
                        val host = inet.hostAddress ?: continue
                        if (host.startsWith("192.168.") || host.startsWith("10.") || host.startsWith("172.")) {
                            return host
                        }
                    }
                }
            }
        } catch (e: Exception) {
            // ignore
        }
        return null
    }
}