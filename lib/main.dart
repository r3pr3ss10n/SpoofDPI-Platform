import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

void main() {
  DartPluginRegistrant.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpoofDPI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage()
    );
  }
}

class HomePage extends HookWidget {
  const HomePage({super.key});

  static const platform = MethodChannel('proxy_bridge');

  @override
  Widget build(BuildContext context) {
    final isRunning = useState<bool>(false);

    Future<void> checkIfRunning() async {
      try {
        final result = await platform.invokeMethod('is_proxy_running');
        isRunning.value = result;
      } on PlatformException catch (e) {
        print("Failed to check proxy status: '${e.message}'.");
      }
    }

    useEffect(() {
      checkIfRunning();
      return;
    }, []);

    Future<void> toggleProxy() async {
      if (isRunning.value) {
        try {
          await platform.invokeMethod('stop_proxy');
          isRunning.value = false;
        } on PlatformException catch (e) {
          print("Failed to stop proxy: '${e.message}'.");
        }
      } else {
        try {
          await platform.invokeMethod('start_proxy');
          isRunning.value = true;
        } on PlatformException catch (e) {
          print("Failed to start proxy: '${e.message}'.");
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('SpoofDPI')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: toggleProxy,
              child: Text(isRunning.value ? 'Stop service' : 'Start service'),
            ),
          ],
        ),
      ),
    );
  }
}