import 'package:flutter/material.dart';
import 'package:nova/services/log_service.dart';
import 'package:nova/services/settings_service.dart';
import 'package:nova/ui/home_screen.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LogService()),
      ],
      child: const NovaApp(),
    ),
  );
}

class NovaApp extends StatelessWidget {
  const NovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nova AI Agent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF388BFD),
          surface: const Color(0xFF161B22),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
