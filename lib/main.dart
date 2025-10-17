import 'package:flutter/material.dart';
import 'screens/compliance_checklist_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Compliance App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ComplianceChecklistScreen(), // 👈 This is your screen
    );
  }
}