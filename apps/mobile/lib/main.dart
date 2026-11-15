import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'onboarding_api.dart';
import 'onboarding_screen.dart';
import 'theme.dart';

void main() {
  const apiUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );
  runApp(CactusFightApp(api: OnboardingApi(apiUrl)));
}

class CactusFightApp extends StatelessWidget {
  const CactusFightApp({super.key, required this.api});

  final OnboardingApi api;

  @override
  Widget build(BuildContext context) {
    const canvas = Color(0xff161823);
    const field = Color(0xff202231);
    const border = Color(0xff383b4d);
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: cactusAcid,
        brightness: Brightness.dark,
        primary: cactusAcid,
        onPrimary: const Color(0xff1c250b),
        surface: canvas,
        onSurface: const Color(0xfff4f4f8),
        onSurfaceVariant: const Color(0xffb4b8ca),
      ),
      scaffoldBackgroundColor: canvas,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: field,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      dividerColor: border,
    );
    return MaterialApp(
      title: 'Cactus Fight',
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: OnboardingScreen(api: api),
    );
  }
}
