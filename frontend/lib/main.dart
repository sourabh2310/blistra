/// Application bootstrap only: bindings, dependencies, runApp.
///
/// No feature logic, no permission prompts, no shell code lives here.
library;

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final deps = await AppDependencies.create();
  runApp(BlistraApp(deps: deps));
}
