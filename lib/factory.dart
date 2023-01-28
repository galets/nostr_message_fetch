import 'dart:async';
import 'dart:convert';
import 'package:nostr_message_fetch/nip04.dart';
import 'package:nostr_message_fetch/services/local_notification_service.dart';
import 'package:nostr_message_fetch/services/task_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'fetcher.dart';

final _taskService = TaskService();

TaskService getTaskService() {
  return _taskService;
}

final _localNotificationService = LocalNotificationService();

LocalNotificationService getLocalNotificationService() {
  return _localNotificationService;
}

Fetcher _fetcher = Fetcher();

Fetcher getFetcher() {
  return _fetcher;
}

final _messageStream = StreamController<SecureMessage>.broadcast();

StreamController<SecureMessage> getMessageStream() {
  return _messageStream;
}

final Config _defaultConfig = Config(privateKey: generatePrivateKey(), relay: 'wss://relay.sendstr.com', senders: {});

Future<Config> loadConfig() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString("config");
    if (null == json) {
      await saveConfig(_defaultConfig);
      return _defaultConfig;
    }
    return Config.fromJson(jsonDecode(json));
  } catch (e) {
    print(e);
    return _defaultConfig;
  }
}

Future<void> saveConfig(Config config) async {
  final prefs = await SharedPreferences.getInstance();
  final json = jsonEncode(config);
  await prefs.setString("config", json);
}
