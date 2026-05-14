/// Parses actions from the BigModel autoglm-phone model response format.
/// The model returns strings like:
///   do(action="tap", coordinate=[0.5, 0.3])
///   do(action="swipe", coordinate=[0.5,0.8,0.5,0.2], duration=1000)
///   do(action="type", text="hello world")
///   do(action="press", key="home")
///   do(action="launch", app="com.android.settings")
///   finish(message="Task completed successfully")

enum ActionType { tap, swipe, type, press, launch, finish, unknown }

class ActionModel {
  final ActionType action;
  final Map<String, dynamic> params;
  final String thinking;
  final String rawAction;

  ActionModel({
    required this.action,
    required this.params,
    required this.thinking,
    required this.rawAction,
  });

  /// Parse a model response (thinking + action string) into an ActionModel.
  factory ActionModel.fromResponse(String thinking, String rawAction) {
    final a = rawAction.trim();

    if (a.startsWith('finish(')) {
      final msg = _extractStringParam(a, 'message') ?? a;
      return ActionModel(
        action: ActionType.finish,
        params: {'message': msg},
        thinking: thinking,
        rawAction: rawAction,
      );
    }

    if (a.startsWith('do(')) {
      // Extract action name
      final actionName = _extractStringParam(a, 'action') ?? '';
      final type = _parseActionType(actionName);

      final params = <String, dynamic>{};

      // Extract coordinate (list of floats)
      final coordRaw = _extractListParam(a, 'coordinate');
      if (coordRaw != null && coordRaw.isNotEmpty) {
        params['coordinate'] = coordRaw;
      }

      // Extract text
      final text = _extractStringParam(a, 'text');
      if (text != null) params['text'] = text;

      // Extract key
      final key = _extractStringParam(a, 'key');
      if (key != null) params['key'] = key;

      // Extract app
      final app = _extractStringParam(a, 'app');
      if (app != null) params['app'] = app;

      // Extract duration
      final durMatch = RegExp(r'duration=(\d+)').firstMatch(a);
      if (durMatch != null) params['duration'] = int.parse(durMatch.group(1)!);

      return ActionModel(
        action: type,
        params: params,
        thinking: thinking,
        rawAction: rawAction,
      );
    }

    // Unknown / unparseable
    return ActionModel(
      action: ActionType.unknown,
      params: {},
      thinking: thinking,
      rawAction: rawAction,
    );
  }

  static ActionType _parseActionType(String name) {
    switch (name.toLowerCase()) {
      case 'tap': return ActionType.tap;
      case 'swipe': return ActionType.swipe;
      case 'type': return ActionType.type;
      case 'press': return ActionType.press;
      case 'launch': return ActionType.launch;
      case 'finish': return ActionType.finish;
      default: return ActionType.unknown;
    }
  }

  /// Extract a quoted string value: key="value" or key='value'
  static String? _extractStringParam(String s, String key) {
    final re = RegExp('$key=["\']([^"\']*)["\']');
    return re.firstMatch(s)?.group(1);
  }

  /// Extract a JSON list value: coordinate=[0.1, 0.2, 0.3, 0.4]
  static List<double>? _extractListParam(String s, String key) {
    final re = RegExp('$key=\\[([\\d.,\\s]+)\\]');
    final match = re.firstMatch(s);
    if (match == null) return null;
    return match.group(1)!
        .split(',')
        .map((e) => double.tryParse(e.trim()) ?? 0.0)
        .toList();
  }
}
