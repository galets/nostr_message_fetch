import 'dart:convert';
import 'dart:io';
import 'package:nostr/nostr.dart';

import 'config.dart';
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

  late WebSocket _relay;
  late Config _config;
  final _subscriptionId = generate64RandomHexChars();

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
      rethrow;
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
    final nip04 = Nip04(_config.privateKey);

    await _restoreMessages();

    print('starting fetcher...');
    _relay = await WebSocket.connect(
      _config.relay, // or any nostr relay
    );

    final filter = Request(_subscriptionId, [
      Filter(
          kinds: [4],
          p: [getPublicKeyFromPrivate(_config.privateKey)],
          authors: _config.senders.isEmpty ? null : _config.senders.keys.toList())
    ]);

    _relay.add(filter.serialize());
    await Future.delayed(Duration(seconds: 1));

    _relay.listen((payload) async {
      print('Received event: $payload');
      final message = Message.deserialize(payload);
      if (message.type != "EVENT") {
        return;
      }

      final event = message.message as Event;
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

        var msg = SecureMessage(event.id, DateTime.fromMicrosecondsSinceEpoch(event.createdAt), from, text);
        messages[event.id] = msg;
        getMessageStream().add(msg);

        commit();
      } catch (e) {
        print(e);
      }
    });

    print('subscribed with id $_subscriptionId');

    return true;
  }

  Future<void> stop() async {
    if (_relay.readyState == WebSocket.open) {
      await _relay.close();
    }
  }

  Future<void> refreshConnection() async {
    if (_relay.readyState != WebSocket.open) {
      print("Relay was disconnected, will restart");
      await stop();
      await start(await loadConfig());
    }
  }
}
