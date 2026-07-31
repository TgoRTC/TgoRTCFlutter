import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:tgortcflutter/bridge/method_handlers.dart';
import 'package:tgortcflutter/bridge/event_forwarder.dart';
import 'package:tgortcflutter/bridge/tgo_video_surface_manager.dart';
import 'package:tgortcflutter/utils/logger.dart';

/// The main bridge class for HarmonyOS NEXT.
///
/// This class initializes the [MethodChannel] and sets up handlers for
/// communication between native HarmonyOS (ArkTS) and Flutter (Dart).
///
/// Note: connectivity_plus stub is now handled in native side (ConnectivityStubPlugin)
/// because Dart-side setMethodCallHandler cannot intercept Dart-to-Native calls.
class TgoRTCOhosBridge {
  static const MethodChannel _channel = MethodChannel('com.tgortc/bridge');

  static bool _isRegistered = false;

  static void _log(String msg) {
    developer.log('[TgoRTCOhosBridge] $msg', name: 'BRIDGE');
    print('[TgoRTCOhosBridge] $msg');
  }

  /// Registers the bridge. Should be called in main.dart.
  static void register() {
    if (_isRegistered) return;

    _log('Registering TgoRTCOhosBridge');
    Logger.info('Registering TgoRTCOhosBridge');

    // Set up method call handler for main bridge
    _channel.setMethodCallHandler(TgoMethodHandlers.handleMethodCall);

    // Note: connectivity_plus stub is now handled in native side (ConnectivityStubPlugin)
    // Dart-side setMethodCallHandler only handles Native-to-Dart calls,
    // but livekit_client makes Dart-to-Native calls to check connectivity.

    // Set up event forwarding
    TgoEventForwarder.init(_channel);
    TgoVideoSurfaceManager.instance.init();

    _isRegistered = true;
    _log('TgoRTCOhosBridge registered successfully');
  }

  /// Returns the MethodChannel instance.
  static MethodChannel get channel => _channel;
}
