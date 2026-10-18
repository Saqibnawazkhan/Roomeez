import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Haptic feedback, in one place so the whole app feels the same. Phones
/// without a vibration motor, or with touch vibration turned off in their
/// settings, simply ignore it.
abstract final class Haptics {
  /// A button, card or chip was tapped.
  static void tap() => HapticFeedback.lightImpact();

  /// A choice changed: a tab, toggle or option. iOS has a dedicated "tick";
  /// many Android phones don't play it, so they get a light tap instead.
  static void select() =>
      defaultTargetPlatform == TargetPlatform.iOS ? HapticFeedback.selectionClick() : HapticFeedback.lightImpact();

  /// Something was saved or done.
  static void success() => HapticFeedback.mediumImpact();

  /// Something went wrong.
  static void error() => HapticFeedback.heavyImpact();
}
