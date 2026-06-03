import 'package:flutter/material.dart';
import 'package:nova/services/ladb_service.dart';
import 'package:nova/services/settings_service.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _pairPortCtrl = TextEditingController();
  final _pairCodeCtrl = TextEditingController();
  final _connectPortCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();

  String _status = '';
  bool _loading = false;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _apiKeyCtrl.text = SettingsService.getApiKey();
    _connectPortCtrl.text = SettingsService.getConnectedPort();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final ok = await LadbService.isConnected();
    if (mounted) setState(() => _connected = ok);
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyCtrl.text.trim();
    if (key.isEmpty) {
      if (mounted) setState(() => _status = '❌ API key cannot be empty.');
      return;
    }

    if (key.contains('[') || key.contains(']') || key.contains('\n') || key.contains(' ')) {
      if (mounted) {
        setState(() => _status = '❌ Invalid format: Key contains logs, brackets, or spaces.\nPlease paste only the raw API key (e.g. id.secret).');
      }
      return;
    }

    // BigModel/Zhipu API keys are formatted as: identifier.secret
    final regExp = RegExp(r'^[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+$');
    if (!regExp.hasMatch(key)) {
      if (mounted) {
        setState(() => _status = '❌ Invalid key format. Expected "id.secret" format.');
      }
      return;
    }

    await SettingsService.setApiKey(key);
    if (mounted) setState(() => _status = '✓ API key saved');
  }

  Future<void> _startServer() async {
    setState(() { _loading = true; _status = 'Starting ADB server...'; });
    final out = await LadbService.execute('start-server');
    setState(() { _loading = false; _status = 'Server: $out'; });
  }

  Future<void> _pair() async {
    final port = _pairPortCtrl.text.trim();
    final code = _pairCodeCtrl.text.trim();
    if (port.isEmpty || code.isEmpty) {
      setState(() => _status = 'Enter pairing port and code.');
      return;
    }
    setState(() { _loading = true; _status = 'Pairing...'; });
    final out = await LadbService.pair(port, code);
    setState(() { _loading = false; _status = 'Pair result: $out'; });
  }

  Future<void> _connect() async {
    final port = _connectPortCtrl.text.trim();
    if (port.isEmpty) {
      setState(() => _status = 'Enter the ADB port.');
      return;
    }
    setState(() { _loading = true; _status = 'Connecting...'; });
    final out = await LadbService.connect(port);
    await SettingsService.setConnectedPort(port);
    await Future.delayed(const Duration(milliseconds: 500));
    final ok = await LadbService.isConnected();
    setState(() {
      _loading = false;
      _connected = ok;
      _status = ok ? '✅ Connected!' : 'Result: $out';
    });
    if (ok && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Setup'),
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionHeader('🔑 BigModel API Key'),
              const SizedBox(height: 8),
              _darkField(_apiKeyCtrl, 'API Key', obscure: true),
              const SizedBox(height: 8),
              _actionButton('Save API Key', _saveApiKey),

              const SizedBox(height: 24),
              _sectionHeader('🔋 Background Optimization'),
              const SizedBox(height: 8),
              const Text(
                'To prevent the OS from killing Nova or aborting network requests when it goes to the background, please set Nova to "Unrestricted" / "Don\'t optimize" in Battery settings.',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
              ),
              const SizedBox(height: 8),
              _actionButton('Open Battery Settings', () => LadbService.openBatterySettings()),

              const SizedBox(height: 28),
              _sectionHeader('📡 ADB Connection'),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.circle, size: 10,
                    color: Color(0xFF3FB950)),
                  const SizedBox(width: 6),
                  Text(
                    _connected ? 'Connected' : 'Not connected',
                    style: TextStyle(
                      color: _connected ? const Color(0xFF3FB950) : const Color(0xFFFF7B72),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F2B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Step 1: In Developer Options → Wireless Debugging,\ntap "Pair device with pairing code". You will see:',
                      style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
                    SizedBox(height: 8),
                    Text('   Code: 844172  ← big number (6 digits)',
                      style: TextStyle(color: Color(0xFF79C0FF), fontSize: 12, fontFamily: 'monospace')),
                    Text('   IP & Port: 172.x.x.x:39217',
                      style: TextStyle(color: Color(0xFFE3B341), fontSize: 12, fontFamily: 'monospace')),
                    SizedBox(height: 4),
                    Text('   Port = number AFTER the colon (:)',
                      style: TextStyle(color: Color(0xFFE3B341), fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _darkField(_pairPortCtrl, 'Port (number AFTER ":" e.g. 39217)', keyboard: TextInputType.number),
              const SizedBox(height: 8),
              _darkField(_pairCodeCtrl, 'Pairing Code (6-digit number e.g. 844172)', keyboard: TextInputType.number),
              const SizedBox(height: 8),
              _actionButton('Pair Device', _pair),

              const SizedBox(height: 20),
              const Text('Step 2: After pairing succeeds, go BACK to the\nWireless Debugging main screen. Use the port shown there\n(different from the pairing port!).',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
              const SizedBox(height: 12),
              _darkField(_connectPortCtrl, 'Connection Port (from main WD screen)', keyboard: TextInputType.number),
              const SizedBox(height: 8),
              _actionButton('Connect', _connect),

              if (_status.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: Text(_status,
                    style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 13, fontFamily: 'monospace')),
                ),
              ],

              if (_loading) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(color: Color(0xFF79C0FF)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Text(title,
    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold));

  Widget _darkField(TextEditingController ctrl, String hint, {
    TextInputType keyboard = TextInputType.text, bool obscure = false,
  }) => TextField(
    controller: ctrl,
    obscureText: obscure,
    keyboardType: keyboard,
    style: const TextStyle(color: Color(0xFFE6EDF3)),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF6E7681)),
      filled: true,
      fillColor: const Color(0xFF161B22),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF30363D)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF30363D)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF388BFD)),
      ),
    ),
  );

  Widget _actionButton(String label, VoidCallback? onTap) => ElevatedButton(
    onPressed: _loading ? null : onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF238636),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(vertical: 14),
    ),
    child: Text(label),
  );
}
