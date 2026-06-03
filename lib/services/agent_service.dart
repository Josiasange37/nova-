import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:nova/models/action_model.dart';
import 'package:nova/services/ladb_service.dart';
import 'package:nova/services/log_service.dart';
import 'package:nova/services/screenshot_service.dart';
import 'package:nova/services/settings_service.dart';

enum AvatarState { idle, listening, thinking, talking }


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
  final ValueNotifier<AvatarState> stateNotifier = ValueNotifier<AvatarState>(AvatarState.idle);
  final FlutterTts _tts = FlutterTts();

  AgentService(this.logService);

  bool get isRunning => _isRunning;

  void stop() {
    _isRunning = false;
    stateNotifier.value = AvatarState.idle;
    _stopSpeak();
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.setLanguage("en-US");
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.55);
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS speak failed: $e');
    }
  }

  Future<void> _stopSpeak() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('TTS stop failed: $e');
    }
  }

  Future<void> runTask(String instruction) async {
    if (_isRunning) return;
    _isRunning = true;
    _context.clear();
    stateNotifier.value = AvatarState.thinking;

    logService.log('▶ Starting task: "$instruction"');

    final lowercaseInstruction = instruction.toLowerCase().trim();
    final isGreeting = _checkIsGreeting(lowercaseInstruction);
    final adbConnected = await LadbService.isConnected();

    if (isGreeting || !adbConnected) {
      if (!adbConnected) {
        logService.log('ℹ ADB not connected. Running in Conversational Chat mode.');
      } else {
        logService.log('ℹ Casual greeting/question detected. Running in Conversational Chat mode.');
      }
      await _runTextChat(instruction);
      return;
    }

    _context.add({'role': 'system', 'content': _systemPrompt});

    int step = 0;
    const int maxSteps = 20;

    try {
      while (_isRunning && step < maxSteps) {
        step++;
        logService.log('── Step $step/$maxSteps ──');
        stateNotifier.value = AvatarState.thinking;

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
        if (!_isRunning) break;
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
          final msg = action.params['message'] as String? ?? 'Task completed';
          logService.log('✅ Done: $msg');
          if (_isRunning) {
            _speak(msg);
            stateNotifier.value = AvatarState.talking;
            final durationMs = min(msg.length * 60, 4000);
            await Future.delayed(Duration(milliseconds: durationMs));
          }
          break;
        }

        if (action.action == ActionType.unknown) {
          logService.log('⚠ Could not parse action: "$rawAction"');
        } else {
          if (!_isRunning) break;
          if (action.action != ActionType.wait) {
            stateNotifier.value = AvatarState.talking;
          }
          await _executeAction(action);
        }

        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (step >= maxSteps) logService.log('⚠ Max steps reached.');
    } catch (e) {
      logService.log('💥 Error: $e');
    } finally {
      _isRunning = false;
      stateNotifier.value = AvatarState.idle;
      logService.log('■ Agent stopped.');
    }
  }

  Future<(String, String?)> _callBigModel() async {
    final apiKey = SettingsService.getApiKey();
    if (apiKey.isEmpty || apiKey == SettingsService.defaultApiKey) {
      logService.log('❌ Error: No API key configured. Open Setup to set it.');
      return ('', null);
    }

    int retryCount = 0;
    const int maxRetries = 2;

    while (true) {
      final client = http.Client();
      try {
        final response = await client.post(
          Uri.parse(_bigModelUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
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
        client.close();
        if (retryCount < maxRetries && _isRunning) {
          retryCount++;
          logService.log('⚠ Network error: $e. Retrying in 1.5 seconds (Attempt $retryCount/$maxRetries)...');
          await Future.delayed(const Duration(milliseconds: 1500));
          continue;
        }
        logService.log('⚠ Network error: $e');
        return ('', null);
      } finally {
        client.close();
      }
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
        await _launchApp(appName);
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

  bool _checkIsGreeting(String text) {
    final greetings = [
      'hello', 'hi', 'hey', 'yo', 'halo', 'greetings',
      'how are you', 'how is it going', 'who are you', 'what is your name',
      'whats up', 'what\'s up', 'good morning', 'good afternoon', 'good evening',
      'help', 'test'
    ];
    return greetings.any((g) => text.startsWith(g) || text == g);
  }

  Future<void> _runTextChat(String instruction) async {
    try {
      final apiKey = SettingsService.getApiKey();
      if (apiKey.isEmpty || apiKey == SettingsService.defaultApiKey) {
        logService.log('❌ Error: No API key configured. Open Setup to set it.');
        return;
      }

      logService.log('🧠 Consulting AI (Chat Mode)...');

      int retryCount = 0;
      const int maxRetries = 2;

      while (true) {
        final client = http.Client();
        try {
          final response = await client.post(
            Uri.parse(_bigModelUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': 'glm-4-flash',
              'messages': [
                {
                  'role': 'system',
                  'content': 'You are Nova, a helpful and friendly mobile AI assistant. Respond to the user\'s greeting or question in a brief, friendly, and helpful manner (max 2 sentences).'
                },
                {'role': 'user', 'content': instruction}
              ],
              'max_tokens': 256,
              'temperature': 0.7,
            }),
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode == 200) {
            if (!_isRunning) return;
            final data = jsonDecode(response.body);
            final content = data['choices'][0]['message']['content'] as String? ?? '';
            logService.log('💭 Nova: $content');

            if (_isRunning) {
              _speak(content);
              // Transition to talking state to animate mouth
              stateNotifier.value = AvatarState.talking;

              // Simulating speech time based on response length (e.g. 60ms per character, max 5s)
              final durationMs = min(content.length * 60, 5000);
              await Future.delayed(Duration(milliseconds: durationMs));
            }
            break;
          } else {
            logService.log('⚠ Chat API Error ${response.statusCode}: ${response.body}');
            break;
          }
        } catch (e) {
          client.close();
          if (retryCount < maxRetries && _isRunning) {
            retryCount++;
            logService.log('⚠ Network error in Chat Mode: $e. Retrying (Attempt $retryCount/$maxRetries)...');
            await Future.delayed(const Duration(milliseconds: 1500));
            continue;
          }
          logService.log('⚠ Network error in Chat Mode: $e');
          break;
        } finally {
          client.close();
        }
      }
    } catch (e) {
      logService.log('⚠ Error in Chat Mode: $e');
    } finally {
      _isRunning = false;
      stateNotifier.value = AvatarState.idle;
      logService.log('■ Agent stopped.');
  }

  Future<void> _launchApp(String appName) async {
    final lowerAppName = appName.toLowerCase().trim();

    // 1. Check for system standard apps that have universal intents
    if (lowerAppName == 'camera') {
      await LadbService.execute('am start -a android.media.action.STILL_IMAGE_CAMERA');
      logService.log('  → launch Camera via STILL_IMAGE_CAMERA intent');
      return;
    } else if (lowerAppName == 'settings') {
      await LadbService.execute('am start -a android.settings.SETTINGS');
      logService.log('  → launch Settings via settings intent');
      return;
    }

    // 2. Resolve package from our static database first
    String? package = _resolvePackage(appName);

    // 3. Fallback: query all installed packages on the device to find a match
    if (package == null || package == appName) {
      logService.log('🔍 Looking up package for "$appName" on the device...');
      final devicePkg = await _findPackageOnDevice(appName);
      if (devicePkg != null) {
        package = devicePkg;
        logService.log('  → Found installed package: $package');
      }
    }

    // 4. Fallback for camera/settings in case the intent didn't fire (just in case)
    if (package == null) {
      if (lowerAppName.contains('camera')) {
        package = await _findPackageOnDevice('camera');
      } else if (lowerAppName.contains('setting')) {
        package = await _findPackageOnDevice('setting');
      }
    }

    final targetPackage = package ?? appName;

    // 5. Try launching using resolve-activity
    final resolveOut = await LadbService.execute(
        'cmd package resolve-activity --brief $targetPackage');
    if (resolveOut.isNotEmpty &&
        !resolveOut.contains('Error') &&
        !resolveOut.contains('No activity')) {
      final activity = resolveOut.split('\n').last.trim();
      if (activity.isNotEmpty && activity.contains('/')) {
        await LadbService.execute('am start -n $activity');
        logService.log('  → launch $appName ($targetPackage) via activity: $activity');
        return;
      }
    }

    // 6. Fallback: use monkey
    await LadbService.execute(
        'monkey -p $targetPackage -c android.intent.category.LAUNCHER 1');
    logService.log('  → launch $appName ($targetPackage) via monkey');
  }

  Future<String?> _findPackageOnDevice(String keyword) async {
    try {
      final lowerKeyword = keyword.toLowerCase().trim();
      final out = await LadbService.execute('pm list packages');
      if (out.isEmpty || out.contains('Error')) return null;

      final lines = out.split('\n');
      // Look for exact ending or last path component matching keyword
      for (var line in lines) {
        if (line.contains('package:')) {
          final pkg = line.replaceAll('package:', '').trim();
          final parts = pkg.split('.');
          if (parts.isNotEmpty && parts.last.toLowerCase() == lowerKeyword) {
            return pkg;
          }
        }
      }
      // Look for suffix matching
      for (var line in lines) {
        if (line.contains('package:')) {
          final pkg = line.replaceAll('package:', '').trim();
          if (pkg.toLowerCase().endsWith('.$lowerKeyword')) {
            return pkg;
          }
        }
      }
      // Look for substring match anywhere in the package name
      for (var line in lines) {
        if (line.contains('package:')) {
          final pkg = line.replaceAll('package:', '').trim();
          if (pkg.toLowerCase().contains(lowerKeyword)) {
            return pkg;
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to query device packages: $e');
    }
    return null;
  }
}
