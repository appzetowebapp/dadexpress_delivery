import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:webview_master_app/config/app_config.dart';

class OverlayBubble extends StatefulWidget {
  const OverlayBubble({super.key});

  @override
  State<OverlayBubble> createState() => _OverlayBubbleState();
}

class _OverlayBubbleState extends State<OverlayBubble> {
  static const platform = MethodChannel('com.dadexpress.delivery/geolocation');
  
  bool _hasIncomingOrder = false;
  String? _orderId;
  String? _orderTitle;
  String? _orderBody;

  @override
  void initState() {
    super.initState();
    _listenToMessages();
  }

  void _listenToMessages() {
    FlutterOverlayWindow.overlayListener.listen((data) {
      debugPrint('📩 Overlay received data: $data');
      try {
        if (data is String && data.startsWith('{')) {
          final Map<String, dynamic> jsonData = jsonDecode(data);
          if (jsonData['type'] == 'NEW_ORDER') {
            setState(() {
              _hasIncomingOrder = true;
              _orderId = jsonData['orderId']?.toString();
              _orderTitle = jsonData['title']?.toString() ?? 'New Order';
              _orderBody = jsonData['body']?.toString() ?? 'You have a new delivery order';
            });
            // Auto-expand overlay might be needed, but we rely on the 160x160 space
          } else if (jsonData['type'] == 'CLEAR_ORDER') {
            setState(() {
              _hasIncomingOrder = false;
            });
          }
        }
      } catch (e) {
        debugPrint('❌ Error parsing overlay data: $e');
      }
    });
  }

  Future<void> _openApp() async {
    try {
      debugPrint('🔵 Launching app directly...');
      await LaunchApp.openApp(
        androidPackageName: 'com.dadexpress.delivery',
        openStore: false,
      );
      await FlutterOverlayWindow.shareData("OPEN_APP");
    } catch (e) {
      debugPrint('❌ Error launching app: $e');
      await FlutterOverlayWindow.shareData("OPEN_APP");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
            child: _hasIncomingOrder ? _buildCompactBubble() : _buildCompactBubble(),
        // child: _hasIncomingOrder ? _buildOrderPopup() : _buildCompactBubble(),
      ),
    );
  }

  Widget _buildCompactBubble() {
    return GestureDetector(
      onTap: _openApp,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          // boxShadow: [
          //   BoxShadow(
          //     color: Colors.black.withOpacity(0.2),
          //     blurRadius: 10,
          //     spreadRadius: 2,
          //   ),
          // ],
          border: Border.all(
            color: AppConfig.primaryColor,
            width: 3,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                color: AppConfig.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              // child: Icon(
              //   Icons.delivery_dining,
              //   color: AppConfig.primaryColor,
              //   size: 35,
              // ),
                child:ClipOval(
                  // borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                  'assets/images/logo.png',
                  
                  // color: AppConfig.primaryColor,
                  // size: 35,
                ),)
            ),
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderPopup() {
    return Container(
      width: 150,
      height: 150,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 3,
          ),
        ],
        border: Border.all(
          color: AppConfig.primaryColor,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shopping_bag, color: Colors.orange, size: 30),
          const SizedBox(height: 5),
          Text(
            _orderTitle ?? 'New Order',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    debugPrint('✅ Order accepted from overlay');
                    await FlutterOverlayWindow.shareData(jsonEncode({
                      'action': 'ACCEPT_ORDER',
                      'orderId': _orderId,
                    }));
                    setState(() {
                      _hasIncomingOrder = false;
                    });
                    await _openApp();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Accept', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    debugPrint('❌ Order rejected from overlay');
                    await FlutterOverlayWindow.shareData(jsonEncode({
                      'action': 'REJECT_ORDER',
                      'orderId': _orderId,
                    }));
                    setState(() {
                      _hasIncomingOrder = false;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Reject', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
