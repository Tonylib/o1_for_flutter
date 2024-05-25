import 'package:flutter/material.dart';

import 'o1_view.dart';

void main() {
  runApp(const o1App());
}

class o1App extends StatelessWidget {
  const o1App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '01',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // use the o1_view.dart file to see the ui
      home: const O1ViewController(),
    );
  }
}
