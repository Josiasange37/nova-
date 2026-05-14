package com.nova.nova

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.nova.nova/adb"
    private var adbFile: File? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Extract ADB binary as early as possible, in background thread
        Thread { extractAdbBinary() }.start()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "executeCommand" -> {
                        val command = call.argument<String>("command") ?: run {
                            result.error("INVALID_ARGUMENT", "Command is null", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                val output = runAdb(*command.split(" ").toTypedArray())
                                result.success(output)
                            } catch (e: Exception) {
                                result.error("ADB_ERROR", e.message, null)
                            }
                        }.start()
                    }

                    "captureScreenshot" -> {
                        Thread {
                            try {
                                val bytes = captureScreenshot()
                                result.success(bytes)
                            } catch (e: Exception) {
                                result.error("SCREENSHOT_ERROR", e.message, null)
                            }
                        }.start()
                    }

                    "adbPair" -> {
                        val port = call.argument<String>("port") ?: ""
                        val code = call.argument<String>("code") ?: ""
                        Thread {
                            try {
                                val output = runAdb("pair", "127.0.0.1:$port", code)
                                result.success(output)
                            } catch (e: Exception) {
                                result.error("PAIR_ERROR", e.message, null)
                            }
                        }.start()
                    }

                    "adbConnect" -> {
                        val port = call.argument<String>("port") ?: ""
                        Thread {
                            try {
                                // First kill server, then start fresh & connect
                                runAdb("kill-server")
                                runAdb("start-server")
                                val output = runAdb("connect", "127.0.0.1:$port")
                                android.util.Log.d("NOVA_ADB", "Connect result: $output")
                                result.success(output)
                            } catch (e: Exception) {
                                result.error("CONNECT_ERROR", e.message, null)
                            }
                        }.start()
                    }

                    "isConnected" -> {
                        Thread {
                            try {
                                val output = runAdb("devices")
                                result.success(output.contains("127.0.0.1"))
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        }.start()
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /** Extract the ADB binary from assets to filesDir and make it executable. */
    private fun extractAdbBinary() {
        val dest = File(filesDir, "adb")
        adbFile = dest

        // Determine which ABI binary to use
        val abi = android.os.Build.SUPPORTED_ABIS.firstOrNull() ?: "arm64-v8a"
        val assetName = when {
            abi.contains("arm64") -> "bin/adb_arm64"
            abi.contains("x86_64") -> "bin/adb_x86_64"
            abi.contains("armeabi") -> "bin/adb_arm64" // fallback
            else -> "bin/adb_arm64"
        }

        try {
            android.util.Log.d("NOVA_ADB", "ABI=$abi, extracting asset: $assetName → ${dest.absolutePath}")
            assets.open(assetName).use { input ->
                dest.outputStream().use { output -> input.copyTo(output) }
            }
            dest.setExecutable(true, false)
            android.util.Log.d("NOVA_ADB", "Extraction OK. Size=${dest.length()} bytes, executable=${dest.canExecute()}")
        } catch (assetEx: Exception) {
            android.util.Log.w("NOVA_ADB", "Asset extraction failed ($assetEx), trying nativeLibraryDir fallback")
            // Fallback: copy from nativeLibraryDir
            try {
                val native = File(applicationInfo.nativeLibraryDir, "libadb.so")
                if (native.exists()) {
                    native.copyTo(dest, overwrite = true)
                    dest.setExecutable(true, false)
                    android.util.Log.d("NOVA_ADB", "Fallback OK from nativeLib. Size=${dest.length()}")
                } else {
                    android.util.Log.e("NOVA_ADB", "Neither asset nor nativeLib found!")
                }
            } catch (fbEx: Exception) {
                android.util.Log.e("NOVA_ADB", "Fallback also failed: $fbEx")
            }
        }
    }

    /** Capture a screenshot and return raw PNG bytes. */
    private fun captureScreenshot(): ByteArray {
        val adb = ensureAdb()
        val pb = ProcessBuilder(adb, "shell", "screencap", "-p")
            .redirectErrorStream(false)
            .directory(filesDir)
        pb.environment().apply {
            put("HOME", filesDir.path)
            put("TMPDIR", cacheDir.path)
        }
        val proc = pb.start()
        val bytes = proc.inputStream.readBytes()
        proc.waitFor()

        // On some ADB implementations \r\n needs to be fixed for PNG
        // screencap -p on Android outputs clean PNG directly via adb shell
        return bytes
    }

    /** Run an ADB command and return stdout+stderr as a string. */
    private fun runAdb(vararg args: String): String {
        val adb = ensureAdb()
        val cmd = mutableListOf(adb, "shell").also { it.addAll(args) }
        val pb = ProcessBuilder(cmd)
            .directory(filesDir)
            .redirectErrorStream(true)
        pb.environment().apply {
            put("HOME", filesDir.path)
            put("TMPDIR", cacheDir.path)
        }
        val proc = pb.start()
        val reader = BufferedReader(InputStreamReader(proc.inputStream))
        val sb = StringBuilder()
        var line: String?
        while (reader.readLine().also { line = it } != null) sb.append(line).append('\n')
        proc.waitFor()
        return sb.toString()
    }

    /** Ensure the ADB binary exists; re-extract if needed. */
    private fun ensureAdb(): String {
        val f = adbFile ?: File(filesDir, "adb").also { adbFile = it }
        if (!f.exists() || !f.canExecute()) extractAdbBinary()
        if (!f.exists()) throw RuntimeException("adb binary missing at ${f.absolutePath}")
        return f.absolutePath
    }
}
