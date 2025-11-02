import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:solar/MQTT/mqtt_app_state.dart';
import 'package:solar/MQTT/mqtt_manager.dart';
import 'mqtt_app_state.dart';

class MQTT with ChangeNotifier{
  late MQTTAppState _currentState;
  late MQTTManager _manager;

  void setManager(MQTTManager manager){
    _manager = manager;
    print('oke manager');
    notifyListeners();
  }
  void setAppState(MQTTAppState currentState){
    _currentState = currentState;
    print('ok');
    notifyListeners();
  }
  MQTTManager get getManager => _manager;
  MQTTAppState get getAppState => _currentState;
}