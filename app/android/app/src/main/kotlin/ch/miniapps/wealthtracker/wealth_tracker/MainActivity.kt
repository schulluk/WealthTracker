package ch.miniapps.wealthtracker

import android.content.Context
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var wakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Keep the relay (MS sync) forwarding for a short window if the app is
        // briefly backgrounded — a partial wakelock keeps the CPU running with
        // the screen off. See lib/services/ms_relay/background_keepalive.dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "wealth/background_keepalive")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "begin" -> { acquireWakeLock(); result.success(null) }
                    "end" -> { releaseWakeLock(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "wealth:ms-relay").apply {
            setReferenceCounted(false)
            acquire(3 * 60 * 1000L) // safety cap: auto-release after 3 min
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
    }

    override fun onDestroy() {
        releaseWakeLock()
        super.onDestroy()
    }
}
