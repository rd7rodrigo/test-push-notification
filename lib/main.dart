import 'dart:async';
import 'dart:io';

import 'package:agora_chat_sdk/agora_chat_sdk.dart';
import 'package:auto_start_flutter/auto_start_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Se você for usar outros serviços do Firebase em segundo plano, como o Firestore,
  // certifique-se de chamar `initializeApp` antes de usar outros serviços do Firebase.
  await Firebase.initializeApp(
      // options: DefaultFirebaseOptions.currentPlatform,
      );

  print("MENSAGEM EM BACKGROUND: ${message.messageId}");

  var flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      const androidInitializationSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettings = InitializationSettings(android: androidInitializationSettings);

      await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await _initSDK();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    debugPrint("message : $message");
  });
  FirebaseMessaging.onMessage.listen((RemoteMessage event) {
    print('AQUI CHEGANDO ${event.data} - ${event.notification?.body}');
  });
  await FirebaseMessaging.instance.setAutoInitEnabled(true);
  
  _permissionNotification();
  _signIn();
  _addChatListener();

  runApp(const MyApp());
}

_initSDK() async {
  ChatOptions options = ChatOptions(
    appKey: "41772773#998537",
    autoLogin: true,
    debugModel: false,
    requireAck: true,
    // requireDeliveryAck: true,
  );
  // Replace <#Your FCM sender id#> with your FCM Sender ID.
  const idFcm = '1083450039264';
  // const idFcm = 'com.opa.opa_messenger';
  // com.opa.opa_messenger
  options.enableFCM(idFcm); // Env.firebaseFcmId
  options.enableAPNs(idFcm); // Env.firebaseFcmId
  await ChatClient.getInstance.init(options);
  // Notify the SDK that the UI is ready. After the following method is executed, callbacks within `ChatRoomEventHandler`, ` ChatContactEventHandler`, and `ChatGroupEventHandler` can be triggered
  await ChatClient.getInstance.startCallback();

  /// quando abri a mensagem
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('NOTIFICACAO ${message.notification}');
  });
  FirebaseMessaging.onMessage.listen((RemoteMessage event) {
    print('AQUI ${event.data} - ${event.notification?.body}');
  });
  // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
}

void _listenToken() {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  messaging.onTokenRefresh.listen((newToken) async {
    print('NOVO TOKEN $newToken');
    try {
      if (Platform.isIOS) {
        await ChatClient.getInstance.pushManager
            .updateAPNsDeviceToken(newToken);
      } else if (Platform.isAndroid) {
        await ChatClient.getInstance.pushManager.updateFCMPushToken(newToken);
      }
    } on ChatError catch (e) {
      debugPrint("bind fcm token error: ${e.code}, desc: ${e.description}");
    }
  });
}

_tokenFcmToChatSdk() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  final fcmToken = await messaging.getToken();
  print(fcmToken);

  if (fcmToken != null) {
    try {
      if (Platform.isIOS) {
        await ChatClient.getInstance.pushManager
            .updateAPNsDeviceToken(fcmToken);
      } else if (Platform.isAndroid) {
        print(fcmToken);
        await ChatClient.getInstance.pushManager.updateFCMPushToken(fcmToken);
      }
      _setNotificationMode();
      // FirebaseMessaging.onMessage.listen((RemoteMessage event) {
      //   print('AQUI ${event.data} - ${event.notification}');
      // });
    } on ChatError catch (e) {
      debugPrint("bind fcm token error: ${e.code}, desc: ${e.description}");
    }
  }
}

_setNotificationMode() async {
  try {
    // Sets the push notification mode to `MENTION_ONLY` for an app.
    var param = ChatSilentModeParam.remindType(
      ChatPushRemindType.ALL,
    );
    await ChatClient.getInstance.pushManager.setSilentModeForAll(
      param: param,
    );
  } on ChatError catch (e) {
    debugPrint("error: ${e.code}, ${e.description}");
  }
}

void _permissionNotification() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );
  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('User granted permission');
  } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
    print('User granted provisional permission');
  } else {
    print('User declined or has not accepted permission');
  }
}

void _signIn() async {
  // c2d535b3-01c4-446f-a168-c9d4e6a5705a
  const String userId = 'c2d535b301c4446fa168c9d4e6a5705a';
  const agoraToken = "007eJxTYFi08Yqapw6f94yK1MN/n85cr1fj354mkLlzfsgMO+t32aIKDJaWBsaJyamWSQbJBiamyWaJaYZGialmhuZJZmZJKWlm9tn3UwT4GBh2TdJjZGRgZWAEQhBfhcEg0cTCONHQQNfYwtxC19AwNUU3ycTUXNfI0MLIODHV0NzCLAUA+dAk4Q==";
  try {
    await ChatClient.getInstance.loginWithAgoraToken(userId, agoraToken);
    print("Login Sucedido, userId: $userId");
    await _tokenFcmToChatSdk();
    _setNotificationMode();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } on ChatError catch (e) {
    print("Login Falhou, code: ${e.code}, desc: ${e.description}");
    if (e.description == 'The user is already logged in') {
      {
        await _tokenFcmToChatSdk();
        FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler);
      }
    }
  }
}

void _addChatListener() {
  _listenToken();
  // _setNotificationMode();

  ///   ChatClient.getInstance.addConnectionEventHandler(UNIQUE_HANDLER_ID, ConnectionEventHandler());
  ChatClient.getInstance.addConnectionEventHandler(
    'UNIQUE_HANDLER_ID',
    ConnectionEventHandler(
      onTokenDidExpire: () async {
        print('TOKEN JÁ EXPIROU');
      },
      onTokenWillExpire: () async {
        print('TOKEN VAIR EXPIRAR');
      },
      onConnected: () {
        print('CONTECTOU COM SUCESSO');
      },
      onDisconnected: () async {
        print('DISCONECTED');
        // const snackBar = SnackBar(
        //   content: Text('Disconectado'),
        // );
        // ScaffoldMessenger.of(context).showSnackBar(snackBar);
        // await loginController.refreshAgoraToken();
      },
      onUserAuthenticationFailed: () async {
        print('AUTENTICÇÂO FALHOU');
      },
    ),
  );

  // ChatClient.getInstance.chatManager.addMessageEvent("UNIQUE_HANDLER_ID", userEvents());

  ChatClient.getInstance.chatManager.addEventHandler(
    "UNIQUE_HANDLER_ID",
    ChatEventHandler(
      // onMessagesRead: onMessagesIsRead,
      onMessagesReceived: (messages) async {
        print('CHEGU MENSAGEM AQUI');
        var flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

        const androidInitializationSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
        // const androidInitializationSettings = AndroidInitializationSettings('app_icon');
        const initializationSettings = InitializationSettings(android: androidInitializationSettings);
        /*
        await flutterLocalNotificationsPlugin.initialize(initializationSettings);
        const NotificationDetails notificationDetails = NotificationDetails(
          android: androidNotificationDetails,
          // iOS: iosNotificationDetails,
          // macOS: macOSNotificationDetails,
          // linux: linuxNotificationDetails,
        );
        await flutterLocalNotificationsPlugin.show(
        1, 'plain title', 'plain body', notificationDetails,
        payload: 'item x',
        );
        */
      },
      // onCmdMessagesReceived: onCmdReceived,
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    //call in init state;
    initAutoStart();
  }

  //initializing the autoStart with the first build.
  Future<void> initAutoStart() async {
    try {
      //check auto-start availability.
      bool? test = await (isAutoStartAvailable as Future<bool?>);
      print(test);
      //if available then navigate to auto-start setting page.
      if (test == true) await getAutoStartPermission();
    } on PlatformException catch (e) {
      print(e);
    }
    if (!mounted) return;
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
    _startLogin();
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) {
        print('USUÁRIO NÃO ESTÁ LOGADO');
      } else {
        print('USUÁRIO ESTÁ LOGADO');
      }
    });
  }

  _startLogin() async {
    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      print("Signed in with temporary account.");
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case "operation-not-allowed":
          print("Anonymous auth hasn't been enabled for this project.");
          break;
        default:
          print("Unknown error.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              'X',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => '',
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
