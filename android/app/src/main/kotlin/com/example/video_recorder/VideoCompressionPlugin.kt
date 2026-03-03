package com.example.video_recorder

import android.graphics.SurfaceTexture
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLExt
import android.opengl.EGLSurface
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.view.Surface
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

class VideoCompressionPlugin {
    companion object {
        private const val MAX_TARGET_BITRATE = 2_000_000
        private const val AUDIO_TARGET_BITRATE = 128_000
        private const val TARGET_FPS = 30
        private const val IFRAME_INTERVAL = 2
        private const val TIMEOUT_US = 10_000L
        private const val MAX_WIDTH = 1280
        private const val DURATION_TOLERANCE_MS = 50L
    }

    fun compressVideo(inputPath: String, outputPath: String): Boolean {
        val inputFile = File(inputPath)
        if (!inputFile.exists()) return false

        val outputFile = File(outputPath)
        outputFile.parentFile?.mkdirs()
        if (outputFile.exists()) outputFile.delete()

        val tempVideoOnly = File(outputFile.parentFile, "${outputFile.nameWithoutExtension}_video_only.mp4")
        val tempAudioReencoded = File(outputFile.parentFile, "${outputFile.nameWithoutExtension}_audio_aac.mp4")

        tempVideoOnly.delete()
        tempAudioReencoded.delete()

        return try {
            val sourceMeta = loadSourceVideoMeta(inputPath) ?: return false

            if (!transcodeVideoOnly(inputPath, tempVideoOnly.path, sourceMeta)) {
                cleanupFiles(outputFile, tempVideoOnly, tempAudioReencoded)
                return false
            }

            val hasAudio = hasAudioTrack(inputPath)

            val muxSuccess = if (hasAudio) {
                muxVideoWithAudioPassthrough(
                    videoOnlyPath = tempVideoOnly.path,
                    originalInputPath = inputPath,
                    outputPath = outputPath,
                ) || run {
                    reencodeAudioToAacMp4(
                        originalInputPath = inputPath,
                        outputAudioPath = tempAudioReencoded.path,
                    ) && muxVideoWithEncodedAudio(
                        videoOnlyPath = tempVideoOnly.path,
                        encodedAudioPath = tempAudioReencoded.path,
                        outputPath = outputPath,
                    )
                }
            } else {
                tempVideoOnly.copyTo(outputFile, overwrite = true)
                true
            }

            tempVideoOnly.delete()
            tempAudioReencoded.delete()

            if (!muxSuccess) {
                cleanupFiles(outputFile)
                return false
            }

            if (!validateOutput(inputPath, outputPath)) {
                cleanupFiles(outputFile)
                return false
            }

            true
        } catch (_: Exception) {
            cleanupFiles(outputFile, tempVideoOnly, tempAudioReencoded)
            false
        }
    }

    private fun loadSourceVideoMeta(inputPath: String): SourceVideoMeta? {
        var extractor: MediaExtractor? = null
        return try {
            extractor = MediaExtractor().apply { setDataSource(inputPath) }
            val videoTrack = findTrack(extractor, "video/")
            if (videoTrack < 0) return null

            val format = extractor.getTrackFormat(videoTrack)
            val sourceWidth = format.getInteger(MediaFormat.KEY_WIDTH)
            val sourceHeight = format.getInteger(MediaFormat.KEY_HEIGHT)
            val sourceBitrate = if (format.containsKey(MediaFormat.KEY_BIT_RATE)) {
                max(format.getInteger(MediaFormat.KEY_BIT_RATE), 1)
            } else {
                4_000_000
            }

            val targetBitrate = max(1_000_000, min((sourceBitrate * 0.5).roundToInt(), MAX_TARGET_BITRATE))
            val (targetWidth, targetHeight) = scaledSize(sourceWidth, sourceHeight)
            SourceVideoMeta(
                targetWidth = targetWidth,
                targetHeight = targetHeight,
                targetBitrate = targetBitrate,
            )
        } catch (_: Exception) {
            null
        } finally {
            try {
                extractor?.release()
            } catch (_: Exception) {
            }
        }
    }

    private fun transcodeVideoOnly(inputPath: String, outputPath: String, meta: SourceVideoMeta): Boolean {
        var extractor: MediaExtractor? = null
        var muxer: MediaMuxer? = null
        var decoder: MediaCodec? = null
        var encoder: MediaCodec? = null
        var outputSurface: OutputSurface? = null
        var inputSurface: InputSurface? = null
        var muxerStarted = false

        val outputFile = File(outputPath)
        if (outputFile.exists()) outputFile.delete()

        return try {
            extractor = MediaExtractor().apply { setDataSource(inputPath) }
            val videoTrack = findTrack(extractor, "video/")
            if (videoTrack < 0) return false
            val inputVideoFormat = extractor.getTrackFormat(videoTrack)

            val outputVideoFormat = MediaFormat.createVideoFormat(
                MediaFormat.MIMETYPE_VIDEO_AVC,
                meta.targetWidth,
                meta.targetHeight,
            ).apply {
                setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
                setInteger(MediaFormat.KEY_BIT_RATE, meta.targetBitrate)
                setInteger(MediaFormat.KEY_FRAME_RATE, TARGET_FPS)
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, IFRAME_INTERVAL)
            }

            encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
            encoder.configure(outputVideoFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            inputSurface = InputSurface(encoder.createInputSurface())
            inputSurface.makeCurrent()
            encoder.start()

            outputSurface = OutputSurface()
            val inputMime = inputVideoFormat.getString(MediaFormat.KEY_MIME) ?: return false
            decoder = MediaCodec.createDecoderByType(inputMime)
            decoder.configure(inputVideoFormat, outputSurface.surface, null, 0)
            decoder.start()

            muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            var muxerVideoTrack = -1

            extractor.selectTrack(videoTrack)

            val encoderBufferInfo = MediaCodec.BufferInfo()
            val decoderBufferInfo = MediaCodec.BufferInfo()

            var inputDone = false
            var decoderDone = false
            var encoderDone = false
            var consecutiveNoProgress = 0

            while (!encoderDone) {
                var progressed = false

                if (!inputDone) {
                    val inputBufferIndex = decoder.dequeueInputBuffer(TIMEOUT_US)
                    if (inputBufferIndex >= 0) {
                        val inputBuffer = decoder.getInputBuffer(inputBufferIndex) ?: return false
                        val sampleSize = extractor.readSampleData(inputBuffer, 0)
                        if (sampleSize < 0) {
                            decoder.queueInputBuffer(
                                inputBufferIndex,
                                0,
                                0,
                                0L,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            inputDone = true
                        } else {
                            decoder.queueInputBuffer(
                                inputBufferIndex,
                                0,
                                sampleSize,
                                extractor.sampleTime,
                                extractor.sampleFlags,
                            )
                            extractor.advance()
                        }
                        progressed = true
                    }
                }

                var encoderOutputAvailable = true
                var decoderOutputAvailable = !decoderDone

                while (encoderOutputAvailable || decoderOutputAvailable) {
                    val encoderStatus = encoder.dequeueOutputBuffer(encoderBufferInfo, TIMEOUT_US)
                    when {
                        encoderStatus == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                            encoderOutputAvailable = false
                        }

                        encoderStatus == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            if (muxerStarted) return false
                            muxerVideoTrack = muxer.addTrack(encoder.outputFormat)
                            muxer.start()
                            muxerStarted = true
                            progressed = true
                        }

                        encoderStatus >= 0 -> {
                            val encodedData = encoder.getOutputBuffer(encoderStatus) ?: return false

                            if (encoderBufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                                encoderBufferInfo.size = 0
                            }

                            if (encoderBufferInfo.size > 0) {
                                if (!muxerStarted || muxerVideoTrack < 0) return false
                                encodedData.position(encoderBufferInfo.offset)
                                encodedData.limit(encoderBufferInfo.offset + encoderBufferInfo.size)
                                muxer.writeSampleData(muxerVideoTrack, encodedData, encoderBufferInfo)
                                progressed = true
                            }

                            encoder.releaseOutputBuffer(encoderStatus, false)

                            if (encoderBufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                                encoderDone = true
                                break
                            }
                        }
                    }

                    if (!decoderDone) {
                        val decoderStatus = decoder.dequeueOutputBuffer(decoderBufferInfo, TIMEOUT_US)
                        when {
                            decoderStatus == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                                decoderOutputAvailable = false
                            }

                            decoderStatus == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> Unit

                            decoderStatus >= 0 -> {
                                val doRender = decoderBufferInfo.size > 0
                                decoder.releaseOutputBuffer(decoderStatus, doRender)

                                if (doRender) {
                                    outputSurface.awaitNewImage()
                                    outputSurface.drawImage()
                                    inputSurface.setPresentationTime(decoderBufferInfo.presentationTimeUs * 1000L)
                                    inputSurface.swapBuffers()
                                    progressed = true
                                }

                                if (decoderBufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                                    decoderDone = true
                                    encoder.signalEndOfInputStream()
                                    progressed = true
                                }
                            }
                        }
                    }
                }

                if (progressed) {
                    consecutiveNoProgress = 0
                } else {
                    consecutiveNoProgress += 1
                    if (consecutiveNoProgress > 500) {
                        return false
                    }
                }
            }

            muxerStarted
        } catch (_: Exception) {
            false
        } finally {
            try { encoder?.stop() } catch (_: Exception) {}
            try { encoder?.release() } catch (_: Exception) {}
            try { decoder?.stop() } catch (_: Exception) {}
            try { decoder?.release() } catch (_: Exception) {}
            try { if (muxerStarted) muxer?.stop() } catch (_: Exception) {}
            try { muxer?.release() } catch (_: Exception) {}
            try { extractor?.release() } catch (_: Exception) {}
            try { outputSurface?.release() } catch (_: Exception) {}
            try { inputSurface?.release() } catch (_: Exception) {}

            if (!outputFile.exists() || outputFile.length() <= 0L) {
                outputFile.delete()
            }
        }
    }

    private fun muxVideoWithAudioPassthrough(videoOnlyPath: String, originalInputPath: String, outputPath: String): Boolean {
        var videoExtractor: MediaExtractor? = null
        var audioExtractor: MediaExtractor? = null
        var muxer: MediaMuxer? = null
        var muxerStarted = false

        val outputFile = File(outputPath)
        if (outputFile.exists()) outputFile.delete()

        return try {
            videoExtractor = MediaExtractor().apply { setDataSource(videoOnlyPath) }
            audioExtractor = MediaExtractor().apply { setDataSource(originalInputPath) }
            muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

            val videoTrack = findTrack(videoExtractor, "video/")
            val audioTrack = findTrack(audioExtractor, "audio/")
            if (videoTrack < 0 || audioTrack < 0) return false

            val muxerVideoTrack = muxer.addTrack(videoExtractor.getTrackFormat(videoTrack))
            val muxerAudioTrack = muxer.addTrack(audioExtractor.getTrackFormat(audioTrack))
            muxer.start()
            muxerStarted = true

            copyTrackSamples(videoExtractor, videoTrack, muxer, muxerVideoTrack)
            copyTrackSamples(audioExtractor, audioTrack, muxer, muxerAudioTrack)

            true
        } catch (_: Exception) {
            false
        } finally {
            try { if (muxerStarted) muxer?.stop() } catch (_: Exception) {}
            try { muxer?.release() } catch (_: Exception) {}
            try { videoExtractor?.release() } catch (_: Exception) {}
            try { audioExtractor?.release() } catch (_: Exception) {}

            if (!outputFile.exists() || outputFile.length() <= 0L) {
                outputFile.delete()
            }
        }
    }

    private fun reencodeAudioToAacMp4(originalInputPath: String, outputAudioPath: String): Boolean {
        var extractor: MediaExtractor? = null
        var decoder: MediaCodec? = null
        var encoder: MediaCodec? = null
        var muxer: MediaMuxer? = null
        var muxerStarted = false

        val outputFile = File(outputAudioPath)
        if (outputFile.exists()) outputFile.delete()

        return try {
            extractor = MediaExtractor().apply { setDataSource(originalInputPath) }
            val audioTrack = findTrack(extractor, "audio/")
            if (audioTrack < 0) return false

            val inputFormat = extractor.getTrackFormat(audioTrack)
            val inputMime = inputFormat.getString(MediaFormat.KEY_MIME) ?: return false
            val sampleRate = if (inputFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) inputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE) else 44100
            val channelCount = if (inputFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) inputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT) else 2

            decoder = MediaCodec.createDecoderByType(inputMime)
            decoder.configure(inputFormat, null, null, 0)
            decoder.start()

            val outputAudioFormat = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, sampleRate, channelCount).apply {
                setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                setInteger(MediaFormat.KEY_BIT_RATE, AUDIO_TARGET_BITRATE)
                setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 256 * 1024)
            }

            encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
            encoder.configure(outputAudioFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            encoder.start()

            muxer = MediaMuxer(outputAudioPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            var muxerAudioTrack = -1

            extractor.selectTrack(audioTrack)

            val decoderInfo = MediaCodec.BufferInfo()
            val encoderInfo = MediaCodec.BufferInfo()

            var extractorDone = false
            var decoderDone = false
            var encoderDone = false
            var consecutiveNoProgress = 0

            while (!encoderDone) {
                var progressed = false
                if (!extractorDone) {
                    val inputBufferIndex = decoder.dequeueInputBuffer(TIMEOUT_US)
                    if (inputBufferIndex >= 0) {
                        val inputBuffer = decoder.getInputBuffer(inputBufferIndex) ?: return false
                        val sampleSize = extractor.readSampleData(inputBuffer, 0)
                        if (sampleSize < 0) {
                            decoder.queueInputBuffer(inputBufferIndex, 0, 0, 0L, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            extractorDone = true
                        } else {
                            decoder.queueInputBuffer(inputBufferIndex, 0, sampleSize, extractor.sampleTime, extractor.sampleFlags)
                            extractor.advance()
                        }
                        progressed = true
                    }
                }

                var decoderOutputAvailable = !decoderDone
                var encoderOutputAvailable = true

                while (decoderOutputAvailable || encoderOutputAvailable) {
                    val encoderStatus = encoder.dequeueOutputBuffer(encoderInfo, TIMEOUT_US)
                    when {
                        encoderStatus == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                            encoderOutputAvailable = false
                        }

                        encoderStatus == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            if (muxerStarted) return false
                            muxerAudioTrack = muxer.addTrack(encoder.outputFormat)
                            muxer.start()
                            muxerStarted = true
                            progressed = true
                        }

                        encoderStatus >= 0 -> {
                            val encodedData = encoder.getOutputBuffer(encoderStatus) ?: return false

                            if (encoderInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                                encoderInfo.size = 0
                            }

                            if (encoderInfo.size > 0) {
                                if (!muxerStarted || muxerAudioTrack < 0) return false
                                encodedData.position(encoderInfo.offset)
                                encodedData.limit(encoderInfo.offset + encoderInfo.size)
                                muxer.writeSampleData(muxerAudioTrack, encodedData, encoderInfo)
                                progressed = true
                            }

                            encoder.releaseOutputBuffer(encoderStatus, false)

                            if (encoderInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                                encoderDone = true
                                break
                            }
                        }
                    }

                    if (!decoderDone) {
                        val decoderStatus = decoder.dequeueOutputBuffer(decoderInfo, TIMEOUT_US)
                        when {
                            decoderStatus == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                                decoderOutputAvailable = false
                            }
                            decoderStatus == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> Unit
                            decoderStatus >= 0 -> {
                                val decodedData = decoder.getOutputBuffer(decoderStatus)
                                if (decoderInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                                    val inIndex = encoder.dequeueInputBuffer(TIMEOUT_US)
                                    if (inIndex >= 0) {
                                        encoder.queueInputBuffer(inIndex, 0, 0, decoderInfo.presentationTimeUs, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                        progressed = true
                                    }
                                    decoderDone = true
                                } else if (decoderInfo.size > 0 && decodedData != null) {
                                    val inIndex = encoder.dequeueInputBuffer(TIMEOUT_US)
                                    if (inIndex >= 0) {
                                        val inBuffer = encoder.getInputBuffer(inIndex) ?: return false
                                        inBuffer.clear()
                                        decodedData.position(decoderInfo.offset)
                                        decodedData.limit(decoderInfo.offset + decoderInfo.size)
                                        inBuffer.put(decodedData)
                                        encoder.queueInputBuffer(inIndex, 0, decoderInfo.size, decoderInfo.presentationTimeUs, 0)
                                        progressed = true
                                    }
                                }
                                decoder.releaseOutputBuffer(decoderStatus, false)
                            }
                        }
                    }
                }

                if (progressed) {
                    consecutiveNoProgress = 0
                } else {
                    consecutiveNoProgress += 1
                    if (consecutiveNoProgress > 500) return false
                }
            }

            muxerStarted
        } catch (_: Exception) {
            false
        } finally {
            try { encoder?.stop() } catch (_: Exception) {}
            try { encoder?.release() } catch (_: Exception) {}
            try { decoder?.stop() } catch (_: Exception) {}
            try { decoder?.release() } catch (_: Exception) {}
            try { if (muxerStarted) muxer?.stop() } catch (_: Exception) {}
            try { muxer?.release() } catch (_: Exception) {}
            try { extractor?.release() } catch (_: Exception) {}

            if (!outputFile.exists() || outputFile.length() <= 0L) {
                outputFile.delete()
            }
        }
    }

    private fun muxVideoWithEncodedAudio(videoOnlyPath: String, encodedAudioPath: String, outputPath: String): Boolean {
        var videoExtractor: MediaExtractor? = null
        var audioExtractor: MediaExtractor? = null
        var muxer: MediaMuxer? = null
        var muxerStarted = false

        val outputFile = File(outputPath)
        if (outputFile.exists()) outputFile.delete()

        return try {
            videoExtractor = MediaExtractor().apply { setDataSource(videoOnlyPath) }
            audioExtractor = MediaExtractor().apply { setDataSource(encodedAudioPath) }
            muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

            val videoTrack = findTrack(videoExtractor, "video/")
            val audioTrack = findTrack(audioExtractor, "audio/")
            if (videoTrack < 0 || audioTrack < 0) return false

            val muxerVideoTrack = muxer.addTrack(videoExtractor.getTrackFormat(videoTrack))
            val muxerAudioTrack = muxer.addTrack(audioExtractor.getTrackFormat(audioTrack))
            muxer.start()
            muxerStarted = true

            copyTrackSamples(videoExtractor, videoTrack, muxer, muxerVideoTrack)
            copyTrackSamples(audioExtractor, audioTrack, muxer, muxerAudioTrack)

            true
        } catch (_: Exception) {
            false
        } finally {
            try { if (muxerStarted) muxer?.stop() } catch (_: Exception) {}
            try { muxer?.release() } catch (_: Exception) {}
            try { videoExtractor?.release() } catch (_: Exception) {}
            try { audioExtractor?.release() } catch (_: Exception) {}

            if (!outputFile.exists() || outputFile.length() <= 0L) {
                outputFile.delete()
            }
        }
    }

    private fun copyTrackSamples(extractor: MediaExtractor, sourceTrack: Int, muxer: MediaMuxer, muxerTrack: Int) {
        extractor.selectTrack(sourceTrack)
        val format = extractor.getTrackFormat(sourceTrack)
        val maxInputSize = if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
            format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE)
        } else {
            512 * 1024
        }
        val buffer = ByteBuffer.allocateDirect(maxInputSize)
        val info = MediaCodec.BufferInfo()

        while (true) {
            buffer.clear()
            info.offset = 0
            info.size = extractor.readSampleData(buffer, 0)
            if (info.size < 0) {
                break
            }
            info.presentationTimeUs = extractor.sampleTime
            info.flags = extractor.sampleFlags
            buffer.position(0)
            buffer.limit(info.size)
            muxer.writeSampleData(muxerTrack, buffer, info)
            extractor.advance()
        }

        extractor.unselectTrack(sourceTrack)
    }

    private fun validateOutput(inputPath: String, outputPath: String): Boolean {
        val inputFile = File(inputPath)
        val outputFile = File(outputPath)

        if (!outputFile.exists() || outputFile.length() <= 0L) return false
        if (outputFile.length() >= inputFile.length()) return false

        val inputDuration = getDurationMs(inputPath)
        val outputDuration = getDurationMs(outputPath)
        if (inputDuration <= 0L || outputDuration <= 0L) return false

        return abs(inputDuration - outputDuration) <= DURATION_TOLERANCE_MS
    }

    private fun getDurationMs(path: String): Long {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(path)
            retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: -1L
        } catch (_: Exception) {
            -1L
        } finally {
            try {
                retriever.release()
            } catch (_: Exception) {
            }
        }
    }

    private fun findTrack(extractor: MediaExtractor, prefix: String): Int {
        for (i in 0 until extractor.trackCount) {
            val mime = extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME) ?: continue
            if (mime.startsWith(prefix)) return i
        }
        return -1
    }


    private fun hasAudioTrack(inputPath: String): Boolean {
        var extractor: MediaExtractor? = null
        return try {
            extractor = MediaExtractor().apply { setDataSource(inputPath) }
            findTrack(extractor, "audio/") >= 0
        } catch (_: Exception) {
            false
        } finally {
            try {
                extractor?.release()
            } catch (_: Exception) {
            }
        }
    }

    private fun scaledSize(width: Int, height: Int): Pair<Int, Int> {
        if (width <= MAX_WIDTH) return Pair(width, ensureEven(height))

        val ratio = MAX_WIDTH.toFloat() / width.toFloat()
        val scaledHeight = (height * ratio).roundToInt().coerceAtLeast(2)
        return Pair(MAX_WIDTH, ensureEven(scaledHeight))
    }

    private fun ensureEven(value: Int): Int {
        return if (value % 2 == 0) value else value - 1
    }

    private fun cleanupFiles(vararg files: File) {
        files.forEach { file ->
            try {
                if (file.exists()) file.delete()
            } catch (_: Exception) {
            }
        }
    }
}

private data class SourceVideoMeta(
    val targetWidth: Int,
    val targetHeight: Int,
    val targetBitrate: Int,
)

private class InputSurface(private val surface: Surface) {
    private var eglDisplay: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var eglContext: EGLContext = EGL14.EGL_NO_CONTEXT
    private var eglSurface: EGLSurface = EGL14.EGL_NO_SURFACE

    init {
        eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        check(eglDisplay != EGL14.EGL_NO_DISPLAY) { "unable to get EGL14 display" }
        val version = IntArray(2)
        check(EGL14.eglInitialize(eglDisplay, version, 0, version, 1)) { "unable to initialize EGL14" }

        val attribList = intArrayOf(
            EGL14.EGL_RED_SIZE, 8,
            EGL14.EGL_GREEN_SIZE, 8,
            EGL14.EGL_BLUE_SIZE, 8,
            EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
            EGL14.EGL_NONE,
        )
        val configs = arrayOfNulls<EGLConfig>(1)
        val numConfigs = IntArray(1)
        check(EGL14.eglChooseConfig(eglDisplay, attribList, 0, configs, 0, configs.size, numConfigs, 0))

        val attribListContext = intArrayOf(
            EGL14.EGL_CONTEXT_CLIENT_VERSION, 2,
            EGL14.EGL_NONE,
        )
        eglContext = EGL14.eglCreateContext(eglDisplay, configs[0], EGL14.EGL_NO_CONTEXT, attribListContext, 0)
        check(eglContext != null && eglContext != EGL14.EGL_NO_CONTEXT)

        val surfaceAttribs = intArrayOf(EGL14.EGL_NONE)
        eglSurface = EGL14.eglCreateWindowSurface(eglDisplay, configs[0], surface, surfaceAttribs, 0)
        check(eglSurface != null && eglSurface != EGL14.EGL_NO_SURFACE)
    }

    fun makeCurrent() {
        check(EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext))
    }

    fun swapBuffers(): Boolean = EGL14.eglSwapBuffers(eglDisplay, eglSurface)

    fun setPresentationTime(nsecs: Long) {
        EGLExt.eglPresentationTimeANDROID(eglDisplay, eglSurface, nsecs)
    }

    fun release() {
        if (eglDisplay !== EGL14.EGL_NO_DISPLAY) {
            EGL14.eglDestroySurface(eglDisplay, eglSurface)
            EGL14.eglDestroyContext(eglDisplay, eglContext)
            EGL14.eglReleaseThread()
            EGL14.eglTerminate(eglDisplay)
        }
        surface.release()
        eglDisplay = EGL14.EGL_NO_DISPLAY
        eglContext = EGL14.EGL_NO_CONTEXT
        eglSurface = EGL14.EGL_NO_SURFACE
    }
}

private class OutputSurface : SurfaceTexture.OnFrameAvailableListener {
    private val textureRender = TextureRender()
    private val surfaceTexture: SurfaceTexture
    val surface: Surface

    private val frameSyncObject = Object()
    private var frameAvailable = false

    init {
        textureRender.surfaceCreated()
        surfaceTexture = SurfaceTexture(textureRender.textureId)
        surfaceTexture.setOnFrameAvailableListener(this)
        surface = Surface(surfaceTexture)
    }

    fun awaitNewImage() {
        val timeoutMs = 5000L
        val start = System.currentTimeMillis()
        synchronized(frameSyncObject) {
            while (!frameAvailable) {
                val elapsed = System.currentTimeMillis() - start
                if (elapsed >= timeoutMs) {
                    throw RuntimeException("frame wait timed out")
                }
                frameSyncObject.wait(timeoutMs - elapsed)
            }
            frameAvailable = false
        }
        surfaceTexture.updateTexImage()
    }

    fun drawImage() {
        textureRender.drawFrame(surfaceTexture)
    }

    fun release() {
        surface.release()
        surfaceTexture.release()
        textureRender.release()
    }

    override fun onFrameAvailable(st: SurfaceTexture) {
        synchronized(frameSyncObject) {
            frameAvailable = true
            frameSyncObject.notifyAll()
        }
    }
}

private class TextureRender {
    private val vertexShader = "attribute vec4 aPosition;attribute vec4 aTextureCoord;varying vec2 vTextureCoord;void main(){gl_Position=aPosition;vTextureCoord=aTextureCoord.xy;}"
    private val fragmentShader = "#extension GL_OES_EGL_image_external : require\nprecision mediump float;varying vec2 vTextureCoord;uniform samplerExternalOES sTexture;void main(){gl_FragColor = texture2D(sTexture, vTextureCoord);}"

    private val triangleVerticesData = floatArrayOf(
        -1.0f, -1.0f, 0f, 0f,
        1.0f, -1.0f, 1f, 0f,
        -1.0f, 1.0f, 0f, 1f,
        1.0f, 1.0f, 1f, 1f,
    )

    private val triangleVertices: FloatBuffer =
        ByteBuffer.allocateDirect(triangleVerticesData.size * 4).order(ByteOrder.nativeOrder()).asFloatBuffer().apply {
            put(triangleVerticesData).position(0)
        }

    var textureId: Int = -1
        private set

    private var program = 0
    private var aPositionHandle = 0
    private var aTextureCoordHandle = 0
    private var uTextureHandle = 0

    fun surfaceCreated() {
        program = createProgram(vertexShader, fragmentShader)
        aPositionHandle = GLES20.glGetAttribLocation(program, "aPosition")
        aTextureCoordHandle = GLES20.glGetAttribLocation(program, "aTextureCoord")
        uTextureHandle = GLES20.glGetUniformLocation(program, "sTexture")

        val textures = IntArray(1)
        GLES20.glGenTextures(1, textures, 0)
        textureId = textures[0]
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, textureId)
        GLES20.glTexParameterf(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR.toFloat())
        GLES20.glTexParameterf(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR.toFloat())
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
    }

    fun drawFrame(st: SurfaceTexture) {
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        GLES20.glUseProgram(program)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, textureId)
        GLES20.glUniform1i(uTextureHandle, 0)

        triangleVertices.position(0)
        GLES20.glVertexAttribPointer(aPositionHandle, 2, GLES20.GL_FLOAT, false, 16, triangleVertices)
        GLES20.glEnableVertexAttribArray(aPositionHandle)

        triangleVertices.position(2)
        GLES20.glVertexAttribPointer(aTextureCoordHandle, 2, GLES20.GL_FLOAT, false, 16, triangleVertices)
        GLES20.glEnableVertexAttribArray(aTextureCoordHandle)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glFinish()
    }

    fun release() {
        if (program != 0) {
            GLES20.glDeleteProgram(program)
            program = 0
        }
    }

    private fun loadShader(shaderType: Int, source: String): Int {
        val shader = GLES20.glCreateShader(shaderType)
        GLES20.glShaderSource(shader, source)
        GLES20.glCompileShader(shader)
        return shader
    }

    private fun createProgram(vertexSource: String, fragmentSource: String): Int {
        val vertexShader = loadShader(GLES20.GL_VERTEX_SHADER, vertexSource)
        val pixelShader = loadShader(GLES20.GL_FRAGMENT_SHADER, fragmentSource)
        val program = GLES20.glCreateProgram()
        GLES20.glAttachShader(program, vertexShader)
        GLES20.glAttachShader(program, pixelShader)
        GLES20.glLinkProgram(program)
        return program
    }
}
