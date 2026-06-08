import 'package:flutter/material.dart';

import 'app_picker_screen.dart';

class LogLensApp extends StatelessWidget {
  const LogLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Log Lens',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2D6FE0), brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const AppPickerScreen(),
    );
  }
}
