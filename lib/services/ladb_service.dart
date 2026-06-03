import 'package:flutter/services.dart';

class LadbService {
  static const MethodChannel _channel = MethodChannel('com.nova.nova/adb');

  /// Executes a shell command via local ADB.
  static Future<String> execute(String command) async {
    try {
      final String result = await _channel.invokeMethod('executeCommand', {
        'command': command,
      });
      return result;
    } on PlatformException catch (e) {
      return "Error: ${e.message}";
    }
  }

  static Future<String> pair(String port, String code) async {
    try {
      final String result = await _channel.invokeMethod('adbPair', {
        'port': port,
        'code': code,
      });
      return result;
    } on PlatformException catch (e) {
      return "Pair Error: ${e.message}";
    }
  }

  static Future<String> connect(String port) async {
    try {
      final String result = await _channel.invokeMethod('adbConnect', {
        'port': port,
      });
      return result;
    } on PlatformException catch (e) {
      return "Connect Error: ${e.message}";
    }
  }

  static Future<bool> isConnected() async {
    try {
      final bool connected = await _channel.invokeMethod('isConnected');
      return connected;
    } on PlatformException {
      return false;
    }
  }

  // --- Specific Actions ---

  static Future<void> tap(double x, double y, double screenWidth, double screenHeight) async {
    final int realX = (x * screenWidth).toInt();
    final int realY = (y * screenHeight).toInt();
    await execute("input tap $realX $realY");
  }

  static Future<void> swipe(double x1, double y1, double x2, double y2, double screenWidth, double screenHeight) async {
    final int realX1 = (x1 * screenWidth).toInt();
    final int realY1 = (y1 * screenHeight).toInt();
    final int realX2 = (x2 * screenWidth).toInt();
    final int realY2 = (y2 * screenHeight).toInt();
    await execute("input swipe $realX1 $realY1 $realX2 $realY2 500");
  }

  static Future<void> inputText(String text) async {
    // Note: ADB 'input text' doesn't support spaces easily, often needs wrapping or using IME
    await execute("input text '$text'");
  }

  static Future<void> launchApp(String package) async {
    await execute("monkey -p $package 1");
  }

  static Future<void> home() async {
    await execute("input keyevent 3");
  }

  static Future<void> back() async {
    await execute("input keyevent 4");
  }

  static Future<void> openBatterySettings() async {
    try {
      await _channel.invokeMethod('openBatterySettings');
    } catch (_) {}
  }
}
