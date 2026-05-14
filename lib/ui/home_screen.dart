import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nova/services/agent_service.dart';
import 'package:nova/services/ladb_service.dart';
import 'package:nova/services/log_service.dart';
import 'package:nova/ui/log_view.dart';
import 'package:nova/ui/setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _ctrl = TextEditingController();
  late AgentService _agent;
  bool _isConnected = false;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _agent = AgentService(context.read<LogService>());
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final ok = await LadbService.isConnected();
    if (mounted) setState(() => _isConnected = ok);
  }

  Future<void> _run() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() => _isRunning = true);
    await _agent.runTask(_ctrl.text.trim());
    if (mounted) setState(() => _isRunning = false);
  }

  void _stop() {
    _agent.stop();
    setState(() => _isRunning = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF388BFD), Color(0xFF8B5CF6)],
                ),
              ),
              child: const Center(child: Text('N', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
            ),
            const SizedBox(width: 10),
            const Text('Nova', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        actions: [
          // Connection status indicator
          GestureDetector(
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SetupScreen()),
            ).then((_) => _checkConnection()),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _isConnected ? const Color(0xFF1A3A21) : const Color(0xFF3A1A1A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isConnected ? const Color(0xFF3FB950) : const Color(0xFFFF7B72),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8,
                    color: _isConnected ? const Color(0xFF3FB950) : const Color(0xFFFF7B72)),
                  const SizedBox(width: 5),
                  Text(
                    _isConnected ? 'ADB' : 'Setup',
                    style: TextStyle(
                      color: _isConnected ? const Color(0xFF3FB950) : const Color(0xFFFF7B72),
                      fontSize: 12, fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFF8B949E)),
            onPressed: () => context.read<LogService>().clear(),
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Input area
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _ctrl,
                      style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 15),
                      maxLines: 2,
                      minLines: 1,
                      enabled: !_isRunning,
                      decoration: const InputDecoration.collapsed(
                        hintText: 'What should Nova do? e.g. "Open the calculator"',
                        hintStyle: TextStyle(color: Color(0xFF6E7681)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _isRunning
                              ? ElevatedButton.icon(
                                  key: const ValueKey('stop'),
                                  onPressed: _stop,
                                  icon: const Icon(Icons.stop_circle_outlined),
                                  label: const Text('Stop Agent'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6E0F0F),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                )
                              : ElevatedButton.icon(
                                  key: const ValueKey('run'),
                                  onPressed: _run,
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: const Text('Run Task'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF238636),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Log terminal
              Expanded(child: const LogView()),
            ],
          ),
        ),
      ),
    );
  }
}
