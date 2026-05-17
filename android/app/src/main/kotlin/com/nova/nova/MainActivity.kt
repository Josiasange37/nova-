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
    private var targetAddress: String? = null

    private val adbPath: String by lazy {
        "${applicationInfo.nativeLibraryDir}/libadb.so"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "executeCommand" -> {
                        val command = call.argument<String>("command") ?: ""
                        Thread {
                            try {
                                val output = runShell(command)
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
                                runAdb("kill-server")
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
                                runAdb("kill-server")
                                runAdb("start-server")
                                val addr = "127.0.0.1:$port"
                                val output = runAdb("connect", addr)
                                if (output.contains("connected")) {
                                    targetAddress = addr
                                }
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
                                val connected = output.lines().any { it.contains("127.0.0.1") && it.contains("device") }
                                result.success(connected)
                                if (connected && targetAddress == null) {
                                    // Try to auto-pick the address
                                    targetAddress = output.lines().find { it.contains("127.0.0.1") }?.split("\t")?.get(0)?.trim()
                                }
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        }.start()
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun captureScreenshot(): ByteArray {
        val tmpPath = "/sdcard/nova_screen.png"
        runShell("screencap -p $tmpPath")

        val pb = if (targetAddress != null) {
            ProcessBuilder(adbPath, "-s", targetAddress!!, "shell", "cat", tmpPath)
        } else {
            ProcessBuilder(adbPath, "shell", "cat", tmpPath)
        }

        pb.redirectErrorStream(false)
        pb.environment().apply {
            put("HOME", filesDir.path)
            put("TMPDIR", cacheDir.path)
        }
        val proc = pb.start()
        val bytes = proc.inputStream.readBytes()
        proc.waitFor()

        runShell("rm $tmpPath")
        return bytes
    }

    /** Run a shell command on the target device. */
    private fun runShell(command: String): String {
        return if (targetAddress != null) {
            runAdb("-s", targetAddress!!, "shell", command)
        } else {
            runAdb("shell", command)
        }
    }

    /** Run a raw ADB command. */
    private fun runAdb(vararg args: String): String {
        val cmd = mutableListOf(adbPath).also { it.addAll(args) }
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
}
