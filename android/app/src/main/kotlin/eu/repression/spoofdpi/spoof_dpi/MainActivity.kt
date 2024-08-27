package eu.repression.spoofdpi.spoof_dpi

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.net.VpnService
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {

    private val CHANNEL = "proxy_bridge"
    private val VPN_REQUEST_CODE = 100


    @RequiresApi(Build.VERSION_CODES.M)
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start_proxy" -> startProxyService(call, result)
                "stop_proxy" -> stopProxyService(result)
                "is_proxy_running" -> isProxyRunning(result)
                "test_service" -> testService(result)
                "open_binary" -> openBinary(result)
                "open_me" -> openMe(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun testService(result: MethodChannel.Result) {
        openUrl("https://rutracker.org")
        result.success(null)
    }

    private fun openBinary(result: MethodChannel.Result) {
        openUrl("https://github.com/xvzc/SpoofDPI")
        result.success(null)
    }

    private fun openMe(result: MethodChannel.Result) {
        openUrl("https://github.com/r3pr3ss10n/SpoofDPI-Platform")
        result.success(null)
    }

    private fun openUrl(url: String) {
        val intent = Intent(Intent.ACTION_VIEW)
        intent.data = Uri.parse(url)
        startActivity(intent)
    }

    private fun askNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, "android.permission.POST_NOTIFICATIONS") !=
                PackageManager.PERMISSION_GRANTED
            ) {
                requestPermissions(arrayOf("android.permission.POST_NOTIFICATIONS"), 1)
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun startProxyService(call: MethodCall, result: MethodChannel.Result) {
        val serviceIntent = Intent(this, ProxyService::class.java)

        val params = call.argument<String>("params")
        serviceIntent.putExtra("params", params)

        askNotificationPermission()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }

        if (call.argument<Boolean>("vpn_mode") == true) {
            requestVpnPermission()
        }

        result.success("Proxy service started, VPN request initiated")
    }

    private fun stopProxyService(result: MethodChannel.Result) {
        val serviceIntent = Intent(this, ProxyService::class.java)
        stopService(serviceIntent)
        val stopIntent = Intent("eu.repression.spoofdpi.spoof_dpi.ACTION_STOP_VPN")
        sendBroadcast(stopIntent)
        result.success("Proxy service stopped")
    }

    private fun isProxyRunning(result: MethodChannel.Result) {
        result.success(ProxyService.isRunning)
    }

    private fun requestVpnPermission() {
        val intent = VpnService.prepare(this)
        if (intent != null) {
            startActivityForResult(intent, VPN_REQUEST_CODE)
        } else {
            startVpnService()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE && resultCode == Activity.RESULT_OK) {
            startVpnService()
        }
    }

    private fun startVpnService() {
        val vpnIntent = Intent(this, ProxyVpnService::class.java)
        startService(vpnIntent)
    }
}
