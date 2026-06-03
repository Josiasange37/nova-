import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:nova/services/agent_service.dart';
import 'package:nova/services/ladb_service.dart';
import 'package:nova/services/log_service.dart';
import 'package:nova/ui/avatar_widget.dart';
import 'package:nova/ui/log_view.dart';
import 'package:nova/ui/setup_screen.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
  int _currentTab = 0;

  // Speech to text integration
  late stt.SpeechToText _speech;
  bool _speechAvailable = false;
  bool _isListening = false;
  String _wordsSpoken = '';

  @override
  void initState() {
    super.initState();
    _agent = AgentService(context.read<LogService>());
    _checkConnection();
    _initSpeech();
  }

  Future<void> _checkConnection() async {
    final ok = await LadbService.isConnected();
    if (mounted) setState(() => _isConnected = ok);
  }

  Future<void> _initSpeech() async {
    try {
      _speech = stt.SpeechToText();
      final hasSpeech = await _speech.initialize(
        onError: (e) {
          debugPrint('Speech error: $e');
          if (mounted) {
            setState(() {
              _isListening = false;
            });
            _agent.stateNotifier.value = AvatarState.idle;
          }
        },
        onStatus: (s) {
          debugPrint('Speech status: $s');
          if (s == 'notListening' && mounted) {
            setState(() {
              _isListening = false;
            });
            _agent.stateNotifier.value = AvatarState.idle;
          }
        },
      );
      if (mounted) {
        setState(() {
          _speechAvailable = hasSpeech;
        });
      }
    } catch (e) {
      debugPrint('Speech init failed: $e');
    }
  }

  void _startListening() async {
    if (_isRunning) return;
    if (!_speechAvailable) {
      context.read<LogService>().log('⚠ Voice recognition not available or permission denied.');
      return;
    }
    _wordsSpoken = '';
    setState(() {
      _isListening = true;
    });
    _agent.stateNotifier.value = AvatarState.listening;

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _wordsSpoken = result.recognizedWords;
          if (_wordsSpoken.isNotEmpty) {
            _ctrl.text = _wordsSpoken;
          }
        });
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
    );
  }

  void _stopListening() async {
    if (!_isListening) return;
    setState(() {
      _isListening = false;
    });
    await _speech.stop();
    _agent.stateNotifier.value = AvatarState.idle;

    if (_wordsSpoken.trim().isNotEmpty) {
      _ctrl.text = _wordsSpoken;
      _run();
    }
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
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF388BFD), Color(0xFF8B5CF6)],
                ),
              ),
              child: const Center(
                child: Text(
                  'N',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Nova',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
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
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: _isConnected ? const Color(0xFF3FB950) : const Color(0xFFFF7B72),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isConnected ? 'ADB' : 'Setup',
                    style: TextStyle(
                      color: _isConnected ? const Color(0xFF3FB950) : const Color(0xFFFF7B72),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_currentTab == 1) ...[
            IconButton(
              icon: const Icon(Icons.copy_all_outlined, color: Color(0xFF8B949E)),
              onPressed: () {
                final allLogs = context.read<LogService>().entries.map((e) => '[${e.timeStr}] ${e.message}').join('\n');
                Clipboard.setData(ClipboardData(text: allLogs));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Logs copied to clipboard'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              tooltip: 'Copy all logs',
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFF8B949E)),
              onPressed: () => context.read<LogService>().clear(),
              tooltip: 'Clear logs',
            ),
          ],
        ],
      ),
      body: IndexedStack(
        index: _currentTab,
        children: [
          _buildAssistantTab(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: LogView(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (index) {
          setState(() {
            _currentTab = index;
          });
        },
        backgroundColor: const Color(0xFF161B22),
        selectedItemColor: const Color(0xFF388BFD),
        unselectedItemColor: const Color(0xFF8B949E),
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.face_retouching_natural_outlined),
            activeIcon: Icon(Icons.face_retouching_natural_rounded),
            label: 'Assistant',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.terminal_outlined),
            activeIcon: Icon(Icons.terminal_rounded),
            label: 'Logs',
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantTab() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            // Center Avatar
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: AvatarWidget(
                    stateNotifier: _agent.stateNotifier,
                  ),
                ),
              ),
            ),

            // Dynamic Subtitle Status Text
            ValueListenableBuilder<AvatarState>(
              valueListenable: _agent.stateNotifier,
              builder: (context, state, child) {
                String status = 'Nova is ready';
                Color color = const Color(0xFF8B949E);
                switch (state) {
                  case AvatarState.idle:
                    status = 'Nova is ready';
                    color = const Color(0xFF8B949E);
                    break;
                  case AvatarState.listening:
                    status = _wordsSpoken.isNotEmpty ? _wordsSpoken : 'Listening to you...';
                    color = const Color(0xFF3FB950);
                    break;
                  case AvatarState.thinking:
                    status = 'Thinking...';
                    color = const Color(0xFF79C0FF);
                    break;
                  case AvatarState.talking:
                    status = 'Executing action...';
                    color = const Color(0xFFE3B341);
                    break;
                }
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      fontFamily: state == AvatarState.listening ? null : 'monospace',
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),

            const SizedBox(height: 8),

            // Combined Text + Microphone Input
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFF30363D)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      enabled: !_isRunning,
                      style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'What should Nova do?',
                        hintStyle: TextStyle(color: Color(0xFF6E7681)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      onSubmitted: (_) => _run(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isRunning
                        ? IconButton(
                            key: const ValueKey('stop'),
                            icon: const Icon(
                              Icons.stop_circle_rounded,
                              color: Color(0xFFFF7B72),
                              size: 32,
                            ),
                            onPressed: _stop,
                            tooltip: 'Stop Agent',
                          )
                        : ValueListenableBuilder<TextEditingValue>(
                            key: const ValueKey('inputs'),
                            valueListenable: _ctrl,
                            builder: (context, value, child) {
                              final textIsEmpty = value.text.trim().isEmpty;
                              if (textIsEmpty) {
                                return GestureDetector(
                                  onLongPressStart: (_) => _startListening(),
                                  onLongPressEnd: (_) => _stopListening(),
                                  onLongPressCancel: () => _stopListening(),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _isListening
                                          ? const Color(0xFF2EA043)
                                          : const Color(0xFF388BFD),
                                      boxShadow: _isListening
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF2EA043).withOpacity(0.4),
                                                blurRadius: 12,
                                                spreadRadius: 4,
                                              )
                                            ]
                                          : [],
                                    ),
                                    child: Icon(
                                      _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                );
                              } else {
                                return IconButton(
                                  icon: const Icon(
                                    Icons.send_rounded,
                                    color: Color(0xFF388BFD),
                                    size: 28,
                                  ),
                                  onPressed: _run,
                                  tooltip: 'Run Task',
                                );
                              }
                            },
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
