import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'app.dart';
import 'firebase_options.dart';

/// Global notification response for handling app launch from notification.
NotificationResponse? initialNotificationResponse;

/// Stream for notification taps while app is running.
final StreamController<String> notificationTapStream =
    StreamController<String>.broadcast();

/// Initialize local notifications before the app starts.
Future<void> _initializeNotifications() async {
  // Initialize timezone data
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Zurich'));

  final notifications = FlutterLocalNotificationsPlugin();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  const settings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await notifications.initialize(
    settings: settings,
    onDidReceiveNotificationResponse: (response) {
      debugPrint('Notification tapped: ${response.payload}');
      if (response.payload != null) {
        notificationTapStream.add(response.payload!);
      }
    },
  );

  // Check if app was launched from a notification
  final details = await notifications.getNotificationAppLaunchDetails();
  if (details?.didNotificationLaunchApp == true &&
      details?.notificationResponse != null) {
    initialNotificationResponse = details!.notificationResponse;
    debugPrint(
      'App launched from notification: ${initialNotificationResponse?.payload}',
    );
  }
}

void main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Initialize notifications early to handle launch notifications
      await _initializeNotifications();

      // Configure Crashlytics
      if (!kDebugMode) {
        // Pass all uncaught Flutter errors to Crashlytics
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;
      }

      runApp(const ProviderScope(child: WealthApp()));
    },
    (error, stack) {
      // Pass all uncaught async errors to Crashlytics
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
    },
  );
}
