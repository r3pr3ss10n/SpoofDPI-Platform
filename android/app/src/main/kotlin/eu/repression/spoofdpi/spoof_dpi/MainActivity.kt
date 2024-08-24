package eu.repression.spoofdpi.spoof_dpi

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import android.Manifest

class MainActivity: FlutterActivity() {

    private val CHANNEL = "proxy_bridge"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start_proxy" -> startProxyService(result)
                "stop_proxy" -> stopProxyService(result)
                "is_proxy_running" -> isProxyRunning(result)
                else -> result.notImplemented()
            }
        }
    }


    private fun askNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
            ) {
                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
            }
        }
    }

    private fun startProxyService(result: MethodChannel.Result) {
        val serviceIntent = Intent(this, ProxyService::class.java)

        askNotificationPermission()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
        result.success("Proxy service started")
    }

    private fun stopProxyService(result: MethodChannel.Result) {
        val serviceIntent = Intent(this, ProxyService::class.java)
        stopService(serviceIntent)
        result.success("Proxy service stopped")
    }

    private fun isProxyRunning(result: MethodChannel.Result) {
        result.success(ProxyService.isRunning)
    }
}