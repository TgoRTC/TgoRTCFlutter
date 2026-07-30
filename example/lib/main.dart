import 'package:flutter/material.dart';
import 'package:tgortcflutter/tgortc.dart';
import 'package:tgortcflutter/entity/options.dart';
import 'package:tgortcflutter/bridge/tgortc_ohos_bridge.dart';

import 'pages/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  TgoRTCOhosBridge.register();

  // 初始化 TgoRTC SDK
  TgoRTC.instance.init(Options()
    ..debug = true
    ..mirror = true);

  runApp(const TgoRTCExampleApp());
}

class TgoRTCExampleApp extends StatelessWidget {
  const TgoRTCExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TgoRTC Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F23),
        fontFamily: 'SF Pro Display',
      ),
      home: const HomePage(),
    );
  }
}
