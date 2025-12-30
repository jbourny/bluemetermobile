import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fixnum/fixnum.dart';
import 'core/packet_analyzer.dart';
import 'core/state/data_storage.dart';
import 'core/models/player_info.dart';
import 'core/models/dps_data.dart';
import 'core/models/classes.dart';

void main() {
  runApp(const MyApp());
}

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: OverlayWidget()),
  );
}

class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _players = [];

  // Track window size locally to support resizing
  double _windowWidth = 400;
  double _windowHeight = 600;
  
  // Track window position
  double _windowX = 0;
  double _windowY = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is List) {
        setState(() {
          _players = List<Map<String, dynamic>>.from(event);
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            // Title Bar / Drag Area
            GestureDetector(
              onPanStart: (details) async {
                try {
                  final pos = await FlutterOverlayWindow.getOverlayPosition();
                  if (pos != null) {
                    setState(() {
                      _windowX = pos.x.toDouble();
                      _windowY = pos.y.toDouble();
                    });
                  }
                } catch (e) {
                  debugPrint("Error getting overlay position: $e");
                }
              },
              onPanUpdate: (details) async {
                setState(() {
                  _windowX += details.delta.dx;
                  _windowY += details.delta.dy;
                });
                await FlutterOverlayWindow.moveOverlay(
                  OverlayPosition(_windowX, _windowY),
                );
              },
              child: Container(
                height: 40,
                color: Colors.transparent, // Hit test
                child: Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        controller: _tabController,
                        labelPadding: EdgeInsets.zero,
                        tabs: const [
                          Tab(text: "All"),
                          Tab(text: "DPS"),
                          Tab(text: "T"),
                          Tab(text: "H"),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
                      onPressed: () async {
                        await FlutterOverlayWindow.closeOverlay();
                      },
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildList(null),
                  _buildList(Role.DPS),
                  _buildList(Role.Tank),
                  _buildList(Role.Heal),
                ],
              ),
            ),
            // Resize Handle
            GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _windowWidth += details.delta.dx;
                  _windowHeight += details.delta.dy;

                  // Min size constraints
                  if (_windowWidth < 200) _windowWidth = 200;
                  if (_windowHeight < 200) _windowHeight = 200;
                });
              },
              onPanEnd: (details) async {
                await FlutterOverlayWindow.resizeOverlay(
                  _windowWidth.toInt(),
                  _windowHeight.toInt(),
                  false, // Do not center, keep position
                );
              },
              child: Container(
                width: double.infinity,
                height: 30,
                color: Colors.transparent,
                alignment: Alignment.bottomRight,
                padding: const EdgeInsets.only(right: 8, bottom: 8),
                child: const Icon(Icons.drag_handle, color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(Role? roleFilter) {
    final filtered = roleFilter == null
        ? _players
        : _players.where((p) {
            final cls = Classes.fromId(p['classId']);
            return cls.role == roleFilter;
          }).toList();

    if (filtered.isEmpty) {
      return const Center(
        child: Text("No data", style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final p = filtered[index];
        final cls = Classes.fromId(p['classId']);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              Container(width: 4, height: 30, color: _getClassColor(cls)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['name'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "${cls.name}",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    (p['dps'] as num).toDouble().toStringAsFixed(0),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _formatNumber(p['total']),
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getClassColor(Classes cls) {
    switch (cls.role) {
      case Role.Tank:
        return Colors.blue;
      case Role.Heal:
        return Colors.green;
      case Role.DPS:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatNumber(int num) {
    if (num >= 1000000) return "${(num / 1000000).toStringAsFixed(1)}M";
    if (num >= 1000) return "${(num / 1000).toStringAsFixed(1)}K";
    return num.toString();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlueMeter Mobile',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
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
  static const eventChannel = EventChannel(
    'com.bluemeter.mobile/packet_stream',
  );

  bool _isVpnRunning = false;
  StreamSubscription? _packetSubscription;
  late PacketAnalyzer _packetAnalyzer;
  Timer? _overlayUpdateTimer;

  @override
  void initState() {
    super.initState();
    _packetAnalyzer = PacketAnalyzer(onDamageDetected: _onDamageDetected);
    // DataStorage().addListener(_updateOverlay);
    // Update overlay at 2 FPS (500ms) to prevent log spam and UI overload
    _overlayUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _updateOverlay();
    });
  }

  @override
  void dispose() {
    // DataStorage().removeListener(_updateOverlay);
    _overlayUpdateTimer?.cancel();
    super.dispose();
  }

  void _onDamageDetected(int damage, bool isCrit) {
    // Logic moved to DataStorage.
    // Overlay update is handled by DataStorage listener.
  }

  void _updateOverlay() {
    final storage = DataStorage();
    final players = storage.fullDpsDatas.entries.map((e) {
      final uid = e.key;
      final dpsData = e.value;
      final info = storage.getPlayerInfo(uid);
      return {
        'name': info?.name ?? "Unknown",
        'classId': info?.professionId ?? 0,
        'dps': dpsData.simpleDps,
        'total': dpsData.totalAttackDamage.toInt(),
        'level': info?.level ?? 0,
      };
    }).toList();

    // Sort by DPS
    players.sort((a, b) {
      final dpsA = (a['dps'] as num?)?.toDouble() ?? 0.0;
      final dpsB = (b['dps'] as num?)?.toDouble() ?? 0.0;
      return dpsB.compareTo(dpsA);
    });

    FlutterOverlayWindow.shareData(players);
  }

  void _onPacketData(dynamic event) {
    if (event is Uint8List) {
      _packetAnalyzer.processPacket(event);
    } else if (event is List<int>) {
      _packetAnalyzer.processPacket(Uint8List.fromList(event));
    } else if (event is String) {
      try {
        final bytes = _hexToBytes(event);
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
    final bool status = await FlutterOverlayWindow.isPermissionGranted();
    if (!status) {
      await FlutterOverlayWindow.requestPermission();
      return;
    }

    if (await FlutterOverlayWindow.isActive()) return;

    await FlutterOverlayWindow.showOverlay(
      enableDrag: false, // Disable default drag to allow custom move/scroll
      overlayTitle: "BlueMeter DPS",
      overlayContent: "DPS Meter Active",
      flag: OverlayFlag.defaultFlag,
      alignment: OverlayAlignment.centerLeft,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.auto,
      height: 600,
      width: 400,
    );
  }

  Future<void> _startVpn() async {
    try {
      await platform.invokeMethod('startVpn');
      setState(() {
        _isVpnRunning = true;
      });

      _packetSubscription = eventChannel.receiveBroadcastStream().listen(
        _onPacketData,
      );
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
      appBar: AppBar(
        title: const Text('BlueMeter Mobile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              DataStorage().reset();
            },
          ),
          IconButton(icon: const Icon(Icons.layers), onPressed: _startOverlay),
          IconButton(
            icon: Icon(_isVpnRunning ? Icons.stop : Icons.play_arrow),
            color: _isVpnRunning ? Colors.red : Colors.green,
            onPressed: _isVpnRunning ? _stopVpn : _startVpn,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Overlay is active"),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _startOverlay,
              child: const Text('Show DPS Overlay'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int num) {
    if (num >= 1000000) return "${(num / 1000000).toStringAsFixed(1)}M";
    if (num >= 1000) return "${(num / 1000).toStringAsFixed(1)}K";
    return num.toString();
  }
}
