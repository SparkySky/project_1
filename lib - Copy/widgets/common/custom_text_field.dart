import 'package:flutter/material.dart';
import '../../app_theme.dart';

/// Reusable custom text field with consistent styling
/// Used for form inputs throughout the app
class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool readOnly;
  final String? helperText;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.readOnly = false,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      cursorColor: AppTheme.primaryOrange,
      style: TextStyle(color: readOnly ? Colors.grey[600] : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        floatingLabelStyle: TextStyle(color: AppTheme.primaryOrange),
        helperText: helperText,
        helperStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
        prefixIcon: Icon(icon, color: AppTheme.primaryOrange),
        suffixIcon: readOnly
            ? Icon(Icons.lock_outline, color: Colors.grey[400], size: 18)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2),
        ),
        filled: true,
        fillColor: readOnly ? Colors.grey[100] : Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}



