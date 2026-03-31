import 'dart:developer' as developer;

import '../tgortc.dart';

class Logger {
  static void debug(Object msg) {
    if (TgoRTC.instance.options.debug) {
      final text = '[DEBUG] $msg';
      developer.log(text, name: 'DEBUG');
      print(text);
    }
  }

  static void info(Object msg) {
    if (TgoRTC.instance.options.debug) {
      final text = '[INFO] $msg';
      developer.log(text, name: 'INFO');
      print(text);
    }
  }

  static void error(Object msg) {
    if (TgoRTC.instance.options.debug) {
      final text = '[ERROR] $msg';
      developer.log(text, name: 'ERROR');
      print(text);
    }
  }
}
