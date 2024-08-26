package eu.repression.spoofdpi.spoof_dpi

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import android.util.Log

class ProxyService : Service() {

    companion object {
        var isRunning = false
    }

    private var spoofDpiProcess: Process? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        isRunning = true
        startForegroundService()
        startSpoofDpi()
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        stopSpoofDpi()
        isRunning = false
    }

    private fun startForegroundService() {
        val channelId = "proxy_service_channel"
        val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Proxy Service",
                NotificationManager.IMPORTANCE_LOW
            )
            notificationManager.createNotificationChannel(channel)
        }

        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(this, 0, notificationIntent, PendingIntent.FLAG_IMMUTABLE)

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("SpoofDPI")
            .setContentText("Proxy server is working")
            .setSmallIcon(R.drawable.round_cell_wifi_24)
            .setContentIntent(pendingIntent)
            .build()

        startForeground(1, notification)
    }

    private fun startSpoofDpi() {
        CoroutineScope(Dispatchers.IO).launch {
            if (spoofDpiProcess != null) return@launch
            try {
                val libPath = "${applicationInfo.nativeLibraryDir}/libspoofdpi.so"
                val command = "$libPath --enable-doh --window-size 0"
                spoofDpiProcess = Runtime.getRuntime().exec(command)
                spoofDpiProcess?.waitFor()
            } catch (e: Exception) {
                Log.e("ProxyService", "Error starting spoof DPI", e)
                spoofDpiProcess = null
                stopSelf()
            }
        }
    }

    private fun stopSpoofDpi() {
        spoofDpiProcess?.destroy()
        spoofDpiProcess = null
    }

    override fun onBind(p0: Intent?): IBinder? {
        return null
    }
}
