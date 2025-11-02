import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:solar/MQTT/mqtt.dart';
import 'package:solar/MQTT/mqtt_app_state.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:solar/Package/animatedbutton.dart';
import 'dart:math';

class GatePage extends StatefulWidget{
  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return _GatePageState();
  }
}
class _GatePageState extends State<GatePage> with SingleTickerProviderStateMixin{
  late final AnimationController _controller;
  late MQTT _mqtt;
  late MQTTAppState _currentState;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    MQTT mqtt = Provider.of<MQTT>(context);
    _mqtt = mqtt;
    MQTTAppState currentState = Provider.of<MQTTAppState>(context);
    _currentState = currentState;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF292636),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'GateWay',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
          ),
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 15), // 🔹 đẩy icon sang trái 12px
            child: Consumer<MQTTAppState>(
              builder: (context, state, _) => Icon(
                state.getIconData,   // lấy icon đúng theo state
                color: Colors.white, // màu trắng dễ nhìn
                size: 26,            // (tùy chọn) chỉnh cho vừa AppBar
              ),
            ),
          ),
        ],
      ),

      // ✅ Bọc trong SingleChildScrollView để tránh overflow
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(), // cuộn mượt tự nhiên
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              _buildTank(),
              const SizedBox(height: 35),
              _buildMode(),
              const SizedBox(height: 20),
              _buildButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTank() {
    final double mucNuoc = (_mqtt.getAppState.getGate.getDoCao ?? 0).toDouble();
    final double percentValue = (mucNuoc / 28).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Container(
        height: 400,
        alignment: Alignment.topCenter,
        decoration: BoxDecoration(
          color: const Color(0xFF292636),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20, top: 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Transform.rotate(
                  angle: 3 * pi / 2,
                  child: LinearPercentIndicator(
                    width: 300,
                    lineHeight: 150,
                    percent: percentValue, // ✅ dùng giá trị an toàn
                    linearStrokeCap: LinearStrokeCap.butt,
                    progressColor: Colors.blue,
                    center: Transform.rotate(
                      angle: pi / 2,
                      child: Text('${((mucNuoc * 100 / 28).clamp(0, 100).toInt())}%',
                        style: const TextStyle(
                          color: Color(0xFF292636),
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Padding(padding: EdgeInsets.all(40)),
              Container(
                height: 52,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Thể tích',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${(mucNuoc * 15 / 28).clamp(0, 15).toStringAsFixed(2)}L / 15L',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMode(){
    return AnimatedToggle(
      text: [' Auto', 'Manual '],
      buttonText: ['Auto', 'Manual'],
      onColor: Colors.blue,
      offColor: Colors.blue,
      backgroundColor: Color(0xFF292636),
      position: _mqtt.getAppState.getGate.getCheDo,
      onToggleCallback: (index) {
        setState(() {});
        _mqtt.getAppState.getGate.setChedo( _mqtt.getAppState.getGate.getCheDo == 1? 0 : 1);
        index == 1?
        _mqtt.getManager.publish("I1J"):
        _mqtt.getManager.publish("I0J");
      },
      width: MediaQuery.of(context).size.width,
      hight: 70,
    );
  }

  Widget _buildButton() {
    final gate = _mqtt.getAppState.getGate;

    return Padding(
      padding: EdgeInsets.all(10),
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFF292636),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // 🔹 Chỉ hiển thị công tắc khi ở MANUAL
            _mqtt.getAppState.getGate.getCheDo == 1
                ? Expanded(
              child: CupertinoSwitch(
                value: gate.getMayBomButton == 1 ? true : false,
                onChanged: (value) {
                  // Nếu bình đầy và người dùng định bật bơm -> cảnh báo
                  if (value == true && gate.getDoCao >= 28) {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          backgroundColor: const Color(0xFF292639),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          title: const Text(
                            "⚠️ Cảnh báo",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          content: const Text(
                            "Bình đã đầy — không thể bật bơm!",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text(
                                "Đã hiểu",
                                style:
                                TextStyle(color: Colors.blueAccent),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                    return;
                  }

                  // Cập nhật trạng thái công tắc
                  setState(() {
                    if (gate.getMayBomButton == 1) {
                      gate.setMayBomButton(0);
                    } else {
                      gate.setMayBomButton(1);
                    }
                  });

                  // ✅ Gửi MQTT lệnh điều khiển bơm thủ công
                  if (value == true) {
                    _mqtt.getManager.publish('J1K'); // Bật bơm
                  } else {
                    _mqtt.getManager.publish('J0K'); // Tắt bơm
                  }
                },
              ),
            )
                : SizedBox.shrink(),

            // 🔹 Icon bơm (hiển thị theo trạng thái thực tế)
            Expanded(
              child: SizedBox(
                height: 100,
                child: Transform.rotate(
                  angle: 0,
                  child: _buildMayBomIcon(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMayBomIcon(BuildContext context) {
    final gate = _mqtt.getAppState.getGate;
    if (gate.getDoCao == null) {
      return Image.asset('assets/maybomoff.png');
    }
    // 🔹 AUTO MODE
    if (gate.getCheDo == 0) {
      return gate.getMayBom == 1
          ? Image.asset('assets/maybomon.png')
          : Image.asset('assets/maybomoff.png');
    }

    // 🔹 MANUAL MODE
    else {
      // Nếu đang bật bơm mà bình đầy -> cảnh báo + tự động tắt
      if (gate.getDoCao >= 28 && gate.getMayBom == 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDialog(
            context: context,
            barrierDismissible: false, // không tắt khi chạm ra ngoài
            builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF292639),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: const Text(
                "⚠️ Thông báo",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: const Text(
                "Bình đã đầy — bơm sẽ tự động tắt!",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    "Đã hiểu",
                    style: TextStyle(color: Colors.blueAccent),
                  ),
                ),
              ],
            ),
          );

          // 🔹 Gửi lệnh tắt bơm (vẫn ở chế độ MANUAL)
          _mqtt.getManager.publish('J0K');
        });

        return Image.asset('assets/maybomoff.png');
      }


      // Bình chưa đầy → hiển thị trạng thái bình thường
      return gate.getMayBom == 1
          ? Image.asset('assets/maybomon.png')
          : Image.asset('assets/maybomoff.png');
    }
  }
  }
