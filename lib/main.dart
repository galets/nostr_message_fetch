import 'factory.dart';
import 'fetcher.dart';
import 'settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

void main() {
  var app = MaterialApp(
    routes: {
      '/loading': (context) => const LoadingWidget(),
      '/home': (context) => const HomeWidget(),
      '/settings': (context) => const SettingsWidget(),
      '/settings/senders': (context) => const SendersWidget(),
    },
    initialRoute: "/loading",
  );

  runApp(app);
}

class HomeWidget extends StatefulWidget {
  const HomeWidget({Key? key}) : super(key: key);

  @override
  State<HomeWidget> createState() => _HomeWidgetState();
}

class _HomeWidgetState extends State<HomeWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Nostr Message Receiver')),
        floatingActionButton: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Navigator.of(context).pushNamed("/settings");
          },
        ),
        body: FutureBuilder(
          future: loadConfig(),
          builder: (context, snapshot) {
            return const MessageListWidget();
          },
        ));
  }
}

class LoadingWidget extends StatefulWidget {
  const LoadingWidget({Key? key}) : super(key: key);

  @override
  State<LoadingWidget> createState() => _LoadingWidgetState();
}

class _LoadingWidgetState extends State<LoadingWidget> {
  Future<void> _initTasks() async {
    final t = getTaskService();
    await t.start();
    final config = await loadConfig();
    final fetcher = getFetcher();
    await fetcher.start(config);
    final notifyPort = t.notifyPort;
    if (notifyPort != null) {
      notifyPort.listen((message) => fetcher.refreshConnection());
    }
  }

  @override
  void initState() {
    super.initState();

    final l = getLocalNotificationService();
    l.requestPermissions();

    final t = getTaskService();
    t.init();

    _initTasks().then((_) => Navigator.of(context).pushReplacementNamed("/home"));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blue,
      child: const SpinKitRotatingCircle(color: Colors.white, size: 50.0),
    );
  }
}

class MessageWidget extends StatelessWidget {
  final SecureMessage message;
  final int index;

  const MessageWidget({Key? key, required this.message, required this.index}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final style = message.isRead ? const TextStyle() : const TextStyle(fontWeight: FontWeight.bold);
    return Container(
      padding: const EdgeInsets.all(5),
      margin: const EdgeInsets.fromLTRB(0, 2, 0, 2),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(5)),
        color: index.isEven ? Colors.lightBlue : Colors.lightBlueAccent,
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(message.from, style: style)),
          Expanded(flex: 4, child: Text(message.text, style: style)),
        ],
      ),
    );
  }
}

class MessageListWidget extends StatefulWidget {
  const MessageListWidget({Key? key}) : super(key: key);

  @override
  State<MessageListWidget> createState() => _MessageListWidgetState();
}

class _MessageListWidgetState extends State<MessageListWidget> with WidgetsBindingObserver {
  late AppLifecycleState _state;

  @override
  void initState() {
    super.initState();
    _state = WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.inactive;
    WidgetsBinding.instance.addObserver(this);

    getMessageStream().stream.listen((event) {
      setState(() {});
      if (_state != AppLifecycleState.resumed) {
        getLocalNotificationService()
            .showNotification(id: event.id.hashCode, title: 'Message from ${event.from}', body: event.text);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _state = state;
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fetcher = getFetcher();
    final messages = fetcher.getMessages();
    messages.sort((m1, m2) => m2.createdAt.compareTo(m1.createdAt));
    messages.forEach((m) {
      m.isSeen = true;
    });
    fetcher.commit();

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
      children: messages
          .asMap()
          .entries
          .map((e) => GestureDetector(
                child: MessageWidget(
                  message: e.value,
                  index: e.key,
                ),
                onTap: () {
                  setState(() {
                    e.value.isRead = true;
                    fetcher.commit();
                  });
                },
              ))
          .toList(),
    );
  }
}
