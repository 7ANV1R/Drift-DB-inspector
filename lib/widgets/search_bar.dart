import 'package:flutter/material.dart';

class TableSearchBar extends StatefulWidget {
  const TableSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.enabled = true,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  State<TableSearchBar> createState() => _TableSearchBarState();
}

class _TableSearchBarState extends State<TableSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  void _onText() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: 'Search rows',
        hintText: 'Filter text columns…',
        isDense: true,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: widget.controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  widget.controller.clear();
                  widget.onChanged('');
                },
              ),
      ),
    );
  }
}
