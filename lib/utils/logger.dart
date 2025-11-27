import 'dart:developer' as developer;

import '../tgortc.dart';

class Logger {
  static void debug(Object msg) {
    if (TgoRTC.instance.options.debug) {
      developer.log("$msg", name: 'DEBUG');
    }
  }

  static void info(Object msg) {
    if (TgoRTC.instance.options.debug) {
      developer.log("$msg", name: 'INFO');
    }
  }

  static void error(Object msg) {
    if (TgoRTC.instance.options.debug) {
      developer.log("$msg", name: 'ERROR');
    }
  }
}
