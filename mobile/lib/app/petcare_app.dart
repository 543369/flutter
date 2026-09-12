import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/network/care_api.dart';
import '../features/care/reminder_service.dart';
import 'home_shell.dart';

class PetCareApp extends StatefulWidget {
  const PetCareApp({super.key, this.api, this.reminders});
  final CareApi? api;
  final ReminderService? reminders;
  @override
  State<PetCareApp> createState() => _PetCareAppState();
}

class _PetCareAppState extends State<PetCareApp> {
  Locale? locale;
  late final CareApi api = widget.api ?? CareApi();
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'PetCare',
        locale: locale,
        supportedLocales: const [Locale('zh'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xff5b3b2e),
            primary: const Color(0xff5b3b2e),
            secondary: const Color(0xffd95e32),
            surface: const Color(0xfffffdf9),
          ),
          scaffoldBackgroundColor: const Color(0xfffffdf9),
          useMaterial3: true,
          fontFamily: 'SF Pro Display',
          appBarTheme: const AppBarTheme(
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            backgroundColor: Color(0xfffffdf9),
            foregroundColor: Color(0xff33241f),
            titleTextStyle: TextStyle(
                fontFamily: 'SF Pro Display',
                color: Color(0xff33241f),
                fontSize: 22,
                fontWeight: FontWeight.w700),
          ),
          textTheme: const TextTheme(
            headlineLarge: TextStyle(
                fontSize: 34,
                height: 1.12,
                fontWeight: FontWeight.w800,
                color: Color(0xff33241f)),
            headlineMedium: TextStyle(
                fontSize: 27,
                height: 1.18,
                fontWeight: FontWeight.w700,
                color: Color(0xff33241f)),
            titleLarge: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xff33241f)),
            titleMedium: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xff33241f)),
            bodyLarge:
                TextStyle(fontSize: 16, height: 1.45, color: Color(0xff4b3a33)),
            bodyMedium:
                TextStyle(fontSize: 14, height: 1.4, color: Color(0xff6f625c)),
          ),
          cardTheme: CardThemeData(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            color: const Color(0xfffaf1e7),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xfffaf6f0),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xffeadfd5))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide:
                    const BorderSide(color: Color(0xff8d604c), width: 1.5)),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: const Color(0xff5b3b2e),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              textStyle:
                  const TextStyle(fontFamily: 'SF Pro Display', fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: const Color(0xff5b3b2e),
              side: const BorderSide(color: Color(0xffd8c8bb)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: const Color(0xfffffdf9),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
          navigationBarTheme: NavigationBarThemeData(
            height: 72,
            backgroundColor: const Color(0xfffffdf9),
            indicatorColor: const Color(0xfff0e5dc),
            elevation: 1,
            labelTextStyle: WidgetStateProperty.resolveWith((states) =>
                TextStyle(
                    color: states.contains(WidgetState.selected)
                        ? const Color(0xff4d3127)
                        : const Color(0xff8e817a),
                    fontWeight: states.contains(WidgetState.selected)
                        ? FontWeight.w700
                        : FontWeight.w500)),
          ),
        ),
        home: CareHome(
            api: api,
            reminders: widget.reminders,
            onLocale: (value) => setState(() => locale = value)),
      );
}
