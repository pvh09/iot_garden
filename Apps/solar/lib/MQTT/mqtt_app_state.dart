import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

enum MQTTAppConnectionState { connected, disconnected, connecting }

class MQTTAppState with ChangeNotifier {
  MQTTAppConnectionState _appConnectionState =
      MQTTAppConnectionState.disconnected;
  String _receivedText = '';
  Garden _garden = Garden(
    nhietDo: 0,
    doAmDat: 0,
    doAm: 0,
    lightStatus: 0,
    fanStatus: 0,
    pumpStatus: 0,
    lightButton: 0,
    pumpButton: 0,
    fanButton: 0,
    mode: 0,
  );
  Garden _garden1 = Garden(
    nhietDo: 0,
    doAmDat: 0,
    doAm: 0,
    lightStatus: 0,
    fanStatus: 0,
    pumpStatus: 0,
    lightButton: 0,
    pumpButton: 0,
    fanButton: 0,
    mode: 0,
  );

  Gate _gate = Gate(docao: 0, chedo: 0, maybom: 0, maybomButton: 0);

  //giai ma chuoi JSON
  var _json;
  IconData _icon = Icons.cloud_off;
  String _connectionStringText = 'Disconnected';

  //Nhận dữ liệu từ MQTT dưới dạng chuỗi
  void setReceivedText(String text) {
    _receivedText = text;
    print(_receivedText);
    _json = jsonDecode(_receivedText); //chuyển chuỗi JSON → object _json
  }

  //decode => set data cho vườn 1
  void setGarden() {
    // Nếu app đang ở Manual (mode = 1) thì không cho phép frame MQTT ghi đè
    if (_garden.getMode == 1) {
      // chỉ cập nhật cảm biến để biểu đồ vẫn chạy
      _garden
        .._nhietDo = _json['nhietdo']
        .._doAm = _json['doam']
        .._doAmDat = _json['doamdat'];
      notifyListeners();
      return;
    }

    // Ngược lại (Auto) thì cập nhật toàn bộ
    _garden = Garden(
      nhietDo: _json['nhietdo'],
      doAm: _json['doam'],
      doAmDat: _json['doamdat'],
      lightStatus: _json['light'],
      fanStatus: _json['fan'],
      pumpStatus: _json['pump'],
      lightButton: _json['light'],
      pumpButton: _json['pump'],
      fanButton: _json['fan'],
      mode: _garden.getMode,
    );
    notifyListeners();
  }

  ////decode => set data cho gate
  void setGate() {
    _gate = Gate(
      docao: setDocao(),
      chedo: _json['chedo'],
      maybom: _json['maybom'],
      maybomButton: _json['maybom'],
    );
    _receivedText = '';
    notifyListeners(); // notifyListeners() để UI update
  }

  // ----------------------------------------------------------
  // Xử lý frame MQTT loại "control" (chỉ chứa lệnh điều khiển)
  // ----------------------------------------------------------
  void updateControlField() {
    if (_json == null) return;

    print("[updateControlField] $_json");

    // Nếu JSON có các key này => chỉ cập nhật đúng field, không đụng đến cảm biến
    if (_json.containsKey('light')) {
      _garden.setLightStatus(_json['light']);
      _garden.setLightButton(_json['light']);
    }

    if (_json.containsKey('fan')) {
      _garden.setFanStatus(_json['fan']);
      _garden.setFanButton(_json['fan']);
    }

    if (_json.containsKey('pump')) {
      _garden.setPumpStatus(_json['pump']);
      _garden.setPumpButton(_json['pump']);
    }

    if (_json.containsKey('mode')) {
      _garden.setMode(_json['mode']);
    }

    // Dữ liệu từ Gate (nếu có)
    if (_json.containsKey('maybom')) {
      _gate.setMayBomButton(_json['maybom']);
    }

    notifyListeners();
  }

  double setDocao() {
    if (_json['docao'] >= 11) {
      return 11.0;
    } else if (_json['docao'] >= 0) {
      return _json['docao'].toDouble();
    } else {
      return 0.0;
    }
  }

  void clearReceiveText() {
    _receivedText = '';
    notifyListeners();
  }

  void setAppConnectionState(MQTTAppConnectionState state) {
    _appConnectionState = state;
    switch (state) {
      case MQTTAppConnectionState.connected:
        _icon = Icons.cloud_done;
        _connectionStringText = 'Connected';
        break;
      case MQTTAppConnectionState.disconnected:
        _icon = Icons.cloud_off;
        _connectionStringText = 'Disconnected';
        _gate = Gate(docao: 0, chedo: 0, maybom: 0, maybomButton: 0);
        break;
      case MQTTAppConnectionState.connecting:
        _icon = Icons.cloud_upload;
        _connectionStringText = 'Connecting';
        break;
    }
    print("UI updated: $_connectionStringText");
    notifyListeners();
  }

  //Get data
  String get getReceivedText => _receivedText;
  MQTTAppConnectionState get getAppConnectionState => _appConnectionState;
  IconData get getIconData => _icon;
  dynamic get getConnectionStringText => _connectionStringText;
  Garden get getGarden => _garden;
  Garden get getGarden1 => _garden1;
  Gate get getGate => _gate;
}

class Garden {
  dynamic _nhietDo = 0;
  dynamic _doAm = 0;
  dynamic _doAmDat = 0;
  int _lightStatus = 0;
  int _fanStatus = 0;
  int _pumpStatus = 0;
  int _lightButton = 0;
  int _fanButton = 0;
  int _pumpButton = 0;
  int _mode = 0;
  Garden({
    required dynamic nhietDo,
    required dynamic doAm,
    required dynamic doAmDat,
    required int lightStatus,
    required int fanStatus,
    required int pumpStatus,
    required int lightButton,
    required int fanButton,
    required int pumpButton,
    required int mode,
  }) : _nhietDo = nhietDo,
       _doAm = doAm,
       _doAmDat = doAmDat,
       _lightStatus = lightStatus,
       _pumpStatus = pumpStatus,
       _fanStatus = fanStatus,
       _lightButton = lightButton,
       _fanButton = fanButton,
       _pumpButton = pumpButton,
       _mode = mode;

  void setLightButton(int lightButton) {
    _lightButton = lightButton;
  }

  void setFanButton(int fanButton) {
    _fanButton = fanButton;
  }

  void setPumpButton(int pumpButton) {
    _pumpButton = pumpButton;
  }

  void setMode(int mode) {
    _mode = mode;
  }

  void setLightStatus(int lightStatus) {
    _lightStatus = lightStatus;
  }

  void setFanStatus(int fanStatus) {
    _fanStatus = fanStatus;
  }

  void setPumpStatus(int pumpStatus) {
    _pumpStatus = pumpStatus;
  }

  dynamic get getNhietDo => _nhietDo;
  dynamic get getDoAm => _doAm;
  dynamic get getDoAmDat => _doAmDat;

  int get getLightStatus => _lightStatus;
  int get getFanStatus => _fanStatus;
  int get getPumpStatus => _pumpStatus;

  int get getLightButton => _lightButton;
  int get getFanButton => _fanButton;
  int get getPumpButton => _pumpButton;

  int get getMode => _mode;
}

class Gate {
  dynamic _docao;
  int _chedo;
  int _maybom;
  int _maybomButton;

  Gate({
    required dynamic docao,
    required int chedo,
    required int maybom,
    required int maybomButton,
  }) : _docao = docao,
       _chedo = chedo,
       _maybom = maybom,
       _maybomButton = maybomButton;

  void setMayBomButton(int state) {
    _maybomButton = state;
  }

  void setChedo(int chedo) {
    _chedo = chedo;
  }

  dynamic get getDoCao => _docao;
  int get getCheDo => _chedo;
  int get getMayBom => _maybom;
  int get getMayBomButton => _maybomButton;
}
