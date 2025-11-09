import 'package:solar/MQTT/mqtt_app_state.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

/// Tầng điều khiển cốt lõi (Logic Layer)
/// Chịu trách nhiệm kết nối tới MQTT broker, publish, subscribe,
/// nhận dữ liệu, và chuyển dữ liệu đó về MQTTAppState để UI cập nhật
class MQTTManager {
  final MQTTAppState _currentState;
  MqttServerClient? _client;
  final String _identifier;
  final String _host;
  final String _topicpub;
  final String _topicsub;

  MQTTManager({
    required String host,
    required String topicpub,
    required String topicsub,
    required String identifier,
    required MQTTAppState state,
  }) : _identifier = identifier,
       _host = host,
       _topicpub = topicpub,
       _topicsub = topicsub,
       _currentState = state;

  /// -----------------------------
  /// Khởi tạo cấu hình client MQTT
  /// -----------------------------
  void initializeMQTTClient() {
    _client = MqttServerClient(_host, _identifier);
    _client!.port = 8883;
    _client!.keepAlivePeriod = 20;
    _client!.secure = true;
    _client!.logging(on: true);

    _client!.onConnected = onConnected;
    _client!.onDisconnected = onDisconnected;
    _client!.onSubscribed = onSubscribed;
  }

  /// -----------------------------
  /// Kết nối tới MQTT broker
  /// -----------------------------
  void connect() async {
    assert(_client != null);
    _currentState.clearReceiveText();
    try {
      print("Start MQTT connecting...");
      _currentState.setAppConnectionState(MQTTAppConnectionState.connecting);
      await _client!.connect("smartiot", "Abc112233");
    } on Exception catch (e) {
      print('Kết nối thất bại: $e');
      disconnect();
    }
  }

  void disconnect() {
    print('MQTT Disconnected');
    _client!.disconnect();
  }

  /// -----------------------------
  /// Publish dữ liệu (từ Flutter lên Broker)
  /// -----------------------------
  void publish(String message) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    _client!.publishMessage(_topicpub, MqttQos.exactlyOnce, builder.payload!);
    print("Publish → $_topicpub : $message");
  }

  void onSubscribed(String topic) {
    print('Subscribed confirmed for topic: $topic');
  }

  void onDisconnected() {
    _currentState.setAppConnectionState(MQTTAppConnectionState.disconnected);
  }

  /// -----------------------------
  /// Khi client kết nối thành công
  /// -----------------------------
  void onConnected() {
    _currentState.setAppConnectionState(MQTTAppConnectionState.connected);
    print('MQTT Connected!');

    // Đăng ký cả 2 topic: sensor & control
    _client!.subscribe('subscribe/sensor', MqttQos.atLeastOnce);
    _client!.subscribe('subscribe/control', MqttQos.atLeastOnce);

    print('Subscribed to: subscribe/sensor & subscribe/control');

    // Lắng nghe mọi tin nhắn nhận được
    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final String topic = c[0].topic;
      final String message = MqttPublishPayload.bytesToStringAsString(
        recMess.payload.message,
      );

      print('[MQTT] Topic: $topic');
      print('[MQTT] Message: $message');

      _currentState.setReceivedText(message);

      // hiện tại firmware chỉ gửi lên "subscribe" => cứ gọi setGarden + setGate
      if (topic.contains("sensor")) {
        _currentState.setGarden();
        _currentState.setGate();
      } else if (topic.contains("control")) {
        _currentState.updateControlField();
      }
    });
  }
}
