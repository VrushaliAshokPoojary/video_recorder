package com.example.video_recorder

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File

class VideoCompressionPlugin {
    fun compressVideo(inputPath: String, outputPath: String): Boolean {
        var extractor: MediaExtractor? = null
        var muxer: MediaMuxer? = null

        return try {
            val inputFile = File(inputPath)
            if (!inputFile.exists()) {
                return false
            }

            val outputFile = File(outputPath)
            outputFile.parentFile?.mkdirs()
            if (outputFile.exists()) {
                outputFile.delete()
            }

            extractor = MediaExtractor()
            extractor.setDataSource(inputPath)

            muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

            val trackMap = mutableMapOf<Int, Int>()
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("video/") || mime.startsWith("audio/")) {
                    // We keep source codecs (H264/AAC) and remux with adjusted timestamps.
                    // MediaCodec constants are used to align with Android codec stack contracts.
                    if (mime.startsWith("video/") && mime != MediaFormat.MIMETYPE_VIDEO_AVC && mime != MediaFormat.MIMETYPE_VIDEO_HEVC) {
                        continue
                    }
                    if (mime.startsWith("audio/") && mime != MediaFormat.MIMETYPE_AUDIO_AAC) {
                        continue
                    }
                    trackMap[i] = muxer.addTrack(format)
                }
            }

            if (trackMap.isEmpty()) {
                return false
            }

            muxer.start()

            val maxBufferSize = trackMap.keys.maxOf { index ->
                val format = extractor.getTrackFormat(index)
                if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                    format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE)
                } else {
                    1 * 1024 * 1024
                }
            }

            val buffer = java.nio.ByteBuffer.allocateDirect(maxBufferSize)

            for ((sourceTrack, targetTrack) in trackMap) {
                extractor.unselectAllTracks(trackMap.keys)
                extractor.selectTrack(sourceTrack)

                val bufferInfo = MediaCodec.BufferInfo()
                while (true) {
                    buffer.clear()
                    bufferInfo.offset = 0
                    bufferInfo.size = extractor.readSampleData(buffer, 0)
                    if (bufferInfo.size < 0) {
                        break
                    }

                    val sourcePtsUs = extractor.sampleTime
                    if (sourcePtsUs < 0) {
                        break
                    }

                    // 2x playback speed: halve all timestamps while preserving full sample sequence.
                    bufferInfo.presentationTimeUs = sourcePtsUs / 2L
                    bufferInfo.flags = extractor.sampleFlags

                    buffer.position(0)
                    buffer.limit(bufferInfo.size)
                    muxer.writeSampleData(targetTrack, buffer, bufferInfo)
                    extractor.advance()
                }
                extractor.unselectTrack(sourceTrack)
            }

            true
        } catch (_: Exception) {
            false
        } finally {
            try {
                extractor?.release()
            } catch (_: Exception) {
            }
            try {
                muxer?.stop()
            } catch (_: Exception) {
            }
            try {
                muxer?.release()
            } catch (_: Exception) {
            }
        }
    }

    private fun MediaExtractor.unselectAllTracks(tracks: Set<Int>) {
        tracks.forEach {
            try {
                unselectTrack(it)
            } catch (_: Exception) {
            }
        }
    }
}
