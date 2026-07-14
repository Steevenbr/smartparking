package com.example.smart_parking

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "smart_parking/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "savePdfToDownloads") {
                    try {
                        val fileName = call.argument<String>("fileName")
                        val bytes = call.argument<ByteArray>("bytes")
                        if (fileName.isNullOrBlank() || bytes == null) {
                            result.error("invalid_args", "fileName o bytes vacios", null)
                            return@setMethodCallHandler
                        }
                        val path = savePdfToDownloads(fileName, bytes)
                        result.success(path)
                    } catch (e: Exception) {
                        result.error("save_failed", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun savePdfToDownloads(fileName: String, bytes: ByteArray): String {
        val relativeFolder = Environment.DIRECTORY_DOWNLOADS + "/SmartParking"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+: MediaStore (aparece en Descargas del telefono)
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, "application/pdf")
                put(MediaStore.Downloads.RELATIVE_PATH, relativeFolder)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }

            val resolver = applicationContext.contentResolver
            val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
            val itemUri = resolver.insert(collection, values)
                ?: throw Exception("No se pudo crear el archivo en Descargas")

            resolver.openOutputStream(itemUri)?.use { output ->
                output.write(bytes)
                output.flush()
            } ?: throw Exception("No se pudo escribir el PDF")

            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(itemUri, values, null, null)

            return itemUri.toString()
        }

        // Android 9 y menor: escribir directo en Descargas publicas
        val dir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            "SmartParking"
        )
        if (!dir.exists()) {
            dir.mkdirs()
        }
        val file = File(dir, fileName)
        FileOutputStream(file).use { it.write(bytes) }
        return file.absolutePath
    }
}
