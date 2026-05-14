import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyApiKey = 'bigmodel_api_key';
  static const _keyConnectedPort = 'adb_connected_port';

  static const String defaultApiKey = 'PASTE_YOUR_API_KEY_HERE';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get _p {
    if (_prefs == null) throw StateError('SettingsService not initialized');
    return _prefs!;
  }

  static String getApiKey() => _p.getString(_keyApiKey) ?? defaultApiKey;
  static Future<void> setApiKey(String key) => _p.setString(_keyApiKey, key);

  static String getConnectedPort() => _p.getString(_keyConnectedPort) ?? '';
  static Future<void> setConnectedPort(String port) => _p.setString(_keyConnectedPort, port);
}
