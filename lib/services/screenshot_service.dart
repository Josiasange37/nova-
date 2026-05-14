import 'dart:convert';
import 'package:flutter/services.dart';

class ScreenshotService {
  static const _channel = MethodChannel('com.nova.nova/adb');

  /// Captures a screenshot via native ADB and returns it as a Base64 string.
  static Future<String?> captureAsBase64() async {
    try {
      final Uint8List bytes = await _channel.invokeMethod('captureScreenshot');
      if (bytes.isEmpty) return null;
      return base64Encode(bytes);
    } on PlatformException catch (e) {
      return null;
    } catch (e) {
      return null;
    }
  }
}
