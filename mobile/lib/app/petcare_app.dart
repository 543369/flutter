import '../core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/network/care_api.dart';
import '../features/care/reminder_service.dart';
import 'home_shell.dart';

class PetCareApp extends StatefulWidget {
  const PetCareApp({super.key, this.api, this.reminders, this.initialLocale});
  final CareApi? api;
  final ReminderService? reminders;
  final Locale? initialLocale;
  @override
  State<PetCareApp> createState() => _PetCareAppState();
}

class _PetCareAppState extends State<PetCareApp> {
  late Locale? locale = widget.initialLocale;
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
          ).copyWith(
            primaryContainer: const Color(0xffeee1d3),
            onPrimaryContainer: const Color(0xff4d3529),
            secondaryContainer: const Color(0xffeee1d3),
            onSecondaryContainer: const Color(0xff4d3529),
            surfaceContainerLowest: const Color(0xfffffdf9),
            surfaceContainerLow: const Color(0xfffaf6f0),
            surfaceContainer: const Color(0xfff5eee5),
            surfaceContainerHigh: const Color(0xffeee5da),
            surfaceContainerHighest: const Color(0xffe7dccf),
            onSurface: const Color(0xff33241f),
            onSurfaceVariant: const Color(0xff746459),
            outline: const Color(0xffa99584),
            outlineVariant: const Color(0xffe5d9cb),
          ),
          canvasColor: const Color(0xfffffdf9),
          focusColor: const Color(0x248d604c),
          hoverColor: const Color(0x148d604c),
          highlightColor: const Color(0x148d604c),
          splashColor: const Color(0x248d604c),
          disabledColor: const Color(0xffa39488),
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
          listTileTheme: const ListTileThemeData(
            contentPadding:
                EdgeInsets.symmetric(horizontal: AppSpacing.content),
            horizontalTitleGap: AppSpacing.item,
          ),
          cardTheme: CardThemeData(
            clipBehavior: Clip.antiAlias,
            margin: AppSpacing.cardMargin,
            elevation: 0,
            color: const Color(0xfffaf1e7),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          ),
          chipTheme: ChipThemeData(
            backgroundColor: const Color(0xfff5eee5),
            selectedColor: const Color(0xffe9d8c5),
            disabledColor: const Color(0xfff3efe9),
            side: BorderSide.none,
            shape: const StadiumBorder(),
            labelStyle: const TextStyle(color: Color(0xff655044), fontSize: 14),
            secondaryLabelStyle: const TextStyle(
                color: Color(0xff4d3529),
                fontSize: 14,
                fontWeight: FontWeight.w600),
            checkmarkColor: const Color(0xff5b3b2e),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          ),
          segmentedButtonTheme: SegmentedButtonThemeData(
            style: ButtonStyle(
              side: const WidgetStatePropertyAll(BorderSide.none),
              shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
              backgroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? const Color(0xffe9d8c5)
                      : const Color(0xfff5eee5)),
              foregroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.disabled)
                      ? const Color(0xff9b8e83)
                      : const Color(0xff5b3b2e)),
              padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
            ),
          ),
          switchTheme: SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.disabled)
                    ? const Color(0xffe9e0d6)
                    : const Color(0xfffffdf9)),
            trackColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.disabled)
                    ? const Color(0xffe2d9ce)
                    : states.contains(WidgetState.selected)
                        ? const Color(0xff80614c)
                        : const Color(0xffc9b8a6)),
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
          checkboxTheme: CheckboxThemeData(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            side: const BorderSide(color: Color(0xffa99584), width: 1.5),
          ),
          popupMenuTheme: PopupMenuThemeData(
            menuPadding: EdgeInsets.zero,
            color: const Color(0xfffffdf9),
            surfaceTintColor: Colors.transparent,
            elevation: 3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xff4d3a30),
            contentTextStyle:
                const TextStyle(color: Color(0xfffffdf9), fontSize: 14),
            actionTextColor: const Color(0xffffdfb8),
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          tooltipTheme: TooltipThemeData(
            decoration: BoxDecoration(
                color: const Color(0xff4d3a30),
                borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(color: Color(0xfffffdf9), fontSize: 12),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: const Color(0xffeee1d3),
            foregroundColor: const Color(0xff5b3b2e),
            elevation: 1,
            highlightElevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: const Color(0xfffffdf9),
            surfaceTintColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            headerBackgroundColor: const Color(0xfffaf6f0),
            headerForegroundColor: const Color(0xff5b3b2e),
            dividerColor: const Color(0xffeadfd5),
            rangePickerBackgroundColor: const Color(0xfffffdf9),
            rangePickerHeaderBackgroundColor: const Color(0xfffaf6f0),
            rangePickerHeaderForegroundColor: const Color(0xff5b3b2e),
            rangeSelectionBackgroundColor: const Color(0xffeee1d3),
          ),
          timePickerTheme: TimePickerThemeData(
            backgroundColor: const Color(0xfffffdf9),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            hourMinuteShape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            dialBackgroundColor: const Color(0xfff5eee5),
            dialHandColor: const Color(0xff80614c),
            hourMinuteColor: WidgetStateColor.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? const Color(0xffe9d8c5)
                    : const Color(0xfff5eee5)),
            dayPeriodColor: WidgetStateColor.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? const Color(0xffe9d8c5)
                    : const Color(0xfffaf6f0)),
            dayPeriodTextColor: const Color(0xff5b3b2e),
            dayPeriodBorderSide: const BorderSide(color: Color(0xffe5d9cb)),
            dayPeriodShape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
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
              minimumSize: const Size(64, 48),
              backgroundColor: const Color(0xff5b3b2e),
              foregroundColor: Colors.white,
              disabledForegroundColor: const Color(0xffa39488),
              disabledBackgroundColor: const Color(0xffece5db),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              textStyle: const TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(64, 48),
              foregroundColor: const Color(0xff5b3b2e),
              disabledForegroundColor: const Color(0xffa39488),
              side: const BorderSide(color: Color(0xffd8c8bb)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: const Color(0xfffffdf9),
            surfaceTintColor: Colors.transparent,
            titleTextStyle: const TextStyle(
                color: Color(0xff33241f),
                fontSize: 21,
                fontWeight: FontWeight.w700),
            contentTextStyle: const TextStyle(
                color: Color(0xff6f625c), fontSize: 14, height: 1.5),
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
