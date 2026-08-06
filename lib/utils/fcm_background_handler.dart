import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_master_app/config/app_config.dart';

/// Background message handler for Firebase Cloud Messaging
/// This must be a top-level function
/// Handles notifications when app is in background or terminated state
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase already initialized or error: $e');
  }

  debugPrint('📨 Background message received: ${message.messageId}');
  debugPrint('📨 Message data: ${message.data}');

  final data = message.data;
  debugPrint('================ FCM RECEIVED (BACKGROUND/TERMINATED) ================');
  debugPrint('📦 Raw message.toMap(): ${message.toMap()}');
  debugPrint('📝 Title: ${message.notification?.title}');
  debugPrint('📝 Body: ${message.notification?.body}');
  debugPrint('📋 Data: $data');
  debugPrint('🆔 MessageId: ${message.messageId}');
  debugPrint('🆔 OrderId: ${data['orderId'] ?? data['order_id'] ?? data['id']}');
  debugPrint('🏷️ Type: ${data['type']}');
  debugPrint('👤 UserId: ${data['userId'] ?? data['user_id']}');
  debugPrint('🚚 DeliveryPartnerId: ${data['deliveryPartnerId'] ?? data['delivery_partner_id'] ?? data['partnerId'] ?? data['riderId']}');
  debugPrint('📱 App State: background/terminated');
  debugPrint('========================================================================');

  // Notify overlay if this is a new order
  // You can customize the condition based on your backend FCM payload
  final type = message.data['type']?.toString();
  final isOrder = type == 'order' || 
                  type == 'NEW_ORDER' ||
                  type == 'new_order_available' ||
                  (message.notification?.title?.toLowerCase().contains('order') ?? false) ||
                  (message.notification?.body?.toLowerCase().contains('order') ?? false);

  debugPrint('🔊 Background Notification check - type: $type, title: ${message.notification?.title}, body: ${message.notification?.body}');
  debugPrint('🔊 Background isOrder matched: $isOrder -> ${isOrder ? "WILL PLAY RING SOUND" : "WILL NOT PLAY RING SOUND"}');

  if (isOrder) {
    try {
      debugPrint('🔔 New order detected, notifying overlay...');
      await FlutterOverlayWindow.shareData(jsonEncode({
        'type': 'NEW_ORDER',
        'orderId': message.data['orderId'] ?? message.data['id'],
        'title': message.notification?.title ?? 'New Order',
        'body': message.notification?.body ?? 'You have a new delivery order',
      }));
    } catch (e) {
      debugPrint('❌ Failed to notify overlay or auto-open app: $e');
    }
  }

  // Initialize notification plugin for background messages
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Use AppConfig for consistency
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings(AppConfig.notificationIcon);

  const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await notificationsPlugin.initialize(initSettings);

  // Create notification channel for Android using AppConfig
  final AndroidNotificationChannel standardChannel = AndroidNotificationChannel(
    AppConfig.notificationChannelId,
    AppConfig.notificationChannelName,
    description: AppConfig.notificationChannelDescription,
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    showBadge: true,
    enableLights: true,
    ledColor: AppConfig.notificationColor,
  );

  final AndroidNotificationChannel criticalChannel = AndroidNotificationChannel(
    AppConfig.criticalChannelId,
    AppConfig.criticalChannelName,
    description: AppConfig.criticalChannelDescription,
    importance: Importance.max,
    playSound: true,
    sound: const RawResourceAndroidNotificationSound(AppConfig.notificationSoundName),
    enableVibration: true,
    showBadge: true,
    enableLights: true,
    ledColor: Colors.red,
  );

  final androidImpl = notificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
          
  await androidImpl?.createNotificationChannel(standardChannel);
  await androidImpl?.createNotificationChannel(criticalChannel);

  RemoteNotification? notification = message.notification;

  // Create unique ID for this notification
  final String notificationId = message.messageId ??
      '${message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}';

  debugPrint('📨 Background notification ID: $notificationId');

  // Handle notification payload (when app is in background/terminated)
  if (notification != null) {
    // Android notification details using AppConfig
    final AndroidNotificationDetails androidDetails = isOrder
      ? AndroidNotificationDetails(
          AppConfig.criticalChannelId,
          AppConfig.criticalChannelName,
          channelDescription: AppConfig.criticalChannelDescription,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound(AppConfig.notificationSoundName),
          enableVibration: true,
          fullScreenIntent: true,
          ongoing: false,
          autoCancel: true,
          additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT = 4 (loops sound)
          icon: AppConfig.notificationIcon,
          showWhen: true,
          styleInformation: const BigTextStyleInformation(''),
          color: Colors.red,
        )
      : AndroidNotificationDetails(
          AppConfig.notificationChannelId, // Must match channel ID
          AppConfig.notificationChannelName,
          channelDescription: AppConfig.notificationChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: AppConfig.notificationIcon,
          showWhen: true,
          styleInformation: const BigTextStyleInformation(''),
          color: AppConfig.notificationColor,
        );

    // iOS notification details
    final DarwinNotificationDetails iosDetails = isOrder
      ? DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: '${AppConfig.notificationSoundName}.mp3',
          interruptionLevel: InterruptionLevel.critical,
        )
      : const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Show notification
    // Use a hash of the notification ID to generate a consistent integer ID
    // This prevents duplicate notifications even if the same message is processed multiple times
    final int localNotificationId = notificationId.hashCode.abs() % 2147483647;
    
    // Workaround for Android notification rate limiting (1 sound per second per package)
    // If FCM auto-created a notification, it played the default sound.
    // If we immediately create another one, Android suppresses our custom sound.
    if (isOrder) {
      await Future.delayed(const Duration(milliseconds: 1500));
    }
    
    // Clear Firebase's auto-generated notification to prevent duplicates
    await notificationsPlugin.cancelAll();

    await notificationsPlugin.show(
      localNotificationId,
      notification.title ?? 'Notification',
      notification.body ?? '',
      notificationDetails,
      payload: data.toString(),
    );

    debugPrint(
        '✅ Background notification shown: ${notification.title} (ID: $localNotificationId)');
  } else if (data.isNotEmpty) {
    // Handle data-only messages (messages without notification payload)
    debugPrint('📨 Data-only message received in background');
    final title = data['title']?.toString() ?? (isOrder ? 'New Order' : 'Notification');
    final body = data['body']?.toString() ?? data['message']?.toString() ?? (isOrder ? 'You have a new delivery order' : '');

    // Android notification details using AppConfig
    final AndroidNotificationDetails androidDetails = isOrder
      ? AndroidNotificationDetails(
          AppConfig.criticalChannelId,
          AppConfig.criticalChannelName,
          channelDescription: AppConfig.criticalChannelDescription,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound(AppConfig.notificationSoundName),
          enableVibration: true,
          fullScreenIntent: true,
          ongoing: false,
          autoCancel: true,
          additionalFlags: Int32List.fromList([4]),
          icon: AppConfig.notificationIcon,
          showWhen: true,
          styleInformation: const BigTextStyleInformation(''),
          color: Colors.red,
        )
      : AndroidNotificationDetails(
          AppConfig.notificationChannelId,
          AppConfig.notificationChannelName,
          channelDescription: AppConfig.notificationChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: AppConfig.notificationIcon,
          showWhen: true,
          styleInformation: const BigTextStyleInformation(''),
          color: AppConfig.notificationColor,
        );

    // iOS notification details
    final DarwinNotificationDetails iosDetails = isOrder
      ? DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: '${AppConfig.notificationSoundName}.mp3',
          interruptionLevel: InterruptionLevel.critical,
        )
      : const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Generate notification ID from data
    final int localNotificationId = notificationId.hashCode.abs() % 2147483647;

    if (isOrder) {
      await Future.delayed(const Duration(milliseconds: 1500));
    }

    // Clear any previous notifications
    await notificationsPlugin.cancelAll();

    await notificationsPlugin.show(
      localNotificationId,
      title,
      body,
      notificationDetails,
      payload: data.toString(),
    );

    debugPrint(
        '✅ Background data-only notification shown: $title (ID: $localNotificationId)');
  }

  // Auto-open application if it's an order
  if (isOrder) {
    // Wait a brief moment to ensure notification is firmly placed in system tray
    // before pulling the app to the foreground
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      debugPrint('🚀 Auto-opening application for order...');
      await LaunchApp.openApp(
        androidPackageName: 'com.dadexpress.delivery',
        openStore: false,
      );
    } catch (e) {
      debugPrint('❌ Failed to auto-open app: $e');
    }
  }
}
