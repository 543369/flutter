import 'package:flutter/material.dart';
import 'app/petcare_app.dart';
import 'core/sync/push_service.dart';
export 'app/petcare_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Missing project configuration does not prevent ordinary/local-only use.
  try {
    await PushConfig.initialize();
  } catch (_) {}
  runApp(const PetCareApp());
}
