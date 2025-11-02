import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:solar/Screen/main_screen.dart';
import 'package:solar/MQTT/mqtt_app_state.dart';
import 'package:solar/MQTT/mqtt.dart';
import 'package:solar/Screen/Node/node_page.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => MQTTAppState()),
        ChangeNotifierProvider(create: (context) => MQTT())
      ],
      child:  MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MQTTView(),
      ),
    );
  }
}