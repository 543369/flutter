import 'dart:async';
import 'package:flutter/material.dart';

/// The same familiar paw is used in the wordmark and loading state.
class PawMark extends StatelessWidget {
  const PawMark({super.key, this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Icon(
          Icons.pets_rounded,
          size: size,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
}

class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PawMark(size: 25),
          const SizedBox(width: 8),
          Text(
            Localizations.localeOf(context).languageCode == 'zh'
                ? '爪伴'
                : 'PetCare',
          ),
        ],
      );
}

/// Short requests never flash a spinner; reduced motion keeps the paw still.
class PawLoading extends StatefulWidget {
  const PawLoading({super.key});

  @override
  State<PawLoading> createState() => _PawLoadingState();
}

class _PawLoadingState extends State<PawLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  Timer? delay;
  bool visible = false;

  @override
  void initState() {
    super.initState();
    delay = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => visible = true);
      updateMotion();
    });
  }

  void updateMotion() {
    if (!visible || MediaQuery.disableAnimationsOf(context)) {
      pulse.stop();
      pulse.value = 0;
    } else if (!pulse.isAnimating) {
      pulse.repeat(reverse: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    updateMotion();
  }

  @override
  void dispose() {
    delay?.cancel();
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final label = Localizations.localeOf(context).languageCode == 'zh'
        ? '正在准备你们的日常…'
        : 'Getting your day ready…';
    return Center(
      child: Semantics(
        liveRegion: true,
        label: label,
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: pulse,
                child: const PawMark(size: 38),
                builder: (context, child) {
                  final value = Curves.easeInOut.transform(pulse.value);
                  return Opacity(
                    opacity: 0.65 + value * 0.35,
                    child: Transform.scale(
                      scale: 1 + value * 0.06,
                      child: child,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

/// Outgoing content is visual only: it must not accept taps or screen readers.
class GentleSwitch extends StatelessWidget {
  const GentleSwitch({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [
            for (final old in previous)
              ExcludeSemantics(child: IgnorePointer(child: old)),
            if (current != null) current,
          ],
        ),
        child: child,
      );
}
