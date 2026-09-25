import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// One place for timings and curves, so the whole app moves the same way.
abstract final class Motion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
  static const slower = Duration(milliseconds: 650);

  static const curve = Curves.easeOutCubic;
  static const emphasized = Cubic(0.2, 0, 0, 1);
  static const spring = Curves.easeOutBack;

  /// [d], or zero when the system asks for no animations.
  static Duration of(BuildContext context, Duration d) =>
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ? Duration.zero : d;
}

abstract final class Haptic {
  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
  static void select() => HapticFeedback.selectionClick();
}
