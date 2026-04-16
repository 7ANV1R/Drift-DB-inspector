import 'package:flutter/material.dart';

class PackageInput extends StatelessWidget {
  const PackageInput({
    super.key,
    required this.controller,
    this.enabled = true,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: const InputDecoration(
        labelText: 'Application ID',
        hintText: 'com.company.app',
        prefixIcon: Icon(Icons.badge_outlined, size: 22),
      ),
      style: Theme.of(context).textTheme.bodyLarge,
      autocorrect: false,
      enableSuggestions: false,
    );
  }
}
