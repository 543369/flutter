import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/app/petcare_app.dart';
import 'package:petcare/features/auth/auth_panel.dart';
import '../test/widget_test.dart' show FakeApi, FakeReminders;
import '../test/auth_panel_test.dart' show AuthFake;
void main() {
 testWidgets('capture compact registration code control', (tester) async {
  await tester.runAsync(() async {
   final data=ByteData.sublistView(await File('/System/Library/Fonts/STHeiti Light.ttc').readAsBytes());
   for(final family in ['SF Pro Display','Roboto','Ahem']) {
    await (FontLoader(family)..addFont(Future.value(data))).load();
   }
  });
  await tester.pumpWidget(PetCareApp(api:FakeApi(),reminders:FakeReminders()));
  await tester.pumpAndSettle();
  final theme=tester.widget<MaterialApp>(find.byType(MaterialApp)).theme;
  final boundary=GlobalKey();
  tester.view.devicePixelRatio=1;tester.view.physicalSize=const Size(393,900);
  addTearDown(tester.view.resetDevicePixelRatio);addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(RepaintBoundary(key:boundary,child:MaterialApp(theme:theme,locale:const Locale('zh'),supportedLocales:const [Locale('zh'),Locale('en')],localizationsDelegates:GlobalMaterialLocalizations.delegates,debugShowCheckedModeBanner:false,home:Scaffold(body:AuthPanel(api:AuthFake(),binding:true,onAuthenticated:()async{})))));
  await tester.pumpAndSettle();
  expect(tester.takeException(),isNull);
  await tester.runAsync(()async{
   final image=await (boundary.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio:2);
   final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
   await File('/tmp/petcare-registration-style.png').writeAsBytes(bytes!.buffer.asUint8List());image.dispose();
  });
 });
}
