package com.example.alpha

import android.content.Context
import android.content.res.AssetFileDescriptor
import org.tensorflow.lite.Interpreter
import java.io.BufferedReader
import java.io.FileInputStream
import java.io.InputStreamReader
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel

/**
 * Loads yamnet.tflite and yamnet_class_map.csv from assets.
 * Exposes infer() which takes 15 600 raw PCM samples (float32 in [-1,1])
 * and returns (scores[521], embedding[1024]).
 */
class YamNetHelper(private val context: Context) {

    private val interpreter: Interpreter
    private val classMap: Map<Int, String>   // index → display_name
    val speechIndex: Int                     // index of the "Speech" class

    // Alert class names we care about (exact display_name values in the CSV)
    val alertClassNames = setOf(
        "Glass", "Gunshot, gunfire", "Explosion", "Siren",
        "Car horn", "Jackhammer", "Drill", "Screaming"
    )
    val alertIndices: Set<Int>

    companion object {
        const val SAMPLE_RATE = 16_000
        const val WINDOW_SAMPLES = 15_600   // 0.975 s
        private const val NUM_CLASSES = 521
        private const val EMBEDDING_SIZE = 1024
    }

    init {
        interpreter = Interpreter(loadModelFile())
        classMap = loadClassMap()
        speechIndex = classMap.entries.firstOrNull {
            it.value.equals("Speech", ignoreCase = true)
        }?.key ?: 0
        alertIndices = classMap.entries
            .filter { entry -> alertClassNames.any { name -> entry.value.contains(name, ignoreCase = true) } }
            .map { it.key }
            .toSet()
    }

    /** Run YAMNet inference. Returns Pair(scores, embedding). */
    fun infer(samples: FloatArray): Pair<FloatArray, FloatArray> {
        require(samples.size == WINDOW_SAMPLES) {
            "Expected $WINDOW_SAMPLES samples, got ${samples.size}"
        }

        // Input: [1, 15600] float32
        val input = Array(1) { samples }

        // Outputs: scores [1, 521], embedding [1, 1024]
        val scoresOut = Array(1) { FloatArray(NUM_CLASSES) }
        val embeddingOut = Array(1) { FloatArray(EMBEDDING_SIZE) }

        val outputs = mapOf(0 to scoresOut, 1 to embeddingOut)
        interpreter.runForMultipleInputsOutputs(arrayOf(input), outputs)

        return Pair(scoresOut[0], embeddingOut[0])
    }

    /** Returns the display_name for a class index. */
    fun className(index: Int): String = classMap[index] ?: "Unknown"

    // ── Private helpers ──────────────────────────────────────────────────────

    private fun loadModelFile(): MappedByteBuffer {
        val afd: AssetFileDescriptor = context.assets.openFd("yamnet.tflite")
        val fis = FileInputStream(afd.fileDescriptor)
        val channel: FileChannel = fis.channel
        return channel.map(FileChannel.MapMode.READ_ONLY, afd.startOffset, afd.declaredLength)
    }

    /** Parse yamnet_class_map.csv → Map<index, display_name>.
     *  CSV columns: index,mid,display_name  (header row present). */
    private fun loadClassMap(): Map<Int, String> {
        val map = mutableMapOf<Int, String>()
        context.assets.open("yamnet_class_map.csv").use { stream ->
            BufferedReader(InputStreamReader(stream)).use { reader ->
                reader.readLine() // skip header
                reader.forEachLine { line ->
                    val parts = line.split(",", limit = 3)
                    if (parts.size == 3) {
                        val idx = parts[0].trim().toIntOrNull() ?: return@forEachLine
                        val name = parts[2].trim().removeSurrounding("\"")
                        map[idx] = name
                    }
                }
            }
        }
        return map
    }

    fun close() {
        interpreter.close()
    }
}
