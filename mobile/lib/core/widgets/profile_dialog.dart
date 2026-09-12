import 'package:flutter/material.dart';

/// A compact form with a scrollable body and a footer that stays reachable.
class ProfileDialog extends StatelessWidget {
  const ProfileDialog(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.children,
      required this.onSave,
      required this.saveLabel,
      required this.cancelLabel,
      this.saving = false,
      this.error});
  final String title, subtitle, saveLabel, cancelLabel;
  final List<Widget> children;
  final VoidCallback? onSave;
  final bool saving;
  final String? error;

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !saving,
        child: Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                color: const Color(0xffffefcc),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(subtitle),
                    ]),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: children),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Text(error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
                child: Row(children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed:
                              saving ? null : () => Navigator.of(context).pop(),
                          child: Text(cancelLabel))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: FilledButton(
                          onPressed: saving ? null : onSave,
                          child: saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : Text(saveLabel))),
                ]),
              ),
            ]),
          ),
        ),
      );
}
