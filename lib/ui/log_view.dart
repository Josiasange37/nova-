import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nova/services/log_service.dart';

class LogView extends StatefulWidget {
  const LogView({super.key});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  final ScrollController _scroll = ScrollController();

  @override
  Widget build(BuildContext context) {
    final logs = context.watch<LogService>().entries;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      padding: const EdgeInsets.all(10),
      child: logs.isEmpty
          ? const Center(
              child: Text(
                'Agent logs will appear here...',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
              ),
            )
          : ListView.builder(
              controller: _scroll,
              itemCount: logs.length,
              itemBuilder: (ctx, i) {
                final entry = logs[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.timeStr,
                        style: const TextStyle(color: Color(0xFF6E7681), fontSize: 11, fontFamily: 'monospace'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.message,
                          style: TextStyle(
                            color: _colorForMessage(entry.message),
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Color _colorForMessage(String msg) {
    if (msg.startsWith('❌') || msg.startsWith('💥')) return const Color(0xFFFF7B72);
    if (msg.startsWith('✅') || msg.startsWith('▶')) return const Color(0xFF3FB950);
    if (msg.startsWith('🧠') || msg.startsWith('💭')) return const Color(0xFF79C0FF);
    if (msg.startsWith('🎯') || msg.startsWith('  →')) return const Color(0xFFE3B341);
    if (msg.startsWith('⚠')) return const Color(0xFFD29922);
    return const Color(0xFFE6EDF3);
  }
}
