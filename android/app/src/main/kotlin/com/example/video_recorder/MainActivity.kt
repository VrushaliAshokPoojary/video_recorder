package com.example.video_recorder

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.video_recorder/video_compression"

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

                        Thread {
                            val success = VideoCompressionPlugin().compressVideo(inputPath, outputPath)
                            runOnUiThread { result.success(success) }
                        }.start()
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
