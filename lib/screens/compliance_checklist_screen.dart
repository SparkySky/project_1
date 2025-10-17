// screens/compliance_checklist_screen.dart
import 'package:flutter/material.dart';
import '../widgets/checklist_item_widget.dart';

class ComplianceChecklistScreen extends StatelessWidget {
  final List<String> checklistItems = const [
    'Verify user identity',
    'Confirm jurisdictional boundaries',
    'Map enforcement agency (PDRM, MCMC, NACSA)',
    'Log digital evidence',
    'Trigger penalty logic'
  ];

  const ComplianceChecklistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Compliance Checklist')),
      body: ListView.builder(
        itemCount: checklistItems.length,
        itemBuilder: (context, index) {
          return ChecklistItemWidget(
            title: checklistItems[index],
            onChanged: (bool? value) {
              // Handle logic here (e.g., update state, log action)
              print('Checklist "${checklistItems[index]}" marked: $value');
            },
          );
        },
      ),
    );
  }
}