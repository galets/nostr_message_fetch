import 'dart:io';
import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class TaskService {
  ReceivePort? notifyPort;

  void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_task',
        channelName: 'Foreground Task Icon',
        channelDescription: 'This notification icon is necessary to keep an app running.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        visibility: NotificationVisibility.VISIBILITY_SECRET,
        showWhen: false,
        iconData: NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 30000,
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<bool> start() async {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      return false;
    }

    if (!await FlutterForegroundTask.canDrawOverlays) {
      final isGranted = await FlutterForegroundTask.openSystemAlertWindowSettings();
      if (!isGranted) {
        print('SYSTEM_ALERT_WINDOW permission denied!');
        return false;
      }
    }

    bool reqResult;
    if (await FlutterForegroundTask.isRunningService) {
      print("service was already running, restarting...");
      reqResult = await FlutterForegroundTask.restartService();
    } else {
      reqResult = await FlutterForegroundTask.startService(
        notificationTitle: 'Nostr message listener is running',
        notificationText: 'Tap to return to the app',
        callback: startCallback,
      );
    }

    notifyPort = await FlutterForegroundTask.receivePort;

    return true;
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {}

  @override
  Future<void> onEvent(DateTime timestamp, SendPort? sendPort) async {
    if (sendPort != null) {
      sendPort.send("ping");
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {}
}
