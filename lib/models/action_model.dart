/// Parses actions from the BigModel autoglm-phone model response format.
/// The model returns strings like:
///   do(action="Tap", element=[500, 300])
///   do(action="Swipe", start=[500,800], end=[500,200], duration=1000)
///   do(action="Type", text="hello world")
///   do(action="Press", key="home")
///   do(action="Launch", app="com.android.settings")
///   finish(message="Task completed successfully")

import 'dart:convert';

enum ActionType { tap, swipe, type, press, launch, wait, finish, unknown }

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

  /// Parse a model response (thinking + full content) into an ActionModel.
  factory ActionModel.fromResponse(String thinking, String content) {
    // 1. Search for do(...) or finish(...) in the content
    final doMatch = RegExp(r'(do\(action=.*?\))', dotAll: true).firstMatch(content);
    final finishMatch = RegExp(r'(finish\(message=.*?\))', dotAll: true).firstMatch(content);

    String actionStr = "";
    if (doMatch != null) {
      actionStr = doMatch.group(1)!;
    } else if (finishMatch != null) {
      actionStr = finishMatch.group(1)!;
    } else {
      // Fallback
      if (content.trim().startsWith('do(')) actionStr = content.trim();
      else if (content.trim().startsWith('finish(')) actionStr = content.trim();
      else {
        return ActionModel(
          action: ActionType.unknown,
          params: {},
          thinking: thinking,
          rawAction: content,
        );
      }
    }

    if (actionStr.startsWith('finish')) {
      final msg = _extractStringParam(actionStr, 'message') ?? actionStr;
      return ActionModel(
        action: ActionType.finish,
        params: {'message': msg},
        thinking: thinking,
        rawAction: actionStr,
      );
    }

    final actionName = _extractStringParam(actionStr, 'action') ?? '';
    final type = _parseActionType(actionName);
    final params = <String, dynamic>{};

    final element = _extractListParam(actionStr, 'element');
    final coordinate = _extractListParam(actionStr, 'coordinate');
    final start = _extractListParam(actionStr, 'start');
    final end = _extractListParam(actionStr, 'end');

    if (element != null) params['coordinate'] = element;
    else if (coordinate != null) params['coordinate'] = coordinate;
    
    if (start != null) params['start'] = start;
    if (end != null) params['end'] = end;

    final text = _extractStringParam(actionStr, 'text');
    if (text != null) params['text'] = text;

    final key = _extractStringParam(actionStr, 'key');
    if (key != null) params['key'] = key;

    final app = _extractStringParam(actionStr, 'app');
    if (app != null) params['app'] = app;

    final durMatch = RegExp('duration=["\']?(\\d+)').firstMatch(actionStr);
    if (durMatch != null) {
      params['duration'] = int.tryParse(durMatch.group(1) ?? '1000') ?? 1000;
    }

    return ActionModel(
      action: type,
      params: params,
      thinking: thinking,
      rawAction: actionStr,
    );
  }

  static ActionType _parseActionType(String name) {
    switch (name.toLowerCase()) {
      case 'tap': return ActionType.tap;
      case 'swipe': return ActionType.swipe;
      case 'type':
      case 'type_name': return ActionType.type;
      case 'press':
      case 'back':
      case 'home': return ActionType.press;
      case 'launch': return ActionType.launch;
      case 'wait': return ActionType.wait;
      case 'finish': return ActionType.finish;
      default: return ActionType.unknown;
    }
  }

  static String? _extractStringParam(String s, String key) {
    // Escape the single quote by using double quotes for the regex literal
    final re = RegExp('$key=["\']([^"\']*)["\']', caseSensitive: false);
    return re.firstMatch(s)?.group(1);
  }

  static List<double>? _extractListParam(String s, String key) {
    final re = RegExp('$key=\\[([\\d.,\\s]+)\\]', caseSensitive: false);
    final match = re.firstMatch(s);
    if (match == null) return null;
    return match.group(1)!
        .split(',')
        .map((e) => double.tryParse(e.trim()) ?? 0.0)
        .toList();
  }
}
