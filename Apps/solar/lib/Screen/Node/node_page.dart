import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:solar/Package/chart.dart';
import 'package:solar/MQTT/mqtt.dart';
import 'package:solar/MQTT/mqtt_app_state.dart';
import 'package:solar/Package/animatedbutton.dart';
import 'package:lottie/lottie.dart';

class NodePage extends StatefulWidget {
  @override
  _NodePageState createState() => _NodePageState();
}

class _NodePageState extends State<NodePage> with TickerProviderStateMixin {
  late MQTT _mqtt;
  late MQTTAppState _currentState;
  late final AnimationController _lightController;
  late final AnimationController _fanController;
  late final AnimationController _pumpController;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _fanController = AnimationController(vsync: this);
    _lightController = AnimationController(vsync: this);
    _pumpController = AnimationController(vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final MQTT mqtt = Provider.of<MQTT>(context);
    _mqtt = mqtt;
    final MQTTAppState currentState = Provider.of<MQTTAppState>(context);
    _currentState = currentState;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF292636),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Garden 1',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: Consumer<MQTTAppState>(
              builder: (context, state, _) =>
                  Icon(state.getIconData, color: Colors.white, size: 26),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            Padding(padding: EdgeInsets.all(10)),
            _buildTabView(),
            _buildAuto(),
            _buildButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabView() {
    return DefaultTabController(
      length: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF292639),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: TabBar(
                  indicator: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: const [
                    Tab(
                      child: Text(
                        'Nhiệt độ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Tab(
                      child: Text(
                        'Độ ẩm',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Tab(
                      child: Text(
                        'Độ ẩm đất',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFF292639),
              ),
              child: SizedBox(
                height: 300,
                child: TabBarView(
                  children: [_buildNhietDo(), _buildDoAm(), _buildDoAmDat()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuto() {
    return AnimatedToggle(
      text: [' Auto', 'Manual '],
      buttonText: ['Auto', 'Manual'],
      onColor: Colors.blue,
      offColor: Colors.blue,
      backgroundColor: const Color(0xFF292636),
      position: _mqtt.getAppState.getGarden.getMode,
      onToggleCallback: (index) {
        final garden = _mqtt.getAppState.getGarden;

        setState(() {
          // Cập nhật mode (0 = Auto, 1 = Manual)
          garden.setMode(index == 1 ? 1 : 0);
          if (index == 1) {
            // Chuyển sang Manual → giữ nguyên trạng thái đang hiển thị của thiết bị
            final temp = garden.getNhietDo ?? 0;
            final soil = garden.getDoAmDat ?? 0;

            // Đèn (Auto: <=32 sáng)
            garden.setLightButton(temp <= 32 ? 1 : 0);
            garden.setLightStatus(temp <= 32 ? 1 : 0);

            // Quạt (Auto: >36 bật)
            garden.setFanButton(temp > 36 ? 1 : 0);
            garden.setFanStatus(temp > 36 ? 1 : 0);

            // Bơm (Auto: <50 bật)
            garden.setPumpButton(soil < 50 ? 1 : 0);
            garden.setPumpStatus(soil < 50 ? 1 : 0);
          } else {
            // Chuyển về Auto → reset nút manual
            garden.setFanButton(0);
            garden.setLightButton(0);
            garden.setPumpButton(0);
          }
        });

        // Gửi lệnh MQTT thay đổi mode
        if (index == 1) {
          _mqtt.getManager.publish("D1E"); // Manual mode
        } else {
          _mqtt.getManager.publish("D0E"); // Auto mode
        }
      },
      width: MediaQuery.of(context).size.width,
      hight: 70,
    );
  }

  Widget _buildNhietDo() {
    final double nhietDo = (_mqtt.getAppState.getGarden.getNhietDo ?? 0)
        .toDouble();
    return Chart(data: nhietDo);
  }

  Widget _buildDoAm() {
    return Container(
      height: 100,
      child: Stack(
        children: [
          Center(child: Lottie.asset('assets/water.json')),
          Center(child: Lottie.asset('assets/in.json')),
          Center(
            child: Text(
              '${(_mqtt.getAppState.getGarden.getDoAm ?? 0).toDouble()}%',
              style: TextStyle(
                color: Color(0xFF0D3770),
                fontSize: 50,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoAmDat() {
    return Container(
      height: 100,
      child: Stack(
        children: [
          Center(child: Lottie.asset('assets/out.json')),
          Center(child: Lottie.asset('assets/in.json')),
          Center(
            child: Text(
              '${(_mqtt.getAppState.getGarden.getDoAmDat ?? 0).toDouble()}%',
              style: TextStyle(
                color: Color(0xFF0D3770),
                fontSize: 50,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        height: 150,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Color(0xFF292636),
                ),
                child: Column(
                  children: [
                    Expanded(child: _buildLightIcon()),
                    _mqtt.getAppState.getGarden.getMode == 1
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: CupertinoSwitch(
                              value:
                                  _mqtt.getAppState.getGarden.getLightButton ==
                                      1
                                  ? true
                                  : false,
                              onChanged: (index) {
                                setState(() {});
                                _mqtt.getAppState.getGarden.setLightButton(
                                  _mqtt.getAppState.getGarden.getLightButton ==
                                          1
                                      ? 0
                                      : 1,
                                );
                                index == true
                                    ? _mqtt.getManager.publish('A1B')
                                    : _mqtt.getManager.publish('A0B');
                              },
                            ),
                          )
                        : SizedBox.shrink(),
                  ],
                ),
              ),
            ),
            SizedBox(width: 5),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Color(0xFF292636),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        width: 60,
                        child: _buildFanIcon(),
                      ),
                    ),
                    _mqtt.getAppState.getGarden.getMode == 1
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: CupertinoSwitch(
                              value:
                                  _mqtt.getAppState.getGarden.getFanButton == 1
                                  ? true
                                  : false,
                              onChanged: (index) {
                                setState(() {});
                                _mqtt.getAppState.getGarden.setFanButton(
                                  _mqtt.getAppState.getGarden.getFanButton == 1
                                      ? 0
                                      : 1,
                                );
                                index == true
                                    ? _mqtt.getManager.publish('B1C')
                                    : _mqtt.getManager.publish('B0C');
                              },
                            ),
                          )
                        : SizedBox.shrink(),
                  ],
                ),
              ),
            ),
            SizedBox(width: 5),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Color(0xFF292636),
                ),
                child: Column(
                  children: [
                    Expanded(child: _buildPumpIcon()),
                    _mqtt.getAppState.getGarden.getMode == 1
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: CupertinoSwitch(
                              value:
                                  _mqtt.getAppState.getGarden.getPumpButton == 1
                                  ? true
                                  : false,
                              onChanged: (index) {
                                setState(() {});
                                _mqtt.getAppState.getGarden.setPumpButton(
                                  _mqtt.getAppState.getGarden.getPumpButton == 1
                                      ? 0
                                      : 1,
                                );
                                index == true
                                    ? _mqtt.getManager.publish('C1D')
                                    : _mqtt.getManager.publish('C0D');
                              },
                            ),
                          )
                        : SizedBox.shrink(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFanIcon() {
    final mode = _mqtt.getAppState.getGarden.getMode;
    final temp = _mqtt.getAppState.getGarden.getNhietDo;
    final fanStatus = _mqtt.getAppState.getGarden.getFanStatus;

    // Nếu chưa có dữ liệu (temp = 0), fan OFF luôn
    if (temp == 0) {
      return Lottie.asset(
        'assets/fanoff.json',
        repeat: false,
        controller: _fanController,
        onLoaded: (composition) {
          _fanController.duration = composition.duration;
          _fanController.forward();
          _fanController.value = 0;
        },
      );
    }

    // Chế độ Auto
    if (mode == 0) {
      return temp > 36
          ? Lottie.asset(
              'assets/fan.json', // Quạt bật
            )
          : Lottie.asset(
              'assets/fanoff.json', // Quạt tắt
              repeat: false,
              controller: _fanController,
              onLoaded: (composition) {
                _fanController.duration = composition.duration;
                _fanController.forward();
                _fanController.value = 0;
              },
            );
    }
    // Chế độ Manual
    else {
      return fanStatus == 1
          ? Lottie.asset(
              'assets/fan.json', // Quạt bật
            )
          : Lottie.asset(
              'assets/fanoff.json', // Quạt tắt
              repeat: false,
              controller: _fanController,
              onLoaded: (composition) {
                _fanController.duration = composition.duration;
                _fanController.forward();
                _fanController.value = 0;
              },
            );
    }
  }

  Widget _buildLightIcon() {
    final mode = _mqtt.getAppState.getGarden.getMode;
    final temp = _mqtt.getAppState.getGarden.getNhietDo;
    final lightStatus = _mqtt.getAppState.getGarden.getLightStatus;

    // Nếu chưa có dữ liệu (temp == 0) => Đèn OFF
    if (temp == 0) {
      return Lottie.asset('assets/lightoff.json', repeat: false);
    }

    // Chế độ Auto
    if (mode == 0) {
      return temp <= 32
          ? Lottie.asset(
              'assets/light.json',
              controller: _lightController,
              repeat: true,
              onLoaded: (composition) {
                _lightController.duration = composition.duration;
                _lightController.forward();
              },
            )
          : Lottie.asset('assets/lightoff.json', repeat: false);
    }
    // Chế độ Manual
    else {
      return lightStatus == 1
          ? Lottie.asset(
              'assets/light.json',
              controller: _lightController,
              repeat: true,
              onLoaded: (composition) {
                _lightController.duration = composition.duration;
                _lightController.forward();
              },
            )
          : Lottie.asset('assets/lightoff.json', repeat: false);
    }
  }

  Widget _buildPumpIcon() {
    final mode = _mqtt.getAppState.getGarden.getMode;
    final soil = _mqtt.getAppState.getGarden.getDoAmDat;
    final pumpStatus = _mqtt.getAppState.getGarden.getPumpStatus;

    if (_currentState.getIconData == Icons.wifi_off ||
        soil == null ||
        soil.isNaN) {
      return Padding(
        padding: const EdgeInsets.only(left: 35),
        child: Lottie.asset(
          'assets/pumpoff.json',
          controller: _pumpController,
          onLoaded: (composition) {
            _pumpController.duration = composition.duration;
            _pumpController.forward();
            _pumpController.value = 0;
          },
        ),
      );
    }

    //  Chế độ Auto
    if (mode == 0) {
      return soil < 50
          ? Lottie.asset('assets/binhnuoctuoicay.json') // Bơm bật
          : Padding(
              padding: const EdgeInsets.only(left: 35),
              child: Lottie.asset(
                'assets/pumpoff.json',
                controller: _pumpController,
                onLoaded: (composition) {
                  _pumpController.duration = composition.duration;
                  _pumpController.forward();
                  _pumpController.value = 0;
                },
              ),
            );
    }
    // Chế độ Manual
    else {
      return pumpStatus == 1
          ? Lottie.asset('assets/binhnuoctuoicay.json')
          : Padding(
              padding: const EdgeInsets.only(left: 35),
              child: Lottie.asset(
                'assets/pumpoff.json',
                controller: _pumpController,
                onLoaded: (composition) {
                  _pumpController.duration = composition.duration;
                  _pumpController.forward();
                  _pumpController.value = 0;
                },
              ),
            );
    }
  }
}