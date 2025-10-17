// widgets/checklist_item_widget.dart
import 'package:flutter/material.dart';

class ChecklistItemWidget extends StatelessWidget {
  final String title;
  final ValueChanged<bool?> onChanged;

  const ChecklistItemWidget({
    super.key,
    required this.title,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      title: Text(title),
      value: false,
      onChanged: onChanged,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}