import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_size/window_size.dart';
import 'home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Set app title
    setWindowTitle('QuickLens');

    // Initial vertical window size
    const initialSize = Size(1000, 1200); // portrait / vertical
    setWindowFrame(Rect.fromLTWH(100, 100, initialSize.width, initialSize.height));

    // Constrain resizing to vertical portrait-like aspect
    setWindowMinSize(Size(800, 1200));
    setWindowMaxSize(Size(1200, 2000));
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QuickLens',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
      ),
      home: PdfDropPage(),
    );
  }
}
