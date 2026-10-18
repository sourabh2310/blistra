package com.blistra.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "blistra/device_context")
            .setMethodCallHandler { call, result ->
                if (call.method == "timezone") result.success(TimeZone.getDefault().id)
                else result.notImplemented()
            }
    }
}
