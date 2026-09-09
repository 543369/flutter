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
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff246957)),
          scaffoldBackgroundColor: const Color(0xfff6f7f2),
          useMaterial3: true,
          inputDecorationTheme:
              const InputDecorationTheme(border: OutlineInputBorder()),
        ),
        home: CareHome(
            api: api,
            reminders: widget.reminders,
            onLocale: (value) => setState(() => locale = value)),
      );
}
