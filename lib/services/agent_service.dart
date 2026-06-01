import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:nova/models/action_model.dart';
import 'package:nova/services/ladb_service.dart';
import 'package:nova/services/log_service.dart';
import 'package:nova/services/screenshot_service.dart';
import 'package:nova/services/settings_service.dart';

const String _bigModelUrl =
    'https://open.bigmodel.cn/api/paas/v4/chat/completions';
const String _model = 'autoglm-phone';

// App name → package name map (ported from Open-AutoGLM apps.py + extras)
const Map<String, String> _appPackages = {
  // Google Apps
  'Settings': 'com.android.settings',
  'Chrome': 'com.android.chrome',
  'Google Chrome': 'com.android.chrome',
  'Gmail': 'com.google.android.gm',
  'Google Maps': 'com.google.android.apps.maps',
  'Maps': 'com.google.android.apps.maps',
  'Google Drive': 'com.google.android.apps.docs',
  'Google Docs': 'com.google.android.apps.docs.editors.docs',
  'Google Sheets': 'com.google.android.apps.docs.editors.sheets',
  'Google Slides': 'com.google.android.apps.docs.editors.slides',
  'Google Calendar': 'com.google.android.calendar',
  'Google Photos': 'com.google.android.apps.photos',
  'Google Keep': 'com.google.android.keep',
  'Google Meet': 'com.google.android.apps.meetings',
  'Google Chat': 'com.google.android.apps.dynamite',
  'Google Pay': 'com.google.android.apps.nbu.paisa.user',
  'Google Play Store': 'com.android.vending',
  'Play Store': 'com.android.vending',
  'YouTube': 'com.google.android.youtube',
  'YouTube Music': 'com.google.android.apps.youtube.music',
  'Google Clock': 'com.google.android.deskclock',
  'Clock': 'com.android.deskclock',
  'Contacts': 'com.google.android.contacts',
  'Phone': 'com.google.android.dialer',
  'Messages': 'com.google.android.apps.messaging',
  'Camera': 'com.google.android.GoogleCamera',
  'Files': 'com.google.android.apps.nbu.files',
  'Calculator': 'com.google.android.calculator',
  'Google Translate': 'com.google.android.apps.translate',
  'Google Lens': 'com.google.ar.lens',
  // Social & Messaging
  'WhatsApp': 'com.whatsapp',
  'Telegram': 'org.telegram.messenger',
  'Instagram': 'com.instagram.android',
  'Facebook': 'com.facebook.katana',
  'Messenger': 'com.facebook.orca',
  'Twitter': 'com.twitter.android',
  'X': 'com.twitter.android',
  'TikTok': 'com.zhiliaoapp.musically',
  'Snapchat': 'com.snapchat.android',
  'LinkedIn': 'com.linkedin.android',
  'Discord': 'com.discord',
  'Reddit': 'com.reddit.frontpage',
  'Pinterest': 'com.pinterest',
  'Skype': 'com.skype.raider',
  'Signal': 'org.thoughtcrime.securesms',
  'Viber': 'com.viber.voip',
  'WeChat': 'com.tencent.mm',
  // Productivity
  'Microsoft Word': 'com.microsoft.office.word',
  'Microsoft Excel': 'com.microsoft.office.excel',
  'Microsoft PowerPoint': 'com.microsoft.office.powerpoint',
  'Microsoft Teams': 'com.microsoft.teams',
  'Microsoft Outlook': 'com.microsoft.office.outlook',
  'Outlook': 'com.microsoft.office.outlook',
  'Notion': 'notion.id',
  'Slack': 'com.Slack',
  'Zoom': 'us.zoom.videomeetings',
  'Dropbox': 'com.dropbox.android',
  'OneDrive': 'com.microsoft.skydrive',
  'Evernote': 'com.evernote',
  'Trello': 'com.trello',
  'Todoist': 'com.todoist.android.Todoist',
  // Music & Media
  'Spotify': 'com.spotify.music',
  'Netflix': 'com.netflix.mediaclient',
  'Amazon Prime Video': 'com.amazon.avod.thirdpartyclient',
  'Disney+': 'com.disney.disneyplus',
  'YouTube Kids': 'com.google.android.apps.youtube.kids',
  'VLC': 'org.videolan.vlc',
  'Shazam': 'com.shazam.android',
  'SoundCloud': 'com.soundcloud.android',
  // Travel & Maps
  'Uber': 'com.ubercab',
  'Lyft': 'me.lyft.android',
  'Google Flights': 'com.google.android.apps.travel.oneway',
  'Airbnb': 'com.airbnb.android',
  'Booking.com': 'com.booking',
  'Expedia': 'com.expedia.bookings',
  // Finance
  'PayPal': 'com.paypal.android.p2pmobile',
  'Venmo': 'com.venmo',
  'Cash App': 'com.squareup.cash',
  'Binance': 'com.binance.dev',
  'Coinbase': 'com.coinbase.android',
  // Shopping
  'Amazon': 'com.amazon.mShop.android.shopping',
  'Amazon Shopping': 'com.amazon.mShop.android.shopping',
  'eBay': 'com.ebay.mobile',
  'Wish': 'com.contextlogic.wish',
  'Shein': 'com.zzkko',
  'Temu': 'com.einnovation.temu',
  // Health & Fitness
  'MyFitnessPal': 'com.myfitnesspal.android',
  'Strava': 'com.strava',
  'Headspace': 'com.getsomeheadspace.android',
  'Calm': 'com.calm.android',
  // News
  'BBC News': 'bbc.mobile.news.ww',
  'CNN': 'com.cnn.mobile.android.phone',
  'The Guardian': 'com.guardian',
  // Misc
  'Duolingo': 'com.duolingo',
  'Quora': 'com.quora.android',
  'Wikipedia': 'org.wikipedia',
  'QR Code Scanner': 'la.droid.qr',
  'Barcode Scanner': 'com.google.zxing.client.android',
  'Adobe Acrobat': 'com.adobe.reader',
  'Adobe Reader': 'com.adobe.reader',
};

String? _resolvePackage(String appName) {
  // 1. Exact match
  if (_appPackages.containsKey(appName)) return _appPackages[appName];
  // 2. Case-insensitive match
  final lower = appName.toLowerCase();
  for (final entry in _appPackages.entries) {
    if (entry.key.toLowerCase() == lower) return entry.value;
  }
  // 3. If model already passed a package name (contains a dot), use it directly
  if (appName.contains('.') && appName.contains('.')) return appName;
  return null;
}

const String _systemPrompt = '''You are Nova, an intelligent mobile agent. Analyze the screenshot and execute the next step to complete the task.
Your entire response (thinking and actions) MUST be in English.

Output format:
<think>Brief reasoning in English</think>
<answer>do(action="Action", ...)</answer>

Valid Actions:
- do(action="Launch", app="AppName or package.name") -> Prefer using exact app names like "WhatsApp", "Settings", "YouTube".
- do(action="Tap", element=[x,y])
- do(action="Type", text="xxx") (Input box must be focused first)
- do(action="Swipe", start=[x1,y1], end=[x2,y2])
- do(action="Press", key="home"|"back"|"enter"|"recent")
- do(action="Double Tap", element=[x,y])
- do(action="Long Press", element=[x,y])
- do(action="Wait", duration=2000)
- finish(message="Task result summary in English")

Core Rules:
1. Use 0-1000 relative coordinate system (0 is top/left, 1000 is bottom/right).
2. IMPORTANT: You are seeing a clean phone screen. Ignore any prior context about "Nova" app or logs.
3. Check if your previous action worked. If not, retry or adjust coordinates.
4. ALWAYS output in English. No Chinese allowed.''';

class AgentService {
  final LogService logService;
  bool _isRunning = false;

  final List<Map<String, dynamic>> _context = [];

  AgentService(this.logService);

  bool get isRunning => _isRunning;

  void stop() => _isRunning = false;

  Future<void> runTask(String instruction) async {
    if (_isRunning) return;
    _isRunning = true;
    _context.clear();

    logService.log('▶ Starting task: "$instruction"');

    if (!await LadbService.isConnected()) {
      logService.log('❌ ADB not connected. Open Settings to pair/connect first.');
      _isRunning = false;
      return;
    }

    _context.add({'role': 'system', 'content': _systemPrompt});

    int step = 0;
    const int maxSteps = 20;

    try {
      while (_isRunning && step < maxSteps) {
        step++;
        logService.log('── Step $step/$maxSteps ──');

        if (step == 1) {
          logService.log('🏠 Minimizing Nova...');
          await LadbService.execute('input keyevent KEYCODE_HOME');
          await Future.delayed(const Duration(milliseconds: 300));
        }

        logService.log('📷 Capturing screen...');
        final screenshotB64 = await ScreenshotService.captureAsBase64();

        if (screenshotB64 == null || screenshotB64.isEmpty) {
          logService.log('❌ Failed to capture screenshot.');
          break;
        }

        final String userText = step == 1
            ? instruction
            : 'Continue the task. Current screen state shown.';

        _context.add({
          'role': 'user',
          'content': [
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$screenshotB64'},
            },
            {'type': 'text', 'text': userText},
          ],
        });

        logService.log('🧠 Consulting AI...');
        final (thinking, rawAction) = await _callBigModel();
        if (rawAction == null) {
          logService.log('❌ No response from AI.');
          break;
        }

        if (thinking.isNotEmpty) logService.log('💭 $thinking');

        final action = ActionModel.fromResponse(thinking, rawAction);
        logService.log('🎯 Action: ${action.action.name}  ${action.params}');

        // Trim image from context to save tokens
        _context.last = {
          'role': 'user',
          'content': [{'type': 'text', 'text': userText}],
        };
        _context.add({
          'role': 'assistant',
          'content': '<think>$thinking</think><answer>$rawAction</answer>',
        });

        if (action.action == ActionType.finish) {
          logService.log('✅ Done: ${action.params['message']}');
          break;
        }

        if (action.action == ActionType.unknown) {
          logService.log('⚠ Could not parse action: "$rawAction"');
        } else {
          await _executeAction(action);
        }

        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (step >= maxSteps) logService.log('⚠ Max steps reached.');
    } catch (e) {
      logService.log('💥 Error: $e');
    } finally {
      _isRunning = false;
      logService.log('■ Agent stopped.');
    }
  }

  Future<(String, String?)> _callBigModel() async {
    final apiKey = SettingsService.getApiKey();
    if (apiKey.isEmpty || apiKey == SettingsService.defaultApiKey) {
      logService.log('❌ Error: No API key configured. Open Setup to set it.');
      return ('', null);
    }

    try {
      final token = _generateToken(apiKey);
      final response = await http.post(
        Uri.parse(_bigModelUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'model': _model,
          'messages': _context,
          'max_tokens': 2048,
          'temperature': 0.0,
          'top_p': 0.85,
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content =
            data['choices'][0]['message']['content'] as String? ?? '';
        return _parseResponse(content);
      } else {
        logService.log(
            '⚠ API Error ${response.statusCode}: ${response.body}');
        return ('', null);
      }
    } catch (e) {
      logService.log('⚠ Network error: $e');
      return ('', null);
    }
  }

  String _generateToken(String apikey) {
    try {
      final parts = apikey.split('.');
      if (parts.length != 2) return apikey;
      final id = parts[0];
      final secret = parts[1];
      final now = DateTime.now().millisecondsSinceEpoch;
      final exp = now + 3600000;

      final header = base64Url
          .encode(utf8.encode(
              jsonEncode({'alg': 'HS256', 'sign_type': 'SIGN'})))
          .replaceAll('=', '');
      final payload = base64Url
          .encode(utf8.encode(
              jsonEncode({'api_key': id, 'exp': exp, 'timestamp': now})))
          .replaceAll('=', '');
      final signature = Hmac(sha256, utf8.encode(secret))
          .convert(utf8.encode('$header.$payload'));
      final signatureB64 =
          base64Url.encode(signature.bytes).replaceAll('=', '');

      return '$header.$payload.$signatureB64';
    } catch (e) {
      return apikey;
    }
  }

  (String, String?) _parseResponse(String content) {
    content = content.trim();
    if (content.contains('<answer>')) {
      final parts = content.split('<answer>');
      final thinking = parts[0]
          .replaceAll('<think>', '')
          .replaceAll('</think>', '')
          .trim();
      final action = parts[1].replaceAll('</answer>', '').trim();
      return (thinking, action);
    }
    final markerMatch =
        RegExp(r'(do\(|finish\()', caseSensitive: false).firstMatch(content);
    if (markerMatch != null) {
      final idx = markerMatch.start;
      return (content.substring(0, idx).trim(),
          content.substring(idx).trim());
    }
    return ('', content);
  }

  Future<void> _executeAction(ActionModel action) async {
    final p = action.params;

    // Get real device dimensions once per action
    final sizeOut = await LadbService.execute('wm size');
    final m = RegExp(r'(\d+)x(\d+)').firstMatch(sizeOut);
    final w = double.tryParse(m?.group(1) ?? '1080') ?? 1080;
    final h = double.tryParse(m?.group(2) ?? '2400') ?? 2400;

    // Scale from 0-1000 (or 0.0-1.0) to real pixels
    int scaleX(double x) =>
        (x > 1.0 ? (x / 1000.0 * w) : (x * w)).toInt();
    int scaleY(double y) =>
        (y > 1.0 ? (y / 1000.0 * h) : (y * h)).toInt();

    switch (action.action) {
      case ActionType.tap:
        final coord = p['coordinate'] as List<double>?;
        if (coord != null && coord.length >= 2) {
          final x = scaleX(coord[0]);
          final y = scaleY(coord[1]);
          await LadbService.execute('input tap $x $y');
          logService.log('  → tap ($x, $y)');
        }
        break;

      case ActionType.swipe:
        final start =
            p['start'] as List<double>? ?? p['coordinate'] as List<double>?;
        final end = p['end'] as List<double>?;
        final dur = p['duration'] as int? ?? 500;
        if (start != null &&
            end != null &&
            start.length >= 2 &&
            end.length >= 2) {
          final x1 = scaleX(start[0]);
          final y1 = scaleY(start[1]);
          final x2 = scaleX(end[0]);
          final y2 = scaleY(end[1]);
          await LadbService.execute('input swipe $x1 $y1 $x2 $y2 $dur');
          logService.log('  → swipe ($x1,$y1)→($x2,$y2) ${dur}ms');
        }
        break;

      case ActionType.type:
        // Escape special characters for shell
        final raw = p['text'] as String? ?? '';
        final escaped = raw
            .replaceAll('\\', '\\\\')
            .replaceAll("'", "\\'")
            .replaceAll(' ', '%s');
        await LadbService.execute("input text '$escaped'");
        logService.log('  → type "$raw"');
        break;

      case ActionType.press:
        final k = p['key']?.toString().toLowerCase() ?? 'home';
        final keyEvent = {
          'home': 'KEYCODE_HOME',
          'back': 'KEYCODE_BACK',
          'enter': 'KEYCODE_ENTER',
          'recent': 'KEYCODE_APP_SWITCH',
          'volume_up': 'KEYCODE_VOLUME_UP',
          'volume_down': 'KEYCODE_VOLUME_DOWN',
        }[k] ?? 'KEYCODE_HOME';
        await LadbService.execute('input keyevent $keyEvent');
        logService.log('  → press $k ($keyEvent)');
        break;

      case ActionType.launch:
        final appName = p['app'] as String? ?? '';
        final package = _resolvePackage(appName);
        if (package != null) {
          // Fast: launch by package name using am start
          await LadbService.execute(
              'am start -a android.intent.action.MAIN '
              '-c android.intent.category.LAUNCHER '
              '-n \$(cmd package resolve-activity --brief $package | tail -1)');
          // Fallback if resolve fails: use monkey
          await LadbService.execute(
              'monkey -p $package -c android.intent.category.LAUNCHER 1');
          logService.log('  → launch $appName ($package)');
        } else {
          // Unknown app name — try monkey with app name as package
          await LadbService.execute(
              'monkey -p $appName -c android.intent.category.LAUNCHER 1');
          logService.log('  → launch (unknown) $appName');
        }
        break;

      case ActionType.wait:
        final ms = p['duration'] as int? ?? 2000;
        logService.log('  → wait ${ms}ms');
        await Future.delayed(Duration(milliseconds: ms));
        break;

      case ActionType.finish:
      case ActionType.unknown:
        break;
    }
  }
}
