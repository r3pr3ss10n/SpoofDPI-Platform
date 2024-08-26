package eu.repression.spoofdpi.spoof_dpi

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ProxyInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.annotation.RequiresApi

class ProxyVpnService : VpnService() {

    private var vpnInterface: ParcelFileDescriptor? = null

    @RequiresApi(Build.VERSION_CODES.Q)
    override fun onCreate() {
        super.onCreate()
        Log.d("ProxyVpnService", "onCreate called")

        val filter = IntentFilter("eu.repression.spoofdpi.spoof_dpi.ACTION_STOP_VPN")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(stopReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(stopReceiver, filter)
        }

        val builder = Builder()
        builder.setSession("SpoofDPI VPN")
            .addAddress("10.0.0.2", 24)
            .addDnsServer("8.8.8.8")
            .setBlocking(true)
            .setHttpProxy(ProxyInfo.buildDirectProxy("127.0.0.1", 8080))

        vpnInterface = builder.establish()
    }

    private fun stopService() {
        vpnInterface?.close()
        vpnInterface = null
        unregisterReceiver(stopReceiver)
        stopSelf()
    }

    private val stopReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "eu.repression.spoofdpi.spoof_dpi.ACTION_STOP_VPN") {
                stopService()
            }
        }
    }
}
