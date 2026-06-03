import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nova/services/log_service.dart';
import 'package:nova/services/settings_service.dart';
import 'package:nova/main.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.init();
  });

  testWidgets('NovaApp loading smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LogService()),
        ],
        child: const NovaApp(),
      ),
    );

    // Verify that the title 'Nova' exists in the app bar.
    expect(find.text('Nova'), findsOneWidget);

    // Verify that the input text field for instructions is rendered.
    expect(find.byType(TextField), findsOneWidget);
  });
}
