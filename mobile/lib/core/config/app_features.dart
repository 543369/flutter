/// Enables login password recovery after mail delivery checks.
/// Account-security email verification is always visible.
class AppFeatures {
  static const emailActionsEnabled =
      bool.fromEnvironment('EMAIL_ACTIONS_ENABLED', defaultValue: false);
}
