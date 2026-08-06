// import 'package:flutter/material.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:webview_master_app/services/api_service.dart';
// import 'package:webview_master_app/config/app_config.dart';
// import 'dart:io' show Platform;
// import 'dart:convert';
// import 'package:flutter_overlay_window/flutter_overlay_window.dart';

// /// Notification Service - Handles system tray notifications
// class NotificationService {
//   static final NotificationService _instance = NotificationService._internal();

//   factory NotificationService() => _instance;

//   NotificationService._internal();

//   final FlutterLocalNotificationsPlugin _notificationsPlugin =
//       FlutterLocalNotificationsPlugin();

//   FirebaseMessaging? _firebaseMessaging;

//   bool _isInitialized = false;

//   // Track shown notifications to prevent duplicates
//   final Set<String> _shownNotificationIds = <String>{};
//   final Map<String, DateTime> _notificationTimestamps = <String, DateTime>{};

//   /// Initialize notification service
//   Future<void> initialize() async {
//     if (_isInitialized) return;

//     // Android initialization settings
//     const AndroidInitializationSettings androidSettings =
//         AndroidInitializationSettings(AppConfig.notificationIcon);

//     // iOS initialization settings
//     const DarwinInitializationSettings iosSettings =
//         DarwinInitializationSettings(
//       requestAlertPermission: true,
//       requestBadgePermission: true,
//       requestSoundPermission: true,
//     );

//     // Combined initialization settings
//     const InitializationSettings initSettings = InitializationSettings(
//       android: androidSettings,
//       iOS: iosSettings,
//     );

//     // Initialize the plugin
//     await _notificationsPlugin.initialize(
//       initSettings,
//       onDidReceiveNotificationResponse: _onNotificationTapped,
//     );

//     // Create notification channel for Android
//     await _createNotificationChannel();

//     // Initialize Firebase Messaging
//     await _initializeFirebaseMessaging();

//     _isInitialized = true;
//     debugPrint('✅ Notification service initialized');
//   }

//   /// Initialize Firebase Cloud Messaging
//   Future<void> _initializeFirebaseMessaging() async {
//     try {
//       _firebaseMessaging = FirebaseMessaging.instance;

//       // Request notification permission for iOS (Android permissions handled via PermissionHandler)
//       if (Platform.isIOS) {
//         NotificationSettings settings =
//             await _firebaseMessaging!.requestPermission(
//           alert: true,
//           badge: true,
//           sound: true,
//           provisional: false,
//         );

//         if (settings.authorizationStatus == AuthorizationStatus.authorized) {
//           debugPrint('✅ Firebase notification permission granted (iOS)');
//         } else if (settings.authorizationStatus ==
//             AuthorizationStatus.provisional) {
//           debugPrint(
//               '⚠️ Firebase notification permission granted provisionally (iOS)');
//         } else {
//           debugPrint('❌ Firebase notification permission denied (iOS)');
//         }
//       }

//       // Get FCM token
//       String? token = await _firebaseMessaging!.getToken();
//       if (token != null) {
//         debugPrint('📱 FCM Token: $token');
//       } else {
//         debugPrint('⚠️ FCM Token is null');
//       }

//       // Listen for token refresh
//       _firebaseMessaging!.onTokenRefresh.listen((newToken) {
//         debugPrint('🔄 FCM Token refreshed: $newToken');
//       });

//       // Configure foreground message handler
//       FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//         debugPrint('📨 Foreground FCM message received: ${message.messageId}');
//         _handleForegroundMessage(message);
//       });

//       // Handle notification tap when app is opened from terminated state
//       FirebaseMessaging.instance
//           .getInitialMessage()
//           .then((RemoteMessage? message) {
//         if (message != null) {
//           debugPrint('📨 App opened from notification: ${message.messageId}');
//         }
//       });

//       debugPrint('✅ Firebase Messaging initialized');
//     } catch (e, stackTrace) {
//       debugPrint('❌ Error initializing Firebase Messaging: $e');
//       debugPrint('❌ Stack trace: $stackTrace');
//       // Continue even if Firebase fails - local notifications will still work
//     }
//   }

//   /// Handle foreground FCM messages
//   Future<void> _handleForegroundMessage(RemoteMessage message) async {
//     debugPrint('📨 Foreground message received: ${message.messageId}');
//     debugPrint('📨 Message data: ${message.data}');

//     RemoteNotification? notification = message.notification;
//     Map<String, dynamic>? data = message.data;

//     // Create unique ID for this notification
//     String notificationId = message.messageId ?? '';

//     // Clean old notification IDs (older than 5 minutes)
//     _cleanOldNotificationIds();

//     // Notify overlay if this is a new order
//     final isOrder = data['type'] == 'order' || 
//                     data['type'] == 'NEW_ORDER' ||
//                     (notification?.title?.toLowerCase().contains('order') ?? false) ||
//                     (notification?.body?.toLowerCase().contains('order') ?? false);

//     if (isOrder) {
//       try {
//         debugPrint('🔔 Foreground order detected, notifying overlay...');
//         await FlutterOverlayWindow.shareData(jsonEncode({
//           'type': 'NEW_ORDER',
//           'orderId': data['orderId'] ?? data['id'],
//           'title': notification?.title ?? 'New Order',
//           'body': notification?.body ?? 'You have a new delivery order',
//         }));
//       } catch (e) {
//         debugPrint('❌ Failed to notify overlay in foreground: $e');
//       }
//     }

//     if (notification != null) {
//       debugPrint('📨 Notification title: ${notification.title}');
//       debugPrint('📨 Notification body: ${notification.body}');

//       // Create a unique ID - use messageId if available, otherwise create from content
//       final String uniqueId = notificationId.isNotEmpty
//           ? notificationId
//           : '${notification.title}_${notification.body}_${message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}';

//       // Check if this notification was already shown (prevent duplicates)
//       if (_shownNotificationIds.contains(uniqueId)) {
//         debugPrint('⚠️ Duplicate notification detected, skipping: $uniqueId');
//         return;
//       }

//       // Mark as shown
//       _shownNotificationIds.add(uniqueId);
//       _notificationTimestamps[uniqueId] = DateTime.now();

//       // Ensure notification service is initialized
//       if (!_isInitialized) {
//         await initialize();
//       }

//       // Request permission if not granted
//       if (!await Permission.notification.isGranted) {
//         debugPrint('⚠️ Notification permission not granted, requesting...');
//         final granted = await requestPermission();
//         if (!granted) {
//           debugPrint(
//               '❌ Notification permission denied, cannot show notification');
//           return;
//         }
//       }

//       // Show notification
//       await showNotification(
//         title: notification.title ?? 'Notification',
//         body: notification.body ?? '',
//         payload: data.toString(),
//         imageUrl: notification.android?.imageUrl ??
//             notification.apple?.imageUrl?.toString(),
//         notificationId: uniqueId,
//       );
//     } else if (data.isNotEmpty) {
//       // Handle data-only messages
//       debugPrint('📨 Data-only message received');
//       final title = data['title']?.toString() ?? 'Notification';
//       final body =
//           data['body']?.toString() ?? data['message']?.toString() ?? '';

//       // Create unique ID for data-only messages
//       final String uniqueId = notificationId.isNotEmpty
//           ? notificationId
//           : '${title}_${body}_${message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}';

//       // Check for duplicates
//       if (_shownNotificationIds.contains(uniqueId)) {
//         debugPrint(
//             '⚠️ Duplicate data-only notification detected, skipping: $uniqueId');
//         return;
//       }

//       // Mark as shown
//       _shownNotificationIds.add(uniqueId);
//       _notificationTimestamps[uniqueId] = DateTime.now();

//       if (!_isInitialized) {
//         await initialize();
//       }

//       if (!await Permission.notification.isGranted) {
//         await requestPermission();
//       }

//       await showNotification(
//         title: title,
//         body: body,
//         payload: data.toString(),
//         notificationId: uniqueId,
//       );
//     }
//   }

//   /// Clean old notification IDs to prevent memory buildup
//   void _cleanOldNotificationIds() {
//     final now = DateTime.now();
//     final keysToRemove = <String>[];

//     _notificationTimestamps.forEach((id, timestamp) {
//       if (now.difference(timestamp).inMinutes > 5) {
//         keysToRemove.add(id);
//       }
//     });

//     for (final id in keysToRemove) {
//       _shownNotificationIds.remove(id);
//       _notificationTimestamps.remove(id);
//     }
//   }

//   /// Get FCM token
//   Future<String?> getFCMToken() async {
//     if (_firebaseMessaging == null) {
//       await _initializeFirebaseMessaging();
//     }
//     return await _firebaseMessaging?.getToken();
//   }

//   Future<bool> saveFCMTokenToBackend({
//     required String phone,
//     String? platform,
//   }) async {
//     try {
//       // Get FCM token
//       final token = await getFCMToken();

//       if (token == null || token.isEmpty) {
//         debugPrint('❌ Cannot save FCM token: Token is null or empty');
//         return false;
//       }

//       // Save to backend via API service
//       final success = await ApiService().saveFCMToken(
//         token: token,
//         phone: phone,
//         platform: platform,
//       );

//       if (success) {
//         debugPrint('✅ FCM token saved to backend successfully');
//       } else {
//         debugPrint('❌ Failed to save FCM token to backend');
//       }

//       return success;
//     } catch (e, stackTrace) {
//       debugPrint('❌ Error saving FCM token to backend: $e');
//       debugPrint('❌ Stack trace: $stackTrace');
//       return false;
//     }
//   }

//   /// Create Android notification channel
//   Future<void> _createNotificationChannel() async {
//     try {
//       const AndroidNotificationChannel channel = AndroidNotificationChannel(
//         AppConfig.notificationChannelId,
//         AppConfig.notificationChannelName,
//         description: AppConfig.notificationChannelDescription,
//         importance: Importance.high,
//         playSound: true,
//         enableVibration: true,
//         showBadge: true,
//         enableLights: true,
//         ledColor: AppConfig.notificationColor,
//       );

//       final androidImplementation =
//           _notificationsPlugin.resolvePlatformSpecificImplementation<
//               AndroidFlutterLocalNotificationsPlugin>();

//       if (androidImplementation != null) {
//         await androidImplementation.createNotificationChannel(channel);
//         debugPrint(
//             '✅ Notification channel created: ${AppConfig.notificationChannelId}');
//         debugPrint('   Channel importance: ${channel.importance}');
//         debugPrint('   Channel color: ${AppConfig.notificationColor}');
//       } else {
//         debugPrint('⚠️ Android notification plugin not available');
//       }
//     } catch (e) {
//       debugPrint('❌ Error creating notification channel: $e');
//     }
//   }

//   /// Handle notification tap
//   void _onNotificationTapped(NotificationResponse response) {
//     debugPrint('📱 Notification tapped: ${response.payload}');
//   }

//   /// Request notification permission
//   Future<bool> requestPermission() async {
//     try {
//       // Check current permission status
//       final currentStatus = await Permission.notification.status;
//       debugPrint('🔔 Current notification permission status: $currentStatus');

//       if (currentStatus.isGranted) {
//         debugPrint('✅ Notification permission already granted');
//         return true;
//       }

//       // For Android 13+, request permission
//       if (Platform.isAndroid) {
//         final status = await Permission.notification.request();
//         debugPrint('🔔 Permission request result: $status');

//         if (status.isGranted) {
//           debugPrint('✅ Notification permission granted');
//           return true;
//         } else if (status.isPermanentlyDenied) {
//           debugPrint('❌ Notification permission permanently denied');
//           debugPrint('⚠️ User needs to enable notifications in app settings');
//         } else {
//           debugPrint('❌ Notification permission denied');
//         }
//         return status.isGranted;
//       }

//       // For iOS, permissions are handled by Firebase
//       return currentStatus.isGranted;
//     } catch (e) {
//       debugPrint('❌ Error requesting notification permission: $e');
//       return false;
//     }
//   }

//   /// Show notification in system tray
//   Future<void> showNotification({
//     required String title,
//     required String body,
//     String? payload,
//     String? imageUrl,
//     String? notificationId,
//   }) async {
//     debugPrint('🔔 showNotification called - Title: "$title", Body: "$body"');

//     if (!_isInitialized) {
//       debugPrint('⚠️ Service not initialized, initializing now...');
//       await initialize();
//     }

//     // Check permission
//     final hasPermission = await Permission.notification.isGranted;
//     debugPrint('🔔 Permission status: $hasPermission');

//     if (!hasPermission) {
//       debugPrint('❌ Notification permission not granted');
//       debugPrint('⚠️ Requesting notification permission...');
//       final granted = await requestPermission();
//       if (!granted) {
//         debugPrint('❌ Cannot show notification - permission denied');
//         debugPrint('⚠️ Please enable notifications in Android Settings');
//         return;
//       }
//     }

//     // Generate notification ID - use provided ID or create one based on content
//     // This ensures duplicate notifications with same content use same ID and replace each other
//     final int localNotificationId;
//     if (notificationId != null && notificationId.isNotEmpty) {
//       // Use hash of the notification ID for consistent integer ID
//       localNotificationId = notificationId.hashCode.abs() % 2147483647;
//     } else {
//       // Fallback: create ID based on title and body to prevent duplicates of same content
//       final contentId = '${title}_$body';
//       localNotificationId = contentId.hashCode.abs() % 2147483647;
//     }

//     // Android notification details
//     final AndroidNotificationDetails androidDetails =
//         AndroidNotificationDetails(
//       AppConfig.notificationChannelId, // Must match channel ID
//       AppConfig.notificationChannelName, // Must match channel name
//       channelDescription: AppConfig.notificationChannelDescription,
//       importance: Importance.max,
//       priority: Priority.max,
//       playSound: true,
//       enableVibration: true,
//       icon: AppConfig.notificationIcon,
//       showWhen: true,
//       styleInformation: const BigTextStyleInformation(''),
//       color: AppConfig.notificationColor,
//       // Add buttons for Accept and Reject
//       actions: <AndroidNotificationAction>[
//         const AndroidNotificationAction(
//           'ACCEPT_ACTION',
//           'Accept',
//           showsUserInterface: true,
//           cancelNotification: true,
//         ),
//         const AndroidNotificationAction(
//           'REJECT_ACTION',
//           'Reject',
//           showsUserInterface: false,
//           cancelNotification: true,
//         ),
//       ],
//     );

//     // iOS notification details
//     const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
//       presentAlert: true,
//       presentBadge: true,
//       presentSound: true,
//     );

//     // Combined notification details
//     final NotificationDetails notificationDetails = NotificationDetails(
//       android: androidDetails,
//       iOS: iosDetails,
//     );

//     // Show the notification
//     try {
//       await _notificationsPlugin.show(
//         localNotificationId,
//         title,
//         body,
//         notificationDetails,
//         payload: payload,
//       );
//       debugPrint(
//           '✅ Notification displayed successfully - ID: $localNotificationId');
//     } catch (e, stackTrace) {
//       debugPrint('❌ Error showing notification: $e');
//       debugPrint('❌ Stack trace: $stackTrace');
//       rethrow;
//     }
//   }
// }
















import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:webview_master_app/services/api_service.dart';
import 'package:webview_master_app/config/app_config.dart';
import 'dart:io' show Platform;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_overlay_window/flutter_overlay_window.dart' hide NotificationVisibility;

/// Notification Service - Handles system tray notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  FirebaseMessaging? _firebaseMessaging;

  bool _isInitialized = false;
  static const _platform = MethodChannel('com.Dadexpress Delivery.restaurant/geolocation');

  // Track shown notifications to prevent duplicates
  final Set<String> _shownNotificationIds = <String>{};
  final Map<String, DateTime> _notificationTimestamps = <String, DateTime>{};

  // Stream for notification taps
  final _tapController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onTap => _tapController.stream;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Android initialization settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings(AppConfig.notificationIcon);

    // iOS initialization settings
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Combined initialization settings
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize the plugin
    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    await _createNotificationChannel();

    // Initialize Firebase Messaging
    await _initializeFirebaseMessaging();

    _isInitialized = true;
    debugPrint('✅ Notification service initialized');
  }

  /// Initialize Firebase Cloud Messaging
  Future<void> _initializeFirebaseMessaging() async {
    try {
      _firebaseMessaging = FirebaseMessaging.instance;

      // Request notification permission for iOS (Android permissions handled via PermissionHandler)
      if (Platform.isIOS) {
        NotificationSettings settings =
            await _firebaseMessaging!.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );

        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          debugPrint('✅ Firebase notification permission granted (iOS)');
        } else if (settings.authorizationStatus ==
            AuthorizationStatus.provisional) {
          debugPrint(
              '⚠️ Firebase notification permission granted provisionally (iOS)');
        } else {
          debugPrint('❌ Firebase notification permission denied (iOS)');
        }
      }

      // Get FCM token
      String? token = await _firebaseMessaging!.getToken();
      if (token != null) {
        debugPrint('📱 FCM Token: $token');
      } else {
        debugPrint('⚠️ FCM Token is null');
      }

      // Listen for token refresh
      _firebaseMessaging!.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM Token refreshed: $newToken');
      });

      // Configure foreground message handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📨 Foreground FCM message received: ${message.messageId}');
        _handleForegroundMessage(message);
      });

      // Handle notification tap when app is opened from terminated state
      FirebaseMessaging.instance
          .getInitialMessage()
          .then((RemoteMessage? message) {
        if (message != null) {
          debugPrint('📨 App opened from notification (terminated): ${message.messageId}');
          _handleNotificationTap(message.data);
        }
      });

      // Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('📨 App opened from notification (background): ${message.messageId}');
        _handleNotificationTap(message.data);
      });

      debugPrint('✅ Firebase Messaging initialized');
    } catch (e, stackTrace) {
      debugPrint('❌ Error initializing Firebase Messaging: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      // Continue even if Firebase fails - local notifications will still work
    }
  }

  /// Handle foreground FCM messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📨 Foreground message received: ${message.messageId}');
    debugPrint('📨 Message data: ${message.data}');

    RemoteNotification? notification = message.notification;
    Map<String, dynamic> data = message.data;

    debugPrint('================ FCM RECEIVED (FOREGROUND) ================');
    debugPrint('📦 Raw message.toMap(): ${message.toMap()}');
    debugPrint('📝 Title: ${notification?.title}');
    debugPrint('📝 Body: ${notification?.body}');
    debugPrint('📋 Data: $data');
    debugPrint('🆔 MessageId: ${message.messageId}');
    debugPrint('🆔 OrderId: ${data['orderId'] ?? data['order_id'] ?? data['id']}');
    debugPrint('🏷️ Type: ${data['type']}');
    debugPrint('👤 UserId: ${data['userId'] ?? data['user_id']}');
    debugPrint('🚚 DeliveryPartnerId: ${data['deliveryPartnerId'] ?? data['delivery_partner_id'] ?? data['partnerId'] ?? data['riderId']}');
    debugPrint('📱 App State: foreground');
    debugPrint('========================================================================');

    // Create unique ID for this notification
    String notificationId = message.messageId ?? '';

    // Create a unique ID - use messageId if available, otherwise create from content
    final String uniqueId = notificationId.isNotEmpty
        ? notificationId
        : '${notification?.title}_${notification?.body}_${message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}';

    // Clean old notification IDs (older than 5 minutes)
    _cleanOldNotificationIds();

    // Check if this notification was already shown (prevent duplicates)
    if (_shownNotificationIds.contains(uniqueId)) {
      debugPrint('⚠️ Duplicate notification detected, skipping: $uniqueId');
      return;
    }

    // Mark as shown
    _shownNotificationIds.add(uniqueId);
    _notificationTimestamps[uniqueId] = DateTime.now();

    // Notify overlay if this is a new order
    final isOrder = data['type'] == 'order' || 
                    data['type'] == 'NEW_ORDER' ||
                     data['type'] == 'new_order' ||
                     data['type'] == 'new_order_available' ||
                    (notification?.title?.toLowerCase().contains('order') ?? false) ||
                    (notification?.body?.toLowerCase().contains('order') ?? false);

    debugPrint('🔊 Foreground Notification check - type: ${data['type']}, title: ${notification?.title}, body: ${notification?.body}');
    debugPrint('🔊 Foreground isOrder matched: $isOrder -> ${isOrder ? "WILL PLAY RING SOUND" : "WILL NOT PLAY RING SOUND"}');

    if (isOrder) {
      // Show notification on critical channel
      await showOrderNotification(
        title: notification?.title ?? 'New Order',
        body: notification?.body ?? 'You have a new delivery order',
        payload: jsonEncode(data),
        notificationId: uniqueId,
      );
      return; // Skip standard notification handling
    }

    if (notification != null) {
      debugPrint('📨 Notification title: ${notification.title}');
      debugPrint('📨 Notification body: ${notification.body}');

      // Ensure notification service is initialized
      if (!_isInitialized) {
        await initialize();
      }

      // Request permission if not granted
      if (!await Permission.notification.isGranted) {
        debugPrint('⚠️ Notification permission not granted, requesting...');
        final granted = await requestPermission();
        if (!granted) {
          debugPrint(
              '❌ Notification permission denied, cannot show notification');
          return;
        }
      }

      // Show notification
      await showNotification(
        title: notification.title ?? 'Notification',
        body: notification.body ?? '',
        payload: jsonEncode(data),
        imageUrl: notification.android?.imageUrl ??
            notification.apple?.imageUrl?.toString(),
        notificationId: uniqueId,
      );
    } else if (data.isNotEmpty) {
      // Handle data-only messages
      debugPrint('📨 Data-only message received');
      final title = data['title']?.toString() ?? 'Notification';
      final body =
          data['body']?.toString() ?? data['message']?.toString() ?? '';

      if (!_isInitialized) {
        await initialize();
      }

      if (!await Permission.notification.isGranted) {
        await requestPermission();
      }

      await showNotification(
        title: title,
        body: body,
        payload: jsonEncode(data),
        notificationId: uniqueId,
      );
    }
  }

  /// Clean old notification IDs to prevent memory buildup
  void _cleanOldNotificationIds() {
    final now = DateTime.now();
    final keysToRemove = <String>[];

    _notificationTimestamps.forEach((id, timestamp) {
      if (now.difference(timestamp).inMinutes > 5) {
        keysToRemove.add(id);
      }
    });

    for (final id in keysToRemove) {
      _shownNotificationIds.remove(id);
      _notificationTimestamps.remove(id);
    }
  }

  /// Get FCM token
  Future<String?> getFCMToken() async {
    if (_firebaseMessaging == null) {
      await _initializeFirebaseMessaging();
    }
    return await _firebaseMessaging?.getToken();
  }

  Future<bool> saveFCMTokenToBackend({
    required String phone,
    String? platform,
  }) async {
    try {
      // Get FCM token
      final token = await getFCMToken();

      if (token == null || token.isEmpty) {
        debugPrint('❌ Cannot save FCM token: Token is null or empty');
        return false;
      }

      // Save to backend via API service
      final success = await ApiService().saveFCMToken(
        token: token,
        phone: phone,
        platform: platform,
      );

      if (success) {
        debugPrint('✅ FCM token saved to backend successfully');
      } else {
        debugPrint('❌ Failed to save FCM token to backend');
      }

      return success;
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving FCM token to backend: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return false;
    }
  }

  /// Create Android notification channel
  Future<void> _createNotificationChannel() async {
    try {
      // Create standard channel
      const AndroidNotificationChannel standardChannel = AndroidNotificationChannel(
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

      // Create critical channel for orders (with high importance and looping sound capability)
      const AndroidNotificationChannel criticalChannel = AndroidNotificationChannel(
        AppConfig.criticalChannelId,
        AppConfig.criticalChannelName,
        description: AppConfig.criticalChannelDescription,
        importance: Importance.max, // High priority
        playSound: true,
        sound: RawResourceAndroidNotificationSound(AppConfig.notificationSoundName),
        enableVibration: true,
        showBadge: true,
        enableLights: true,
        ledColor: Colors.red,
      );

      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        // Delete existing critical channel to ensure new settings (Importance.max, etc.) are applied
        await androidImplementation.deleteNotificationChannel(AppConfig.criticalChannelId);
        
        await androidImplementation.createNotificationChannel(standardChannel);
        await androidImplementation.createNotificationChannel(criticalChannel);
        debugPrint(
            '✅ Notification channels created: ${AppConfig.notificationChannelId}, ${AppConfig.criticalChannelId}');
      } else {
        debugPrint('⚠️ Android notification plugin not available');
      }
    } catch (e) {
      debugPrint('❌ Error creating notification channel: $e');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('📱 Local notification tapped: ${response.payload}');
    if (response.payload != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(response.payload!);
        _handleNotificationTap(data);
      } catch (e) {
        debugPrint('❌ Error parsing notification payload: $e');
        // If not JSON, maybe it's the old toString() format or a simple string
        _handleNotificationTap({'payload': response.payload});
      }
    } else {
      _handleNotificationTap({});
    }
  }

  /// Centralized notification tap handler
  void _handleNotificationTap(Map<String, dynamic> data) {
    debugPrint('🚀 Handling notification tap with data: $data');
    
    // Always bring app to front
    try {
      _platform.invokeMethod('bringToFront');
    } catch (e) {
      debugPrint('❌ Error bringing app to front: $e');
    }

    // Handle redirection if order details are present
    final orderId = data['orderId'] ?? data['order_id'] ?? data['id'];
    if (orderId != null) {
        debugPrint('📦 Order notification tapped, orderId: $orderId');
    }
    
    cancelAllOrderNotifications();

    _tapController.add(data);
  }

  /// Request notification permission
  Future<bool> requestPermission() async {
    try {
      // Check current permission status
      final currentStatus = await Permission.notification.status;
      debugPrint('🔔 Current notification permission status: $currentStatus');

      if (currentStatus.isGranted) {
        debugPrint('✅ Notification permission already granted');
        return true;
      }

      // For Android 13+, request permission
      if (Platform.isAndroid) {
        final status = await Permission.notification.request();
        debugPrint('🔔 Permission request result: $status');

        if (status.isGranted) {
          debugPrint('✅ Notification permission granted');
          return true;
        } else if (status.isPermanentlyDenied) {
          debugPrint('❌ Notification permission permanently denied');
          debugPrint('⚠️ User needs to enable notifications in app settings');
        } else {
          debugPrint('❌ Notification permission denied');
        }
        return status.isGranted;
      }

      // For iOS, permissions are handled by Firebase
      return currentStatus.isGranted;
    } catch (e) {
      debugPrint('❌ Error requesting notification permission: $e');
      return false;
    }
  }

  /// Show notification in system tray
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    String? imageUrl,
    String? notificationId,
  }) async {
    debugPrint('🔔 showNotification called - Title: "$title", Body: "$body"');

    if (!_isInitialized) {
      debugPrint('⚠️ Service not initialized, initializing now...');
      await initialize();
    }

    // Check permission
    final hasPermission = await Permission.notification.isGranted;
    debugPrint('🔔 Permission status: $hasPermission');

    if (!hasPermission) {
      debugPrint('❌ Notification permission not granted');
      debugPrint('⚠️ Requesting notification permission...');
      final granted = await requestPermission();
      if (!granted) {
        debugPrint('❌ Cannot show notification - permission denied');
        debugPrint('⚠️ Please enable notifications in Android Settings');
        return;
      }
    }

    // Generate notification ID - use provided ID or create one based on content
    // This ensures duplicate notifications with same content use same ID and replace each other
    final int localNotificationId;
    if (notificationId != null && notificationId.isNotEmpty) {
      // Use hash of the notification ID for consistent integer ID
      localNotificationId = notificationId.hashCode.abs() % 2147483647;
    } else {
      // Fallback: create ID based on title and body to prevent duplicates of same content
      final contentId = '${title}_$body';
      localNotificationId = contentId.hashCode.abs() % 2147483647;
    }

    // Android notification details
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      AppConfig.notificationChannelId, // Must match channel ID
      AppConfig.notificationChannelName, // Must match channel name
      channelDescription: AppConfig.notificationChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      icon: AppConfig.notificationIcon,
      showWhen: true,
      styleInformation: const BigTextStyleInformation(''),
      color: AppConfig.notificationColor,
      // Add buttons for Accept and Reject
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'ok',
          'ok',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        // const AndroidNotificationAction(
        //   'REJECT_ACTION',
        //   'Reject',
        //   showsUserInterface: false,
        //   cancelNotification: true,
        // ),
      ],
    );

    // iOS notification details
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Combined notification details
    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Show the notification
    try {
      await _notificationsPlugin.show(
        localNotificationId,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      debugPrint(
          '✅ Notification displayed successfully - ID: $localNotificationId');
    } catch (e, stackTrace) {
      debugPrint('❌ Error showing notification: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Show a simple notification without order actions (Accept/Reject)
  Future<void> showSimpleNotification({
    required String title,
    required String body,
    String? payload,
    String? notificationId,
  }) async {
    debugPrint('🔔 showSimpleNotification - Title: "$title", Body: "$body"');

    if (!_isInitialized) {
      await initialize();
    }

    final int localId = notificationId != null 
        ? notificationId.hashCode.abs() % 2147483647
        : DateTime.now().millisecondsSinceEpoch.hashCode.abs() % 2147483647;

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      AppConfig.notificationChannelId,
      AppConfig.notificationChannelName,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      icon: AppConfig.notificationIcon,
      showWhen: true,
      color: AppConfig.notificationColor,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      localId,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Show urgent order notification with looping sound
  Future<void> showOrderNotification({
    required String title,
    required String body,
    String? payload,
    String? notificationId,
  }) async {
    debugPrint('🔔 showOrderNotification (Urgent) - Title: "$title"');
    debugPrint('🔊 PLAYING RING SOUND for Order Notification. Payload: $payload');

    if (!_isInitialized) {
      await initialize();
    }

    // Generate a specific ID range for orders so we can cancel them all if needed
    // or use a consistent one
    final int localId = notificationId != null 
        ? (notificationId.hashCode.abs() % 1000000) + 1000000 // 1,000,000+ for orders
        : (DateTime.now().millisecondsSinceEpoch.hashCode.abs() % 1000000) + 1000000;

    // Android notification details with FLAG_INSISTENT for looping sound
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      AppConfig.criticalChannelId,
      AppConfig.criticalChannelName,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound(AppConfig.notificationSoundName),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]), // Custom vibration
      fullScreenIntent: true, // Show on lock screen
      ongoing: false, // Allow swipe to dismiss
      autoCancel: true, // Auto-cancel on tap
      additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT = 4 (loops sound)
      icon: AppConfig.notificationIcon,
      styleInformation: const BigTextStyleInformation(''),
      color: Colors.red,
      category: AndroidNotificationCategory.call, // Use call category for high focus
      showWhen: true,
      setAsGroupSummary: true,
      groupKey: 'new_orders_group',
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'ok',
          'ok',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        // const AndroidNotificationAction(
        //   'REJECT_ACTION',
        //   'Reject',
        //   showsUserInterface: false,
        //   cancelNotification: true,
        // ),
      ],
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: '${AppConfig.notificationSoundName}.mp3',
      interruptionLevel: InterruptionLevel.critical,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      localId,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Cancel all order notifications (stops the bell)
  Future<void> cancelAllOrderNotifications() async {
    debugPrint('🔔 Cancelling all order notifications...');
    // We can't easily cancel by "range", so we rely on the specific channel or just cancel all
    // Since this app is primarily for orders, cancelling all is often acceptable
    // or we can track order notification IDs
    await _notificationsPlugin.cancelAll();
  }
}
