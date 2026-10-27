package dev.chandra.chat_media_cleaner

import android.content.Intent
import dev.chandra.chat_media_cleaner.storage.StorageChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var storage: StorageChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val handler = StorageChannel(this)
        storage = handler
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, StorageChannel.CHANNEL)
            .setMethodCallHandler(handler)
    }

    @Deprecated("FlutterActivity is not a ComponentActivity, so the result API is not available.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (storage?.onActivityResult(requestCode, resultCode, data) == true) return
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        storage?.dispose()
        storage = null
        super.onDestroy()
    }
}
