import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// A non-editable selector with one clipped surface and no outer menu padding.
class AppSelect<T> extends StatelessWidget {
  const AppSelect(
      {super.key,
      required this.initialValue,
      required this.items,
      required this.onChanged,
      this.decoration = const InputDecoration()});

  final T? initialValue;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration decoration;

  @override
  Widget build(BuildContext context) {
    final selected =
        items.where((item) => item.value == initialValue).firstOrNull;
    final border = decoration.enabledBorder ??
        decoration.border ??
        Theme.of(context).inputDecorationTheme.enabledBorder ??
        Theme.of(context).inputDecorationTheme.border;
    final radius = border is OutlineInputBorder
        ? border.borderRadius
        : BorderRadius.circular(18);
    return LayoutBuilder(
        builder: (context, constraints) => PopupMenuButton<T>(
              enabled: onChanged != null && items.isNotEmpty,
              tooltip: '',
              borderRadius: radius,
              position: PopupMenuPosition.under,
              offset: const Offset(0, AppSpacing.inline),
              menuPadding: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              constraints: BoxConstraints(
                  minWidth: constraints.maxWidth,
                  maxWidth: constraints.maxWidth,
                  maxHeight: 360),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              color: Theme.of(context).colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 3,
              onSelected: onChanged,
              itemBuilder: (_) => items
                  .map((item) => PopupMenuItem<T>(
                        value: item.value,
                        enabled: item.enabled,
                        child: Row(children: [
                          Expanded(child: item.child),
                          if (item.value == initialValue)
                            const Padding(
                                padding: EdgeInsets.only(left: 12),
                                child: Icon(Icons.check_rounded, size: 18)),
                        ]),
                      ))
                  .toList(),
              child: InputDecorator(
                decoration: decoration.copyWith(enabled: onChanged != null),
                isEmpty: selected == null,
                child: Row(children: [
                  Expanded(child: selected?.child ?? const SizedBox()),
                  const Icon(Icons.expand_more_rounded, size: 20),
                ]),
              ),
            ));
  }
}
