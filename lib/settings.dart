import 'package:flutter/services.dart';
import 'package:nostr_message_fetch/nip04.dart';

import 'factory.dart';
import 'package:nostr_message_fetch/config.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

String _decorate(String? value) {
  return (value == null || value.isEmpty)
      ? 'Missing'
      : (value.length < 4)
          ? '???'
          : '${value.substring(0, 4)} ...';
}

final RegExp _privateKeyRegex = RegExp(r'^[0-9a-fA-F]{64}$');
final RegExp _publicKeyRegex = RegExp(r'^[0-9a-fA-F]{64}$');
final RegExp _webSocketUri = RegExp(r'^(wss|ws)://.+$');

class SettingsWidget extends StatefulWidget {
  const SettingsWidget({Key? key}) : super(key: key);

  @override
  State<SettingsWidget> createState() => _SettingsWidgetState();
}

class _SettingsWidgetState extends State<SettingsWidget> {
  void _updateConfig(Config c) {
    setState(() {
      saveConfig(c);
      getFetcher().start(c);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Nostr Message Receiver Settings')),
        body: FutureBuilder(
          future: loadConfig(),
          builder: (context, snapshot) {
            if (snapshot.data == null) {
              return const SpinKitCircle(color: Colors.blue);
            }

            final config = snapshot.data!;
            return SettingsList(
              sections: [
                SettingsSection(
                  title: const Text('Network'),
                  tiles: [
                    SettingsTile(
                      title: const Text('Relay'),
                      leading: const Icon(Icons.computer),
                      value: Text(config.relay),
                      onPressed: (BuildContext context) async {
                        var newRelay = await showRelayEditDialog(context, config.relay);
                        if (null != newRelay && newRelay.isNotEmpty && newRelay != config.relay) {
                          _updateConfig(
                              Config(privateKey: config.privateKey, relay: newRelay, senders: config.senders));
                        }
                      },
                    ),
                  ],
                ),
                SettingsSection(
                  title: const Text('Identity'),
                  tiles: [
                    SettingsTile(
                      title: const Text('Private Key'),
                      leading: const Icon(Icons.key),
                      value: Column(
                        children: [
                          Text(_decorate(config.privateKey)),
                          TextButton(
                            onPressed: () async {
                              final publicKey = getPublicKeyFromPrivate(config.privateKey);
                              await Clipboard.setData(ClipboardData(text: publicKey));
                              // ignore: use_build_context_synchronously
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text("Public key copied"),
                              ));
                            },
                            child: const Text('Copy Public Key'),
                          ),
                        ],
                      ),
                      onPressed: (BuildContext context) async {
                        var newPrivateKey = await showPrivateKeyEditDialog(context, config.privateKey);
                        if (null != newPrivateKey && newPrivateKey.isNotEmpty && newPrivateKey != config.privateKey) {
                          _updateConfig(
                              Config(privateKey: newPrivateKey, relay: config.relay, senders: config.senders));
                        }
                      },
                    ),
                  ],
                ),
                SettingsSection(
                  title: const Text('Senders'),
                  tiles: [
                    SettingsTile(
                      title: const Text('Allowed Senders'),
                      leading: const Icon(Icons.messenger),
                      value: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: config.senders.entries
                              .map((entry) => Row(
                                    children: [
                                      Expanded(flex: 2, child: Text(entry.value)),
                                      Expanded(flex: 4, child: Text(_decorate(entry.key))),
                                    ],
                                  ))
                              .toList()),
                      onPressed: (BuildContext context) async {
                        var newSenders = await Navigator.of(context)
                            .pushNamed('/settings/senders', arguments: config.senders) as Map<String, String>?;
                        if (null != newSenders && newSenders.isNotEmpty) {
                          _updateConfig(
                              Config(privateKey: config.privateKey, relay: config.relay, senders: newSenders));
                        }
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        ));
  }
}

Future<String?> showRelayEditDialog(BuildContext context, String initialValue) async {
  var relay = initialValue;
  final formKey = GlobalKey<FormState>();

  final ad = Form(
      key: formKey,
      child: AlertDialog(
        title: const Text('Relay'),
        content: TextFormField(
          initialValue: initialValue,
          validator: (value) {
            if (null == value || !_webSocketUri.hasMatch(value)) {
              return 'Please enter a ws: or wss: uri';
            }
            return null;
          },
          onSaved: (value) => relay = value ?? '',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState != null && formKey.currentState!.validate()) {
                formKey.currentState!.save();
                Navigator.pop(context, relay);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ));

  return await showDialog<String?>(context: context, builder: (context) => ad);
}

Future<String?> showPrivateKeyEditDialog(BuildContext context, String initialValue) async {
  var privateKey = initialValue;
  final formKey = GlobalKey<FormState>();

  final ad = Form(
      key: formKey,
      child: AlertDialog(
        title: const Text('Private Key'),
        content: TextFormField(
          initialValue: privateKey,
          obscureText: true,
          validator: (value) {
            if (null == value || !_privateKeyRegex.hasMatch(value)) {
              return 'Please enter a 64 character hex string';
            }
            return null;
          },
          onSaved: (value) => privateKey = value ?? '',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState != null && formKey.currentState!.validate()) {
                formKey.currentState!.save();
                Navigator.pop(context, privateKey);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ));

  return await showDialog<String?>(context: context, builder: (context) => ad);
}

class SendersWidget extends StatefulWidget {
  const SendersWidget({super.key});

  @override
  State<SendersWidget> createState() => _SendersWidgetState();
}

class _SendersWidgetState extends State<SendersWidget> {
  late Map<String, String> _senders;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _senders = ModalRoute.of(context)!.settings.arguments as Map<String, String>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Allowed Message Senders'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context, _senders),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        children: _senders.entries
            .toList()
            .asMap()
            .entries
            .map(
              (e) => Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(5)),
                  color: e.key.isEven ? Colors.blue[100] : Colors.blue[300],
                ),
                child: Row(children: [
                  IconButton(
                      onPressed: () {
                        setState(() {
                          _senders.remove(e.value.key);
                        });
                      },
                      icon: const Icon(Icons.delete)),
                  GestureDetector(
                    child: Row(
                      children: [
                        Text('${e.value.value} : ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(_decorate(e.value.key), style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                    onTap: () async {
                      final item = await showAllowedKeyEditDialog(context, e.value);
                      if (null != item) {
                        setState(() {
                          _senders.remove(e.value.key);
                          _senders[item.key] = item.value.isEmpty ? item.key.substring(0, 4) : item.value;
                        });
                      }
                    },
                  ),
                ]),
              ),
            )
            .toList(),
      ),

      // ignore: prefer_const_constructors
      floatingActionButton: IconButton(
        icon: const Icon(Icons.add),
        onPressed: () async {
          final item = await showAllowedKeyEditDialog(context, null);
          if (null != item) {
            setState(() {
              _senders[item.key] = item.value.isEmpty ? item.key.substring(0, 4) : item.value;
            });
          }
        },
      ),
    );
  }
}

Future<MapEntry<String, String>?> showAllowedKeyEditDialog(
    BuildContext context, MapEntry<String, String>? initialValue) async {
  String privateKey = initialValue?.key ?? '';
  String name = initialValue?.value ?? '';
  final formKey = GlobalKey<FormState>();

  final ad = Form(
      key: formKey,
      child: AlertDialog(
        title: const Text('Allowed Sender'),
        content: Column(
          children: [
            TextFormField(
              initialValue: privateKey,
              validator: (value) {
                if (null == value || !_publicKeyRegex.hasMatch(value)) {
                  return 'Must be a 64 character hex string';
                }
                return null;
              },
              onSaved: (value) => privateKey = value ?? '',
              decoration: const InputDecoration(
                labelText: 'Private Key',
              ),
            ),
            TextFormField(
              initialValue: name,
              validator: (value) {
                if (null == value || value.isEmpty) {
                  return 'Please enter an alias for this key';
                }
                return null;
              },
              onSaved: (value) => name = value ?? '',
              decoration: const InputDecoration(
                labelText: 'Name',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState != null && formKey.currentState!.validate()) {
                formKey.currentState!.save();
                Navigator.pop(context, MapEntry<String, String>(privateKey, name));
              }
            },
            child: const Text('OK'),
          ),
        ],
      ));

  return await showDialog<MapEntry<String, String>?>(context: context, builder: (context) => ad);
}
