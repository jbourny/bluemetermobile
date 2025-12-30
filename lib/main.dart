import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/packet_analyzer.dart';

void main() {
  runApp(const MyApp());
}

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlayWidget(),
  ));
}

class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  String _dpsText = "Waiting for data...";

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is String) {
        setState(() {
          _dpsText = event;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blueAccent),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "BlueMeter DPS",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Text(
                _dpsText,
                style: const TextStyle(color: Colors.greenAccent, fontSize: 16),
              ),
              const SizedBox(height: 5),
              ElevatedButton(
                onPressed: () async {
                    await FlutterOverlayWindow.closeOverlay();
                },
                child: const Text("Close", style: TextStyle(fontSize: 10)),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlueMeter Mobile',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const platform = MethodChannel('com.bluemeter.mobile/vpn');
  static const eventChannel = EventChannel('com.bluemeter.mobile/packet_stream');
  
  bool _isVpnRunning = false;
  StreamSubscription? _packetSubscription;
  late PacketAnalyzer _packetAnalyzer;
  
  int _totalDamage = 0;
  DateTime? _combatStart;
  Timer? _dpsUpdateTimer;

  @override
  void initState() {
    super.initState();
    _packetAnalyzer = PacketAnalyzer(onDamageDetected: _onDamageDetected);
  }

  void _onDamageDetected(int damage, bool isCrit) {
    if (_combatStart == null || DateTime.now().difference(_combatStart!) > const Duration(seconds: 10)) {
      _combatStart = DateTime.now();
      _totalDamage = 0;
    }
    
    _totalDamage += damage;
    _updateOverlay();
  }

  void _updateOverlay() {
    if (_combatStart == null) return;
    
    final duration = DateTime.now().difference(_combatStart!).inSeconds;
    final dps = duration > 0 ? _totalDamage / duration : _totalDamage;
    
    final dpsString = "DPS: ${dps.toStringAsFixed(1)}\nTotal: $_totalDamage";
    FlutterOverlayWindow.shareData(dpsString);
  }

  void _onPacketData(dynamic event) {
    if (event is Uint8List) {
      debugPrint("Received packet chunk: ${event.length} bytes");
      _packetAnalyzer.processPacket(event);
    } else if (event is List<int>) {
       debugPrint("Received packet chunk (List<int>): ${event.length} bytes");
       _packetAnalyzer.processPacket(Uint8List.fromList(event));
    } else if (event is String) {
      try {
        final bytes = _hexToBytes(event);
        debugPrint("Received packet chunk (String): ${bytes.length} bytes");
        _packetAnalyzer.processPacket(bytes);
      } catch (e) {
        debugPrint("Error processing packet: $e");
      }
    }
  }

  Uint8List _hexToBytes(String hex) {
    final buffer = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < hex.length; i += 2) {
      buffer[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return buffer;
  }

  Future<void> _requestOverlayPermission() async {
    final status = await FlutterOverlayWindow.isPermissionGranted();
    if (!status) {
      await FlutterOverlayWindow.requestPermission();
    }
  }

  Future<void> _startOverlay() async {
    debugPrint("Starting overlay...");
    final bool status = await FlutterOverlayWindow.isPermissionGranted();
    debugPrint("Permission granted: $status");
    if (!status) {
      debugPrint("Requesting permission...");
      await FlutterOverlayWindow.requestPermission();
      return;
    }

    if (await FlutterOverlayWindow.isActive()) {
      debugPrint("Overlay already active");
      return;
    }

    debugPrint("Calling showOverlay");
    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: "BlueMeter DPS",
      overlayContent: "DPS Meter Active",
      flag: OverlayFlag.defaultFlag,
      alignment: OverlayAlignment.centerLeft,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.auto,
      height: 400,
      width: 400,
    );
    debugPrint("showOverlay called");
  }

  Future<void> _startVpn() async {
    try {
      await platform.invokeMethod('startVpn');
      setState(() {
        _isVpnRunning = true;
      });
      
      // Start listening to packets
      _packetSubscription = eventChannel.receiveBroadcastStream().listen(_onPacketData);
      
    } on PlatformException catch (e) {
      debugPrint("Failed to start VPN: '${e.message}'.");
    }
  }

  Future<void> _stopVpn() async {
    try {
      await platform.invokeMethod('stopVpn');
      setState(() {
        _isVpnRunning = false;
      });
      _packetSubscription?.cancel();
    } on PlatformException catch (e) {
      debugPrint("Failed to stop VPN: '${e.message}'.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BlueMeter Mobile')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _requestOverlayPermission,
              child: const Text('Grant Overlay Permission'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _startOverlay,
              child: const Text('Show DPS Overlay'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isVpnRunning ? _stopVpn : _startVpn,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isVpnRunning ? Colors.red : Colors.green,
              ),
              child: Text(_isVpnRunning ? 'Stop Capture' : 'Start Capture'),
            ),
          ],
        ),
      ),
    );
  }
}
