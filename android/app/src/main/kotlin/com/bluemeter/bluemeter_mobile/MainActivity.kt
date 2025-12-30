package com.bluemeter.bluemeter_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.VpnService
import android.os.Build
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.bluemeter.mobile/vpn"
    private val EVENT_CHANNEL = "com.bluemeter.mobile/packet_stream"
    private var eventSink: EventChannel.EventSink? = null

    private val packetReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.bluemeter.mobile.PACKET_DATA") {
                val data = intent.getByteArrayExtra("data")
                if (data != null) {
                    eventSink?.success(data)
                }
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "startVpn") {
                val intent = VpnService.prepare(this)
                if (intent != null) {
                    startActivityForResult(intent, 0)
                } else {
                    onActivityResult(0, -1, null)
                }
                result.success(null)
            } else if (call.method == "stopVpn") {
                val intent = Intent(this, PacketCaptureService::class.java)
                intent.action = "STOP"
                startService(intent)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    val filter = IntentFilter("com.bluemeter.mobile.PACKET_DATA")
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        registerReceiver(packetReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
                    } else {
                        registerReceiver(packetReceiver, filter)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    unregisterReceiver(packetReceiver)
                    eventSink = null
                }
            }
        )
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == 0 && resultCode == -1) {
            val intent = Intent(this, PacketCaptureService::class.java)
            startService(intent)
        }
        super.onActivityResult(requestCode, resultCode, data)
    }
}
