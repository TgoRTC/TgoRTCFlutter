/// SDK configuration options.
///
/// Use this class to configure the SDK behavior.
///
/// ## Example
///
/// ```dart
/// final options = Options()
///   ..mirror = true
///   ..debug = false;
///
/// TgoRTC.instance.init(options);
/// ```
class Options {
  /// Whether to mirror local video (front camera).
  ///
  /// Defaults to `false`.
  bool mirror = false;

  /// Whether to enable debug logging.
  ///
  /// Defaults to `true`.
  bool debug = true;
}
