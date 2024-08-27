import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:sp_util/sp_util.dart';

import 'globals.dart';

void main() async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();
  await SpUtil.getInstance().then((value) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpoofDPI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(200, 60),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            iconColor: Colors.deepPurple,
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(200, 60),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            iconColor: Colors.white,
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const HomePage(),
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

    useEffect(() {
      if (isRunning.value) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Service is running at 127.0.0.1:8080'),
              duration: const Duration(days: 365),
              action: SnackBarAction(
                label: 'Test it!',
                onPressed: () {
                  platform.invokeMethod('test_service');
                },
              ),
            ),
          );
        });
      } else {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        });
      }
      return;
    }, [isRunning.value]);

    String buildParams() {
      var params = "";
      if (SpUtil.getBool('doh', defValue: true)! == true) {
        params += "--enable-doh ";
      }
      if (SpUtil.getString('dns', defValue: '8.8.8.8') != "8.8.8.8") {
        params += "--dns-addr ${SpUtil.getString('dns', defValue: '8.8.8.8')} ";
      }
      params += "--window-size ${SpUtil.getInt('ws', defValue: 0)}";
      return params;
    }

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
          var params = buildParams();
          await platform.invokeMethod('start_proxy', {'params': params, 'vpn_mode': SpUtil.getBool('use_vpn_mode', defValue: true)});
          isRunning.value = true;
        } on PlatformException catch (e) {
          print("Failed to start proxy: '${e.message}'.");
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('SpoofDPI'),
        actions: [
          IconButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SettingsPage()));
              },
              icon: const Icon(Icons.settings))
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: toggleProxy,
              icon: Icon(
                isRunning.value ? Icons.stop : Icons.play_arrow,
                color: Theme.of(context).iconTheme.color,
              ),
              label: Text(isRunning.value ? 'Stop service' : 'Start service'),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends HookWidget {
  const SettingsPage({super.key});

  static const platform = MethodChannel('proxy_bridge');

  @override
  Widget build(BuildContext context) {

    final vpnMode = useState(SpUtil.getBool('use_vpn_mode', defValue: true)!);

    final enableDoh = useState(SpUtil.getBool('doh', defValue: true)!);

    final TextEditingController dnsController = useTextEditingController(
      text: SpUtil.getString('dns', defValue: '8.8.8.8'),
    );
    final TextEditingController windowSizeController = useTextEditingController(
      text: SpUtil.getInt('ws', defValue: 0).toString(),
    );

    void updateDoh(bool? value) {
      enableDoh.value = value ?? true;
      SpUtil.putBool('doh', enableDoh.value);
    }

    void updateVpnMode(bool? value) {
      vpnMode.value = value ?? true;
      SpUtil.putBool('use_vpn_mode', vpnMode.value);
    }

    void updateDns(String value) {
      if (_isValidIp(value)) {
        SpUtil.putString('dns', value);
      }
    }

    void updateWindowSize(String value) {
      final intValue = int.tryParse(value);
      if (intValue != null) {
        SpUtil.putInt('ws', intValue);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CheckboxListTile(
              secondary: const Icon(Icons.vpn_key),
              title: const Text('Use VPN mode'),
              subtitle: const Text('If disabled - only Proxy server will be started'),
              value: vpnMode.value,
              onChanged: updateVpnMode,
            ),
            CheckboxListTile(
              secondary: const Icon(Icons.public),
              title: const Text('Enable DOH'),
              value: enableDoh.value,
              onChanged: updateDoh,
            ),
            const SizedBox(height: 15,),
            TextField(
              controller: dnsController,
              decoration: const InputDecoration(
                labelText: 'DNS',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dns),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: updateDns,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: windowSizeController,
              decoration: const InputDecoration(
                labelText: 'Window size',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.window),
              ),
              keyboardType: TextInputType.number,
              onChanged: updateWindowSize,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('SpoofDPI source code'),
              onTap: () async {
                await platform.invokeMethod('open_binary');
              },
            ),
            ListTile(
              leading: const Icon(Icons.code_off),
              title: const Text('SpoofDPI-Platform $appVersion source code'),
              onTap: () async {
                await platform.invokeMethod('open_me');
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _isValidIp(String value) {
    final ipPattern = RegExp(
      r'^(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)\.' +
          r'(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)\.' +
          r'(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)\.' +
          r'(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)$',
    );
    return ipPattern.hasMatch(value);
  }
}
