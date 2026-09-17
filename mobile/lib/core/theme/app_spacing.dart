import 'package:flutter/material.dart';

/// Shared layout rhythm. Artwork offsets, touch targets and safe areas are
/// separate concerns: do not replace their dimensions with spacing tokens.
abstract final class AppSpacing {
  static const double tight = 4;
  static const double inline = 8;
  static const double item = 12;
  static const double content = 16;
  static const double section = 24;
  static const double page = 24;
  static const double spacious = 32;

  static const pageInsets = EdgeInsets.fromLTRB(page, content, page, section);
  static const cardInsets = EdgeInsets.all(content);
  static const dialogInsets = EdgeInsets.all(section);
  // Cards own their sibling gap; add only item after a Card for a section gap.
  static const cardMargin = EdgeInsets.only(bottom: item);
}
