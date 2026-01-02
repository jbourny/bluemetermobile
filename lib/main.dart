import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:fixnum/fixnum.dart';
import 'core/analyze/packet_analyzer_v2.dart';
import 'core/state/data_storage.dart';
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

  // Track window position
  double _windowX = 0;
  double _windowY = 0;
  
  // Drag helpers
  double _lastMoveX = 0;
  double _lastMoveY = 0;
  double _windowDeltaX = 0;
  double _windowDeltaY = 0;
  Size? _resizeStartWindowSize;
  Offset? _dragStartTouchPosition; // Keep for resize
  bool _isDragging = false;

  // Minimize state
  bool _isMinimized = false;
  double _restoredWidth = 600;
  double _restoredHeight = 400;

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
    if (_isMinimized) {
      return _buildMinimized();
    }
    return _buildFull();
  }

  BoxDecoration get _windowDecoration => BoxDecoration(
        color: Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(width: 0.5, color: Colors.white.withValues(alpha: 0.9)),
      );

  Widget _buildMinimized() {
    final myData = _players.firstWhere(
      (p) => p['isMe'] == true,
      orElse: () => {},
    );
    final myDps = (myData['dps'] as num?)?.toDouble() ?? 0.0;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onPanStart: (details) async {
             _isDragging = false;
             try {
               final pos = await FlutterOverlayWindow.getOverlayPosition();
               _windowX = pos.x;
               _windowY = pos.y;
               _lastMoveX=details.globalPosition.dx;
               _lastMoveY=details.globalPosition.dy;
               _windowDeltaX=0;
               _windowDeltaY=0;
               _isDragging = true;
             } catch (e) {
               debugPrint("Error getting overlay position: $e");
             }
        },
        onPanUpdate: (details) {
             if (!_isDragging) return;
             final dpr = MediaQuery.of(context).devicePixelRatio;
             _windowDeltaX= details.globalPosition.dx-_lastMoveX;
             _windowDeltaY= details.globalPosition.dy - _lastMoveY;
             FlutterOverlayWindow.moveOverlay(
               OverlayPosition(_windowX+_windowDeltaX/dpr, _windowY+_windowDeltaY/dpr),
             );
        },
        onTap: () async {
          setState(() {
            _isMinimized = false;
          });
          await FlutterOverlayWindow.resizeOverlay(
            _restoredWidth.toInt(),
            _restoredHeight.toInt(),
            false,
          );
        },
        child: Container(
          decoration: _windowDecoration,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flash_on, size: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    _formatNumber(myDps),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () async {
                   final sendPort = IsolateNameServer.lookupPortByName('overlay_communication_port');
                   if (sendPort != null) {
                     sendPort.send("RESET");
                   }
                },
                child: const Icon(Icons.refresh, size: 16, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFull() {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: _windowDecoration,
        child: Column(
          children: [
            // Title Bar
            GestureDetector(
              onPanStart: (details) async {
                _isDragging = false;
                try {
                  final pos = await FlutterOverlayWindow.getOverlayPosition();
                  // Convert physical position (from native) to logical pixels (for Flutter)
                  _windowX = pos.x;
                  _windowY = pos.y;
                  _lastMoveX=details.globalPosition.dx;
                  _lastMoveY=details.globalPosition.dy;
                  _windowDeltaX=0;
                  _windowDeltaY=0;
                  _isDragging = true;
                                } catch (e) {
                  debugPrint("Error getting overlay position: $e");
                }
              },
              onPanUpdate: (details) {
                if (!_isDragging) return;
                  final dpr = MediaQuery.of(context).devicePixelRatio;
                  // Arrondir les deltas pour éviter l'accumulation d'erreurs de flottement
                _windowDeltaX= details.globalPosition.dx-_lastMoveX;
                _windowDeltaY= details.globalPosition.dy - _lastMoveY;
                
                // Simple delta update.
                // With alignment: OverlayAlignment.topLeft, this should be stable.
                debugPrint("[BM Overlay] dpr:$dpr Moving overlay to (${_windowX + _windowDeltaX} [+${details.delta.dx}], ${_windowY + _windowDeltaY} [+${details.delta.dy}])");
                
                FlutterOverlayWindow.moveOverlay(
                  OverlayPosition(_windowX+_windowDeltaX/dpr, _windowY+_windowDeltaY/dpr),
                );
              },
              child: Container(
                height: 32, // Reduced height
                color: Colors.transparent, // Hit test
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        controller: _tabController,
                        labelPadding: EdgeInsets.zero,
                        indicatorSize: TabBarIndicatorSize.label,
                        indicatorColor: Colors.transparent,
                        dividerColor: Colors.transparent,
                        labelColor: Colors.blue,
                        unselectedLabelColor: Colors.white,
                        tabs: const [
                          Tab(child: Icon(Icons.star, size: 16)),
                          Tab(child: Icon(Icons.flash_on, size: 16)), // DPS (Sword replacement)
                          Tab(child: Icon(Icons.shield, size: 16)),
                          Tab(child: Icon(Icons.local_hospital, size: 16)),
                        ],
                      ),
                    ),
                    // Actions
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            setState(() {
                              _isMinimized = true;
                            });
                            await FlutterOverlayWindow.resizeOverlay(135, 30, false);
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 2),
                            child: Icon(Icons.remove, size: 16, color: Colors.white70),
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                             final sendPort = IsolateNameServer.lookupPortByName('overlay_communication_port');
                             if (sendPort != null) {
                               sendPort.send("RESET");
                             } else {
                               debugPrint("Could not find communication port");
                             }
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 2),
                            child: Icon(Icons.refresh, size: 16, color: Colors.white70),
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            await FlutterOverlayWindow.closeOverlay();
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 2),
                            child: Icon(Icons.settings, size: 16, color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildList(null, "dps"),
                  _buildList(Role.dps, "dps"),
                  _buildList(Role.tank, "taken"),
                  _buildList(Role.heal, "heal"),
                ],
              ),
            ),
            // Resize Handle
            GestureDetector(
              onPanStart: (details) {
                // Use logical size directly
                final size = MediaQuery.of(context).size;
                _resizeStartWindowSize = size;
                _dragStartTouchPosition = details.globalPosition;
              },
              onPanUpdate: (details) {
                if (_resizeStartWindowSize == null || _dragStartTouchPosition == null) return;

                final currentTouch = details.globalPosition;
                final diff = currentTouch - _dragStartTouchPosition!;
                
                // Calculate new size in logical pixels
                double newWidth = _resizeStartWindowSize!.width + diff.dx;
                double newHeight = _resizeStartWindowSize!.height + diff.dy;

                // Min size constraints (logical)
                if (newWidth < 150) newWidth = 150;
                if (newHeight < 100) newHeight = 100;

                // Save for restore
                _restoredWidth = newWidth;
                _restoredHeight = newHeight;

                FlutterOverlayWindow.resizeOverlay(
                  newWidth.toInt(),
                  newHeight.toInt(),
                  false,
                );
              },
              child: Container(
                width: double.infinity,
                height: 20,
                color: Colors.transparent,
                alignment: Alignment.bottomRight,
                padding: const EdgeInsets.only(right: 4, bottom: 4),
                child: const Icon(Icons.drag_handle, size: 16, color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(Role? roleFilter, String metricType) {
    // Filter
    var filtered = _players;
    if (roleFilter != null) {
      filtered = _players.where((p) {
        final cls = Classes.fromId(p['classId']);
        return cls.role == roleFilter;
      }).toList();
    }

    if (filtered.isEmpty) {
      return const Center(
        child: Text("No data", style: TextStyle(color: Colors.white54, fontSize: 10)),
      );
    }

    // Determine keys based on metricType
    String rateKey = 'dps';
    String totalKey = 'total';
    if (metricType == 'heal') {
      rateKey = 'hps';
      totalKey = 'totalHeal';
    } else if (metricType == 'taken') {
      rateKey = 'takenDps';
      totalKey = 'totalTaken';
    }

    // Sort
    filtered.sort((a, b) {
      final valA = (a[rateKey] as num?)?.toDouble() ?? 0.0;
      final valB = (b[rateKey] as num?)?.toDouble() ?? 0.0;
      return valB.compareTo(valA);
    });

    // Calculate Max for Progress Bar
    double maxVal = 0.0;
    if (filtered.isNotEmpty) {
      maxVal = (filtered.first[rateKey] as num?)?.toDouble() ?? 0.0;
    }
    if (maxVal == 0) maxVal = 1.0;

    return ListView.builder(
      itemCount: filtered.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final p = filtered[index];
        final cls = Classes.fromId(p['classId']);
        final val = (p[rateKey] as num?)?.toDouble() ?? 0.0;
        final total = (p[totalKey] as num?)?.toInt() ?? 0;
        final percent = (val / maxVal).clamp(0.0, 1.0);

        return Container(
          height: 24, // Compact row
          margin: const EdgeInsets.only(bottom: 1),
          child: Stack(
            children: [
              // Progress Bar Background
              FractionallySizedBox(
                widthFactor: percent,
                child: Container(
                  color: _getClassColor(cls).withValues(alpha: 0.3),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    // Class Icon/Color Indicator (Small)
                    Container(width: 2, color: _getClassColor(cls)),
                    const SizedBox(width: 4),
                    // Name
                    Expanded(
                      child: Text(
                        "${index + 1}. ${p['name']}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                          shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Values
                    Text(
                      "${_formatNumber(val)} / ${_formatNumber(total)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getClassColor(Classes cls) {
    switch (cls.role) {
      case Role.tank:
        return Colors.blue;
      case Role.heal:
        return Colors.green;
      case Role.dps:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatNumber(num number) {
    if (number >= 1000000) {
      double val = number / 1000000;
      String s = val < 100 ? val.toStringAsFixed(2) : val.toStringAsFixed(1);
      return "${s}m";
    }
    if (number >= 1000) {
      double val = number / 1000;
      String s = val < 100 ? val.toStringAsFixed(2) : val.toStringAsFixed(1);
      return "${s}k";
    }
    return number.toStringAsFixed(0);
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
  late PacketAnalyzerV2 _packetAnalyzer;
  Timer? _overlayUpdateTimer;
  ReceivePort? _receivePort;

  @override
  void initState() {
    super.initState();
    _packetAnalyzer = PacketAnalyzerV2(DataStorage());
    
    // Setup communication port
    _receivePort = ReceivePort();
    IsolateNameServer.removePortNameMapping('overlay_communication_port'); // Clean up old mapping if any
    IsolateNameServer.registerPortWithName(_receivePort!.sendPort, 'overlay_communication_port');
    _receivePort!.listen((message) {
      if (message == "RESET") {
        DataStorage().reset();
      }
    });

    // DataStorage().addListener(_updateOverlay);
    // Update overlay at 2 FPS (500ms) to prevent log spam and UI overload
    _overlayUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _updateOverlay();
    });
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping('overlay_communication_port');
    _receivePort?.close();
    // DataStorage().removeListener(_updateOverlay);
    _overlayUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _updateOverlay() async {
    final storage = DataStorage();
    final playersFutures = storage.fullDpsDatas.entries
    .where((e) => e.value.totalAttackDamage > Int64.ZERO || e.value.totalHeal > Int64.ZERO || e.value.totalTakenDamage > Int64.ZERO)
    .map((e) async {
      final uid = e.key;
      final dpsData = e.value;
      final info = await storage.getPlayerInfo(uid);
      // if (uid == storage.currentPlayerUuid) {
      //    debugPrint("[BM Main] Sending Overlay Update for Me ($uid): Name=${info?.name}, DPS=${dpsData.simpleDps}");
      // }
      return {
        'name': info?.name ?? "Unknown (${uid.toString()})",
        'isMe': uid == storage.currentPlayerUuid,
        'classId': info?.professionId ?? 0,
        'dps': dpsData.simpleDps,
        'total': dpsData.totalAttackDamage.toInt(),
        'hps': dpsData.simpleHps,
        'totalHeal': dpsData.totalHeal.toInt(),
        'takenDps': dpsData.simpleTakenDps,
        'totalTaken': dpsData.totalTakenDamage.toInt(),
        'level': info?.level ?? 0,
      };
    });

    final players = await Future.wait(playersFutures);

    // Sort by DPS by default, but we send all data so the overlay can sort based on tab
    // Actually, sorting logic should probably be in the overlay if it changes per tab.
    // But here we just send the list.
    
    FlutterOverlayWindow.shareData(players);
  }

  Future<void> _onPacketData(dynamic event) async {
    // debugPrint("Received packet data: ${event.runtimeType}");
    if (event is Uint8List) {
      // debugPrint("Processing ${event.length} bytes");
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

  Future<void> _startOverlay() async {
    final bool status = await FlutterOverlayWindow.isPermissionGranted();
    if (!status) {
      await FlutterOverlayWindow.requestPermission();
      return;
    }

    if (await FlutterOverlayWindow.isActive()) return;

    await FlutterOverlayWindow.showOverlay(
      enableDrag: false, // Disable native drag to allow content interaction
      overlayTitle: "BlueMeter DPS",
      overlayContent: "DPS Meter Active",
      flag: OverlayFlag.defaultFlag,
      alignment: OverlayAlignment.topLeft,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.none,
      height: 400,
      width: 600,
    );
    
    // Move to a safe initial position (logical pixels)
    await Future.delayed(const Duration(milliseconds: 100));
    await FlutterOverlayWindow.moveOverlay(
      const OverlayPosition(0, 100),
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
}
