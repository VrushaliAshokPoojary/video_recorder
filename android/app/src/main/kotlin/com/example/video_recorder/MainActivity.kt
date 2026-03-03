package com.example.video_recorder

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.video_recorder/video_compression"
    private val compressionExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "compressVideo" -> {
                        val inputPath = call.argument<String>("inputPath")
                        val outputPath = call.argument<String>("outputPath")

                        if (inputPath.isNullOrBlank() || outputPath.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "inputPath and outputPath are required", null)
                            return@setMethodCallHandler
                        }

                        compressionExecutor.execute {
                            val success = VideoCompressionPlugin().compressVideo(inputPath, outputPath)
                            runOnUiThread { result.success(success) }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        compressionExecutor.shutdown()
        super.onDestroy()
    }
}
