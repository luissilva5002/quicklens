import 'package:flutter/material.dart';
import 'pages/home.dart';

void main() {
  runApp(const QuickLensApp());
}

class QuickLensApp extends StatelessWidget {
  const QuickLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuickLens',
      theme: ThemeData(primarySwatch: Colors.amber),
      home: const HomePage(),
    );
  }
}