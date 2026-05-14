import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nova/models/action_model.dart';
import 'package:nova/services/ladb_service.dart';
import 'package:nova/services/log_service.dart';
import 'package:nova/services/screenshot_service.dart';
import 'package:nova/services/settings_service.dart';

const String _bigModelUrl =
    'https://open.bigmodel.cn/api/paas/v4/chat/completions';
const String _model = 'autoglm-phone';

// System prompt adapted from Open-AutoGLM
const String _systemPrompt = '''You are Nova, an AI agent that controls an Android phone on behalf of the user. 
You will be given a task and a screenshot of the current screen. 
Analyze the screen, think step by step, then output ONE action.

Output format (mandatory):
- To tap: do(action="tap", coordinate=[x, y])
- To swipe: do(action="swipe", coordinate=[x1, y1, x2, y2], duration=500)
- To type text: do(action="type", text="your text here")
- To press a key: do(action="press", key="home"|"back"|"enter"|"recent")
- To open an app: do(action="launch", app="package.name")
- When done: finish(message="description of what was accomplished")

Coordinates are normalized between 0.0 and 1.0 (relative to screen size).
x=0 is left, x=1 is right, y=0 is top, y=1 is bottom.
Always output ONLY the action line and nothing else after it.
Think carefully before acting. If the task is complete, call finish().
Respond in English only.''';

class AgentService {
  final LogService logService;
  bool _isRunning = false;

  // Conversation history (maintained across steps like Open-AutoGLM)
  final List<Map<String, dynamic>> _context = [];

  AgentService(this.logService);

  bool get isRunning => _isRunning;

  void stop() => _isRunning = false;

  Future<void> runTask(String instruction) async {
    if (_isRunning) return;
    _isRunning = true;
    _context.clear();

    logService.log('▶ Starting task: "$instruction"');

    // Check ADB connection
    if (!await LadbService.isConnected()) {
      logService.log('❌ ADB not connected. Open Settings to pair/connect first.');
      _isRunning = false;
      return;
    }

    // Build initial system message
    _context.add({'role': 'system', 'content': _systemPrompt});

    int step = 0;
    const int maxSteps = 20;

    try {
      while (_isRunning && step < maxSteps) {
        step++;
        logService.log('── Step $step/$maxSteps ──');

        // 1. Capture screenshot
        logService.log('📷 Capturing screen...');
        final screenshotB64 = await ScreenshotService.captureAsBase64();
        if (screenshotB64 == null || screenshotB64.isEmpty) {
          logService.log('❌ Failed to capture screenshot.');
          break;
        }

        // 2. Build user message for this step
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

        // 3. Call BigModel API
        logService.log('🧠 Consulting BigModel AI...');
        final (thinking, rawAction) = await _callBigModel();
        if (rawAction == null) {
          logService.log('❌ No response from AI.');
          break;
        }

        if (thinking.isNotEmpty) logService.log('💭 $thinking');

        // 4. Parse action
        final action = ActionModel.fromResponse(thinking, rawAction);
        logService.log('🎯 Action: ${action.action.name}  ${action.params}');

        // Add assistant response to context (without image to save tokens)
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

        // 5. Execute action
        if (action.action == ActionType.finish) {
          logService.log('✅ Done: ${action.params['message']}');
          break;
        }

        await _executeAction(action);

        // Small delay before next step
        await Future.delayed(const Duration(milliseconds: 1500));
      }

      if (step >= maxSteps) logService.log('⚠ Max steps reached.');
    } catch (e) {
      logService.log('💥 Error: $e');
    } finally {
      _isRunning = false;
      logService.log('■ Agent stopped.');
    }
  }

  /// Calls the BigModel API and returns (thinking, rawAction).
  Future<(String, String?)> _callBigModel() async {
    final apiKey = SettingsService.getApiKey();
    try {
      final response = await http.post(
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
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String? ?? '';
        return _parseResponse(content);
      } else {
        logService.log('⚠ API Error ${response.statusCode}: ${response.body}');
        return ('', null);
      }
    } catch (e) {
      logService.log('⚠ Network error: $e');
      return ('', null);
    }
  }

  /// Parses the model response into (thinking, actionString).
  (String, String?) _parseResponse(String content) {
    content = content.trim();

    // Format: <think>...</think><answer>...</answer>
    if (content.contains('<answer>')) {
      final parts = content.split('<answer>');
      final thinking = parts[0].replaceAll('<think>', '').replaceAll('</think>', '').trim();
      final action = parts[1].replaceAll('</answer>', '').trim();
      return (thinking, action);
    }

    // Format: thinking text ... do(action=...) or finish(...)
    for (final marker in ['do(action=', 'finish(message=', 'finish(']) {
      if (content.contains(marker)) {
        final idx = content.indexOf(marker);
        final thinking = content.substring(0, idx).trim();
        final action = content.substring(idx).trim();
        return (thinking, action);
      }
    }

    return ('', content);
  }

  /// Executes a parsed action via LADB.
  Future<void> _executeAction(ActionModel action) async {
    final p = action.params;

    // Get screen dimensions for coordinate conversion
    final sizeOut = await LadbService.execute('wm size');
    final m = RegExp(r'(\d+)x(\d+)').firstMatch(sizeOut);
    final w = double.tryParse(m?.group(1) ?? '1080') ?? 1080;
    final h = double.tryParse(m?.group(2) ?? '2400') ?? 2400;

    switch (action.action) {
      case ActionType.tap:
        final coord = p['coordinate'] as List<double>?;
        if (coord != null && coord.length >= 2) {
          final x = (coord[0] * w).toInt();
          final y = (coord[1] * h).toInt();
          await LadbService.execute('input tap $x $y');
          logService.log('  → tap ($x, $y)');
        }
        break;

      case ActionType.swipe:
        final coord = p['coordinate'] as List<double>?;
        final dur = p['duration'] as int? ?? 500;
        if (coord != null && coord.length >= 4) {
          final x1 = (coord[0] * w).toInt();
          final y1 = (coord[1] * h).toInt();
          final x2 = (coord[2] * w).toInt();
          final y2 = (coord[3] * h).toInt();
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
        final keyMap = {
          'home': '3', 'back': '4', 'enter': '66',
          'recent': '187', 'delete': '67',
        };
        final key = keyMap[p['key']] ?? '3';
        await LadbService.execute('input keyevent $key');
        logService.log('  → press ${p['key']}');
        break;

      case ActionType.launch:
        final app = p['app'] as String? ?? '';
        await LadbService.execute('monkey -p $app 1');
        logService.log('  → launch $app');
        break;

      case ActionType.finish:
      case ActionType.unknown:
        break;
    }
  }
}
