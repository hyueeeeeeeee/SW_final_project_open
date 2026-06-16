import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart'; // To access global navigator key if needed, or we can use a callback

class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  
  // Callback for when a notification is tapped
  void Function(Map<String, dynamic> payload)? onNotificationTapped;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    // Initialize native android notification
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Initialize native ios notification
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          try {
            final payloadData = jsonDecode(response.payload!);
            if (onNotificationTapped != null) {
              onNotificationTapped!(payloadData);
            }
          } catch (e) {
            print("Error parsing notification payload: $e");
          }
        }
      },
    );

    _initialized = true;
    _requestIOSPermissions();
    _listenToPracticeTasks();
  }

  Future<void> _requestIOSPermissions() async {
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  void _listenToPracticeTasks() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        final now = DateTime.now();
        final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('practiceTasks')
            .where('dayId', isGreaterThanOrEqualTo: todayStr)
            .snapshots()
            .listen((snapshot) {
              
          _syncNotifications(snapshot.docs);
        });
      }
    });
  }

  Future<void> _syncNotifications(List<QueryDocumentSnapshot> docs) async {
    await cancelAllNotifications();
    int idCounter = 0;
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final startTimeStr = data['startTime'] as String?;
      final dayId = data['dayId'] as String?;
      if (startTimeStr != null && dayId != null) {
        try {
          final parts = startTimeStr.split(':');
          if (parts.length == 2) {
            final hour = int.parse(parts[0]);
            final minute = int.parse(parts[1]);
            final dateParts = dayId.split('-');
            final year = int.parse(dateParts[0]);
            final month = int.parse(dateParts[1]);
            final day = int.parse(dateParts[2]);

            final scheduledTime = DateTime(year, month, day, hour, minute);
            
            // Only schedule if it's in the future
            if (scheduledTime.isAfter(DateTime.now())) {
              await schedulePracticeReminder(
                id: idCounter++,
                title: 'It\'s time to practice! 🎸',
                body: 'Your scheduled session for ${data['title'] ?? 'guitar'} is starting.',
                scheduledTime: scheduledTime,
                payload: {
                  'type': 'practice',
                  'title': data['title'] ?? 'Practice Session',
                  'artist': data['artist'] ?? '',
                  'bpm': data['bpm'] ?? 100,
                  'videoId': data['videoId'] ?? '',
                  'songId': data['songId'] ?? '',
                },
              );
            }
          }
        } catch (e) {
          print("Error parsing schedule time: $e");
        }
      }
    }
  }

  /// Cancels all scheduled notifications
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Schedules a practice reminder
  Future<void> schedulePracticeReminder(
      {required int id, required String title, required String body, required DateTime scheduledTime, required Map<String, dynamic> payload}) async {
    
    // Don't schedule for past times
    if (scheduledTime.isBefore(DateTime.now())) {
      return;
    }

    final location = tz.getLocation('Asia/Taipei');
    final tzScheduledTime = tz.TZDateTime.from(scheduledTime, location);

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'practice_reminders',
      'Practice Reminders',
      channelDescription: 'Reminders for your scheduled guitar practice sessions',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const DarwinNotificationDetails iosNotificationDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics, iOS: iosNotificationDetails);

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduledTime,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode(payload),
    );
    print("Scheduled notification #$id for $tzScheduledTime");
  }

  // Helper method to schedule a notification 5 seconds from now (for testing)
  Future<void> scheduleTestNotification() async {
    String songId = 'mock_song_123';
    String title = 'Wonderwall';
    String artist = 'Oasis';
    int bpm = 87;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('songLibrary')
            .orderBy('addedAt', descending: true)
            .limit(1)
            .get();

        if (snap.docs.isNotEmpty) {
          final data = snap.docs.first.data();
          songId = snap.docs.first.id;
          title = data['title'] ?? title;
          artist = data['artist'] ?? artist;
          bpm = data['bpm'] ?? bpm;
        }
      }
    } catch (e) {
      print("Error fetching recent song: $e");
    }

    final payload = {
      'type': 'practice',
      'songId': songId,
      'title': title,
      'artist': artist,
      'bpm': bpm,
    };

    if (kIsWeb) {
      print("Simulating Web Notification (Bypassing permission issues)...");
      Future.delayed(const Duration(seconds: 1), () {
        if (onNotificationTapped != null) {
          onNotificationTapped!(payload);
        }
      });
      return;
    }

    await schedulePracticeReminder(
      id: 999,
      title: 'It\'s time to practice! 🎸',
      body: 'Grab your guitar and let\'s rock $title!',
      scheduledTime: DateTime.now().add(const Duration(seconds: 5)),
      payload: payload,
    );
  }
}
