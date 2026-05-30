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

// System prompt strictly aligned with Open-AutoGLM's expected model behavior
const String _systemPrompt = '''You are Nova, a professional Android AI agent. 
Your goal is to execute the user's task using ADB commands.
You see a screenshot of the current screen with dimensions. 

Rules:
1. Analyze the screen and output EXACTLY ONE action.
2. IMPORTANT: If you see the "Nova" app or terminal logs on the screen, ignore them. Focus on the background apps or the task.
3. Be extremely concise in your thinking.
4. Output format:
   - do(action="Tap", element=[x, y])
   - do(action="Swipe", start=[x1, y1], end=[x2, y2], duration=500)
   - do(action="Type", text="text content")
   - do(action="Press", key="home"|"back"|"enter"|"recent")
   - do(action="Launch", app="package.name")
   - do(action="Wait", duration=2000)
   - finish(message="done")

Coordinates: [0-1000] (0 is top/left, 1000 is bottom/right). Respond ONLY in English.''';

class AgentService {
  final LogService logService;
  bool _isRunning = false;

  // Reading the coordinate context
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

        logService.log('📷 Capturing screen...');
        final screenshotB64 = await ScreenshotService.captureAsBase64();
        if (screenshotB64 == null || screenshotB64.isEmpty) {
          logService.log('❌ Failed to capture screenshot.');
          break;
        }

        final String userText = step == 1
            ? instruction
            : '** Continuing task ** Current screen state shown.';

        _context.add({
          'role': 'user',
          'content': [
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/png;base64,$screenshotB64'},
            },
            {'type': 'text', 'text': userText},
          ],
        });

        logService.log('🧠 Consulting BigModel AI...');
        final (thinking, rawAction) = await _callBigModel();
        if (rawAction == null) {
          logService.log('❌ No response from AI.');
          break;
        }

        if (thinking.isNotEmpty) logService.log('💭 $thinking');

        final action = ActionModel.fromResponse(thinking, rawAction);
        logService.log('🎯 Action: ${action.action.name}  ${action.params}');

        // Cleanup context to save tokens
        _context.last = {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': userText},
          ],
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

        await Future.delayed(const Duration(milliseconds: 1000));
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
        final content = data['choices'][0]['message']['content'] as String? ?? '';
        return _parseResponse(content);
      } else {
        logService.log('⚠ API Error ${response.statusCode}: ${response.body}');
        return ('', null);
      }
    } catch (e) {
      logService.log('⚠ Network/Auth error: $e');
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

      final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'sign_type': 'SIGN'}))).replaceAll('=', '');
      final payload = base64Url.encode(utf8.encode(jsonEncode({'api_key': id, 'exp': exp, 'timestamp': now}))).replaceAll('=', '');
      final signature = Hmac(sha256, utf8.encode(secret)).convert(utf8.encode('$header.$payload'));
      final signatureB64 = base64Url.encode(signature.bytes).replaceAll('=', '');

      return '$header.$payload.$signatureB64';
    } catch (e) { return apikey; }
  }

  (String, String?) _parseResponse(String content) {
    content = content.trim();
    if (content.contains('<answer>')) {
      final parts = content.split('<answer>');
      final thinking = parts[0].replaceAll('<think>', '').replaceAll('</think>', '').trim();
      final action = parts[1].replaceAll('</answer>', '').trim();
      return (thinking, action);
    }
    // Fallback: search for do( or finish(
    final markerMatch = RegExp(r'(do\(|finish\()', caseSensitive: false).firstMatch(content);
    if (markerMatch != null) {
      final idx = markerMatch.start;
      return (content.substring(0, idx).trim(), content.substring(idx).trim());
    }
    return ('', content);
  }

  Future<void> _executeAction(ActionModel action) async {
    final p = action.params;
    final sizeOut = await LadbService.execute('wm size');
    final m = RegExp(r'(\d+)x(\d+)').firstMatch(sizeOut);
    final w = double.tryParse(m?.group(1) ?? '1080') ?? 1080;
    final h = double.tryParse(m?.group(2) ?? '2400') ?? 2400;

    // Helper to scale coordinates (Open-AutoGLM uses 0-1000)
    int scaleX(double x) => (x > 1.0 ? (x / 1000.0 * w) : (x * w)).toInt();
    int scaleY(double y) => (y > 1.0 ? (y / 1000.0 * h) : (y * h)).toInt();

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
        final start = p['start'] as List<double>? ?? p['coordinate'] as List<double>?;
        final end = p['end'] as List<double>?;
        final dur = p['duration'] as int? ?? 500;
        if (start != null && end != null && start.length >= 2 && end.length >= 2) {
          final x1 = scaleX(start[0]);
          final y1 = scaleY(start[1]);
          final x2 = scaleX(end[0]);
          final y2 = scaleY(end[1]);
          await LadbService.execute('input swipe $x1 $y1 $x2 $y2 $dur');
          logService.log('  → swipe ($x1,$y1)→($x2,$y2)');
        }
        break;

      case ActionType.type:
        final text = (p['text'] as String? ?? '').replaceAll(' ', '%s');
        await LadbService.execute("input text '$text'");
        logService.log('  → type "${p['text']}"');
        break;

      case ActionType.press:
        final k = p['key']?.toString().toLowerCase() ?? 'home';
        final keyEvent = k == 'home' ? '3' : k == 'back' ? '4' : k == 'enter' ? '66' : '3';
        await LadbService.execute('input keyevent $keyEvent');
        logService.log('  → press $k');
        break;

      case ActionType.launch:
        final app = p['app'] as String? ?? '';
        await LadbService.execute('monkey -p $app -c android.intent.category.LAUNCHER 1');
        logService.log('  → launch $app');
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
