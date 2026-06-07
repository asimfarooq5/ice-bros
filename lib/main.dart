import 'package:flutter/material.dart';

import 'game/game_screen.dart';

void main() {
  runApp(const SnowBrosApp());
}

class SnowBrosApp extends StatelessWidget {
  const SnowBrosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snow Bros',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}
