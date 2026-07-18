import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/app_radius.dart';
import '../utils/app_spacing.dart';
import '../utils/app_text_styles.dart';

/// One selectable row in an [OptionSheet].
class SheetOption<T> {
  const SheetOption({required this.value, required this.label, this.subtitle});
  final T value;
  final String label;
  final String? subtitle;
}

/// Bottom-sheet single-select picker. Returns the chosen value, or null if
/// dismissed. Used wherever the mockups show a "Select ▾" dropdown. Set
/// [searchable] to show a filter field that matches on label + subtitle.
class OptionSheet {
  const OptionSheet._();

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required List<SheetOption<T>> options,
    T? selected,
    bool searchable = false,
    String searchHint = 'Search',
    String? addLabel,
    VoidCallback? onAdd,
  }) {
    final c = context.colors;
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: c.bgSurface,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          // Lift the sheet above the keyboard when the search field is focused.
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: _OptionSheetBody<T>(
                title: title,
                options: options,
                selected: selected,
                searchable: searchable,
                searchHint: searchHint,
                addLabel: addLabel,
                onAdd: onAdd,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OptionSheetBody<T> extends StatefulWidget {
  const _OptionSheetBody({
    required this.title,
    required this.options,
    required this.selected,
    required this.searchable,
    required this.searchHint,
    this.addLabel,
    this.onAdd,
  });

  final String title;
  final List<SheetOption<T>> options;
  final T? selected;
  final bool searchable;
  final String searchHint;
  final String? addLabel;
  final VoidCallback? onAdd;

  @override
  State<_OptionSheetBody<T>> createState() => _OptionSheetBodyState<T>();
}

class _OptionSheetBodyState<T> extends State<_OptionSheetBody<T>> {
  String _query = '';

  List<SheetOption<T>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options.where((o) {
      final hay = '${o.label} ${o.subtitle ?? ''}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final options = _filtered;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(widget.title,
                  style: AppTextStyles.h2.copyWith(color: c.textMain)),
            ),
            if (widget.onAdd != null)
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onAdd!();
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text(widget.addLabel ?? 'Add new'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (widget.searchable) ...[
          TextField(
            autofocus: false,
            onChanged: (v) => setState(() => _query = v),
            style: AppTextStyles.body.copyWith(color: c.textMain),
            decoration: InputDecoration(
              hintText: widget.searchHint,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              fillColor: c.bgContainer,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                borderSide: BorderSide(color: c.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                borderSide: BorderSide(color: c.borderColor),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (options.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text(
                _query.isEmpty
                    ? 'Nothing to choose from yet'
                    : 'No matches for “$_query”',
                style: AppTextStyles.body.copyWith(color: c.textSub)),
          ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: options.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: c.borderColor),
            itemBuilder: (_, i) {
              final o = options[i];
              final isSel = o.value == widget.selected;
              return ListTile(
                title: Text(o.label,
                    style: AppTextStyles.body.copyWith(color: c.textMain)),
                subtitle: o.subtitle != null
                    ? Text(o.subtitle!,
                        style:
                            AppTextStyles.caption.copyWith(color: c.textSub))
                    : null,
                trailing:
                    isSel ? Icon(Icons.check, color: c.primary) : null,
                onTap: () => Navigator.of(context).pop(o.value),
              );
            },
          ),
        ),
      ],
    );
  }
}
