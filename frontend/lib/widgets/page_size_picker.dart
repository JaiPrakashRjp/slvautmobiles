import 'package:flutter/material.dart';

/// Small dropdown to choose how many rows load per page (50 / 70 / 90).
class PageSizePicker extends StatelessWidget {
  const PageSizePicker({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const options = [50, 70, 90];

  @override
  Widget build(BuildContext context) {
    return DropdownButton<int>(
      value: options.contains(value) ? value : options.first,
      underline: const SizedBox.shrink(),
      isDense: true,
      items: options
          .map((s) => DropdownMenuItem(value: s, child: Text('$s / page')))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
