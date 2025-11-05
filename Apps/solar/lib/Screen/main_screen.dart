import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:solar/MQTT/mqtt.dart';
import 'package:solar/MQTT/mqtt_manager.dart';
import 'package:solar/MQTT/mqtt_app_state.dart';
import 'package:solar/Screen/Node/node_page.dart';
import 'package:solar/Screen/Node/node_page1.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:solar/Package/animatedbutton.dart';
import 'package:solar/Screen/Gate/gate_page.dart';

class MQTTView extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return _MQTTViewState();
  }
}

class _MQTTViewState extends State<MQTTView> {
  late MQTTAppState _currentAppState;
  late MQTTManager _manager;
  late MQTT _mqtt;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MQTTAppState appState = Provider.of<MQTTAppState>(context);
    _currentAppState = appState;
    final MQTT mqtt = Provider.of<MQTT>(context);
    _mqtt = mqtt;
    final Scaffold scaffold = Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Solar App',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF292639),
        leading: Container(
          padding: const EdgeInsets.only(
            left: 8,
          ),
          child: Center(
            child: SizedBox(
              height: 35,
              width: 35,
              child: Image.asset(
                'assets/Logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(
              right: 15,
            ),
            child: Consumer<MQTTAppState>(
              builder: (context, state, _) => Icon(
                state.getIconData,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(child: _buildColumn()),
    );
    return scaffold;
  }

  Widget _buildColumn() {
    return Column(
      children: <Widget>[
        _buildConnectButton(_currentAppState.getAppConnectionState),
        _buildGatePageButton(_currentAppState.getAppConnectionState),
        Padding(padding: EdgeInsets.all(1)),
        _buildGardenButton(_currentAppState.getAppConnectionState),
        Padding(padding: EdgeInsets.all(1)),
        _buildGardenButton1(_currentAppState.getAppConnectionState),
      ],
    );
  }

  Widget _buildConnectButton(MQTTAppConnectionState state) {
    return ConnectButton(
      text: ['Disconnect', 'Connect'],
      buttonText: [
        _currentAppState.getConnectionStringText,
        _currentAppState.getConnectionStringText,
      ],
      onColor:
          _currentAppState.getAppConnectionState ==
              MQTTAppConnectionState.disconnected
          ? Colors.red
          : Colors.blue,
      offColor:
          _currentAppState.getAppConnectionState ==
              MQTTAppConnectionState.disconnected
          ? Colors.red
          : Colors.blue,
      position:
          _currentAppState.getAppConnectionState ==
              MQTTAppConnectionState.disconnected
          ? false
          : true,
      onToggleCallback: (index) {
        setState(() {});
        if (index == 0) {
          _disconnect();
        } else if (index == 1) {
          _configureAndConnect();
        }
      },
    );
  }

  Widget _buildGatePageButton(MQTTAppConnectionState state) {
    return InkWell(
      onTap: () {
        if (state == MQTTAppConnectionState.connected) {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (context) => GatePage()));
        } else {
          return null;
        }
      },
      child: Padding(
        padding: EdgeInsets.only(top: 0, left: 5, right: 5, bottom: 5),
        child: Container(
          padding: EdgeInsets.only(top: 30, bottom: 20, left: 30, right: 30),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: state == MQTTAppConnectionState.connected
                ? Color(0xFF292636)
                : Colors.grey,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: <Widget>[
              Container(
                child: Text(
                  'GateWay',
                  style: TextStyle(
                    color: state == MQTTAppConnectionState.connected
                        ? Colors.white
                        : Colors.white38,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(padding: EdgeInsets.all(20)),
              LinearPercentIndicator(
                width: MediaQuery.of(context).size.width * 0.6,
                lineHeight: 25,
                animation: false,
                progressColor: Colors.blue,
                backgroundColor: state == MQTTAppConnectionState.connected
                    ? Colors.white54
                    : Colors.white10,
                percent: state == MQTTAppConnectionState.connected
                    ? ((_mqtt.getAppState.getGate.getDoCao) / 11).toDouble()
                    : 0,
                center: state == MQTTAppConnectionState.connected
                    ? Text(
                        '${((_mqtt.getAppState.getGate.getDoCao) * 100 / 11).toInt()}%',
                      )
                    : Text(
                        'Mực nước',
                        style: TextStyle(
                          color: Colors.white38,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                linearStrokeCap: LinearStrokeCap.roundAll,
                leading: Text(
                  'Mực nước  ',
                  style: TextStyle(
                    color: state == MQTTAppConnectionState.connected
                        ? Colors.white
                        : Colors.white38,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGardenButton(MQTTAppConnectionState state) {
    return InkWell(
      onTap: () {
        if (state == MQTTAppConnectionState.connected) {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (context) => NodePage()));
        } else {
          return null;
        }
      },
      child: Padding(
        padding: EdgeInsets.all(5),
        child: Container(
          padding: EdgeInsets.only(top: 30, bottom: 20, left: 30, right: 30),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: state == MQTTAppConnectionState.connected
                ? Color(0xFF292639)
                : Colors.grey,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: <Widget>[
              Container(
                child: Text(
                  'Garden 1',
                  style: TextStyle(
                    color: state == MQTTAppConnectionState.connected
                        ? Colors.white
                        : Colors.white38,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(padding: EdgeInsets.all(10)),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Container(
                      child: CircularPercentIndicator(
                        radius: 100,
                        percent: state == MQTTAppConnectionState.connected
                            ? _currentAppState.getGarden.getNhietDo.toDouble() /
                                  100
                            : 0,
                        progressColor: Colors.red,
                        backgroundColor:
                            state == MQTTAppConnectionState.connected
                            ? Colors.white
                            : Colors.white38,
                        circularStrokeCap: CircularStrokeCap.round,
                        center: Text(
                          state == MQTTAppConnectionState.connected
                              ? "${_currentAppState.getGarden.getNhietDo.toInt()}°C"
                              : "Nhiệt độ",
                          style: TextStyle(
                            color: state == MQTTAppConnectionState.connected
                                ? Colors.white
                                : Colors.white38,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  Expanded(
                    child: Container(
                      child: CircularPercentIndicator(
                        radius: 100,
                        percent: state == MQTTAppConnectionState.connected
                            ? _currentAppState.getGarden.getDoAm.toDouble() /
                                  100
                            : 0,
                        progressColor: Colors.blue,
                        backgroundColor:
                            state == MQTTAppConnectionState.connected
                            ? Colors.white
                            : Colors.white38,
                        circularStrokeCap: CircularStrokeCap.round,
                        center: Text(
                          state == MQTTAppConnectionState.connected
                              ? "${_currentAppState.getGarden.getDoAm.toDouble()}%"
                              : "Độ ẩm",
                          style: TextStyle(
                            color: state == MQTTAppConnectionState.connected
                                ? Colors.white
                                : Colors.white38,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      child: CircularPercentIndicator(
                        radius: 100,
                        percent: state == MQTTAppConnectionState.connected
                            ? _currentAppState.getGarden.getDoAmDat.toDouble() /
                                  100
                            : 0,
                        progressColor: Colors.blue,
                        backgroundColor:
                            state == MQTTAppConnectionState.connected
                            ? Colors.white
                            : Colors.white38,
                        circularStrokeCap: CircularStrokeCap.round,
                        center: Text(
                          state == MQTTAppConnectionState.connected
                              ? "${_currentAppState.getGarden.getDoAmDat.toDouble()}%"
                              : "Độ ẩm đất",
                          style: TextStyle(
                            color: state == MQTTAppConnectionState.connected
                                ? Colors.white
                                : Colors.white38,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(padding: EdgeInsets.all(5)),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Container(
                      child: Center(
                        child: const Text(
                          "Nhiệt độ",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      child: Center(
                        child: const Text(
                          "Độ ẩm",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      child: Center(
                        child: const Text(
                          "Độ ẩm đất",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGardenButton1(MQTTAppConnectionState state) {
    return InkWell(
      onTap: () {
        if (state == MQTTAppConnectionState.connected) {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (context) => NodePage1()));
        } else {
          return null;
        }
      },
      child: Padding(
        padding: EdgeInsets.all(5),
        child: Container(
          padding: EdgeInsets.only(top: 30, bottom: 20, left: 30, right: 30),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: state == MQTTAppConnectionState.connected
                ? Color(0xFF292639)
                : Colors.grey,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: <Widget>[
              Container(
                child: Text(
                  'Garden 2',
                  style: TextStyle(
                    color: state == MQTTAppConnectionState.connected
                        ? Colors.white
                        : Colors.white38,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(padding: EdgeInsets.all(10)),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Container(
                      child: CircularPercentIndicator(
                        radius: 100,
                        percent: state == MQTTAppConnectionState.connected
                            ? _currentAppState.getGarden1.getNhietDo
                                      .toDouble() /
                                  100
                            : 0,
                        progressColor: Colors.red,
                        backgroundColor:
                            state == MQTTAppConnectionState.connected
                            ? Colors.white
                            : Colors.white38,
                        circularStrokeCap: CircularStrokeCap.round,
                        center: Text(
                          state == MQTTAppConnectionState.connected
                              ? "${_currentAppState.getGarden1.getNhietDo.toInt()}°C"
                              : "Nhiệt độ",
                          style: TextStyle(
                            color: state == MQTTAppConnectionState.connected
                                ? Colors.white
                                : Colors.white38,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  Expanded(
                    child: Container(
                      child: CircularPercentIndicator(
                        radius: 100,
                        percent: state == MQTTAppConnectionState.connected
                            ? _currentAppState.getGarden1.getDoAm.toDouble() /
                                  100
                            : 0,
                        progressColor: Colors.blue,
                        backgroundColor:
                            state == MQTTAppConnectionState.connected
                            ? Colors.white
                            : Colors.white38,
                        circularStrokeCap: CircularStrokeCap.round,
                        center: Text(
                          state == MQTTAppConnectionState.connected
                              ? "${_currentAppState.getGarden1.getDoAm.toDouble()}%"
                              : "Độ ẩm",
                          style: TextStyle(
                            color: state == MQTTAppConnectionState.connected
                                ? Colors.white
                                : Colors.white38,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      child: CircularPercentIndicator(
                        radius: 100,
                        percent: state == MQTTAppConnectionState.connected
                            ? _currentAppState.getGarden1.getDoAmDat
                                      .toDouble() /
                                  100
                            : 0,
                        progressColor: Colors.blue,
                        backgroundColor:
                            state == MQTTAppConnectionState.connected
                            ? Colors.white
                            : Colors.white38,
                        circularStrokeCap: CircularStrokeCap.round,
                        center: Text(
                          state == MQTTAppConnectionState.connected
                              ? "${_currentAppState.getGarden1.getDoAmDat.toDouble()}%"
                              : "Độ ẩm đất",
                          style: TextStyle(
                            color: state == MQTTAppConnectionState.connected
                                ? Colors.white
                                : Colors.white38,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(padding: EdgeInsets.all(5)),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Container(
                      child: Center(
                        child: const Text(
                          "Nhiệt độ",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      child: Center(
                        child: const Text(
                          "Độ ẩm",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      child: Center(
                        child: const Text(
                          "Độ ẩm đất",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _configureAndConnect() {
    _manager = MQTTManager(
      host: '18043847e2864c2caba0ff6f607cbb8f.s1.eu.hivemq.cloud',
      topicpub: 'publish',
      topicsub: 'subscribe',
      identifier: 'My App Flutter',
      state: _currentAppState,
    );
    _manager.initializeMQTTClient();
    _manager.connect();
    _mqtt.setAppState(_currentAppState);
    _mqtt.setManager(_manager);
  }

  void _disconnect() {
    _manager.disconnect();
  }

  void publish(String text) {
    _manager.publish(text);
  }
}
