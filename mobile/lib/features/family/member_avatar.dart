import 'package:flutter/material.dart';
import '../../core/images/photo_cache.dart';

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, this.data, this.radius = 18});
  final String? data;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(Icons.person_outline_rounded,
        size: radius * 1.2, color: const Color(0xff80523f));
    Widget child = fallback;
    if (data != null && data!.isNotEmpty) {
      try {
        child = Image.memory(PhotoCache.shared.decode(data!),
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => fallback);
      } on FormatException {
        // Older or damaged images retain the default avatar.
      }
    }
    return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        child: ClipOval(child: child));
  }
}
