import 'dart:convert';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_message_fetch/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:json_annotation/json_annotation.dart';
import 'factory.dart';
import 'nip04.dart';

part 'fetcher.g.dart';

@JsonSerializable()
class SecureMessage {
  final String id;
  final String from;
  final String text;
  final DateTime createdAt;
  bool isRead;
  bool isSeen;

  SecureMessage(this.id, this.createdAt, this.from, this.text, [this.isRead = false, this.isSeen = false]);
  factory SecureMessage.fromJson(Map<String, dynamic> json) => _$SecureMessageFromJson(json);
  Map<String, dynamic> toJson() => _$SecureMessageToJson(this);
}

class Fetcher {
  var messages = Map<String, SecureMessage>();

  late Relay _relay;
  late Config _config;

  List<SecureMessage> getMessages() {
    return messages.values.toList();
  }

  Future<void> _restoreMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString("messages");
      if (null == json) {
        return;
      }
      final List<dynamic> events = jsonDecode(json);
      for (var e in events) {
        try {
          final msg = SecureMessage.fromJson(e);
          if (!messages.containsKey(msg.id)) {
            messages[msg.id] = msg;
            getMessageStream().add(msg);
          }
        } catch (e) {
          print(e);
        }
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> commit() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(messages.values.toList());
    await prefs.setString("messages", json);
  }

  Future<bool> start(Config config) async {
    if (config.privateKey.isEmpty) {
      return false;
    }

    _config = config;
    _relay = Relay(_config.relay);
    final nip04 = Nip04(_config.privateKey);

    await _restoreMessages();

    print('starting fetcher...');
    _relay.connect();

    final filter = Filter(kinds: [4], authors: _config.senders.isEmpty ? null : _config.senders.keys.toList());

    _relay.stream.whereIsEvent().listen((event) async {
      print('Received event from: ${event.pubkey}');

      try {
        if (messages.containsKey(event.id)) {
          return;
        }

        final senders = config.senders;
        late String from;
        if (_config.senders.isEmpty) {
          from = event.pubkey.substring(0, 12);
        } else {
          if (!senders.containsKey(event.pubkey)) {
            throw Exception("sender unknown");
          }
          from = senders[event.pubkey]!;
        }

        final text = nip04.decryptContent(event);

        var msg = SecureMessage(event.id, event.createdAt, from, text);
        messages[event.id] = msg;
        getMessageStream().add(msg);

        commit();
      } catch (e) {
        print(e);
      }
    });

    print('subing');
    final subscriptionId = _relay.subscribe(filter);
    print('suid $subscriptionId');

    return true;
  }

  void stop() {
    if (_relay.isConnected) {
      _relay.disconnect();
    }
  }
}
