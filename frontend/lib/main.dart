/// Application bootstrap only: bindings, dependencies, runApp.
///
/// No feature logic, no permission prompts, no shell code lives here.
library;

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_dependencies.dart';
import 'core/device/device_context.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DeviceContext.refreshTimezone();
  final deps = await AppDependencies.create();
  runApp(BlistraApp(deps: deps));
}
