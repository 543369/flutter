import 'package:flutter/material.dart';

/// A visible entitlement marker, independent of the surrounding disabled state.
class MembershipBadge extends StatelessWidget {
  const MembershipBadge({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.workspace_premium_outlined,
            size: 14, color: colors.onPrimaryContainer),
        const SizedBox(width: 4),
        Flexible(
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.onPrimaryContainer,
                    height: 1.3))),
      ]),
    );
  }
}
