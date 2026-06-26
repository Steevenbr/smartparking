// lib/services/push_notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';

class PushNotificationService {
  // RF-16: Notificaciones
  void initialize() {
    FirebaseMessaging.instance.requestPermission();
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Manejar notificaciones en primer plano
    });
  }
}