#include <RF24.h>
#include <RF24_config.h>
#include <nRF24L01.h>
#include <printf.h>

#include <ESP8266WiFi.h>  //https://github.com/esp8266/Arduino
#include <DNSServer.h>
#include <ESP8266WebServer.h>
#include <WiFiManager.h>  //https://github.com/tzapu/WiFiManager
#include <PubSubClient.h>
//#include <SoftwareSerial.h>
#include "Model.h"
#include <WiFiClientSecure.h>

#include <SPI.h>
#include <nRF24L01.h>
#include <RF24.h>

// --- NRF24 ---
#define CE_PIN 4   // GPIO4
#define CSN_PIN 5  // GPIO5

RF24 radio(CE_PIN, CSN_PIN);                          // CE=D2, CSN=D1
const byte ADDR_UP[5] = { 'N', 'O', 'D', 'E', '1' };  // STM -> ESP
const byte ADDR_DN[5] = { 'G', 'A', 'T', 'E', '1' };  // ESP -> STM

#define LED 2
#define PIN_AP 0

#define PUMP 15
#define TRIG_PIN 16
#define ECHO_PIN 2
#define TIME_OUT 5000

const char *ID = "GateWay";
const char *PUB_TOPIC = "subscribe/sensor";  // ✅  Gửi dữ liệu cảm biến
const char *SUB_TOPIC = "publish";           // Flutter gửi lệnh xuống
const char *BROKER = "18043847e2864c2caba0ff6f607cbb8f.s1.eu.hivemq.cloud";
const int PORT = 8883;
const char *MQTT_USER = "smartiot";
const char *MQTT_PASS = "Abc112233";

String inputString;
bool stringComplete = false;

Garden garden0 = Garden(0, 0, 0, 0, 0, 0, 0);
Gate gate = Gate(0, 0, 0);

volatile bool hasPendingCmd = false;
byte pendingCmd[4] = { 0, 0, 0, 0 };

float docao = 0.0f;
int pump;

bool mqttCommandPending = false;

WiFiClientSecure espClient;
PubSubClient client(espClient);
//SoftwareSerial Serial_ESP(13, 5);  // RX D1 noi voi chan D4 - TX D6 noi voi chan 3

// ====== Khai báo ======
void wifiSetup();
void callback(char *topic, byte *payload, unsigned int length);
void connectMQTT();
void reconnect();
void resetWifi();

void Xulychuoi_node(String node_data);

float getDistance();
void DocKhoangCach();

void XuLyCheDoGate();  // đọc gate.getCheDo(): "0" auto, "1" manual
void setPumpAuto();
void setPumpManual();

void XuLyChuoiMQTT(String msg);  // parse I..J (mode), F..G (maybom)

String JsonGarden0();
void sendMQTT();
void sendData();

void setup() {
  Serial.begin(115200);
  pinMode(PIN_AP, INPUT_PULLUP);
  pinMode(LED, OUTPUT);

  if (digitalRead(PIN_AP) == LOW) {
    WiFiManager wm;
    wm.resetSettings();
    Serial.println(" WiFi credentials cleared!");
  }

  wifiSetup();
  NRFSetup();  // khởi tạo NRF24L01 sau khi WiFi đã sẵn sàng

  pinMode(PUMP, OUTPUT);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  digitalWrite(PUMP, LOW);
}

void NRFSetup() {
  Serial.println("Khoi dong nRF24...");
  if (!radio.begin()) {
    Serial.println("Khong tim thay module nRF24!");
    while (1)
      ;
  }

  radio.setAutoAck(false);          // khớp STM (AutoAck ON)
  radio.setRetries(10, 15);         // 5 * 250us, 15 lần
  radio.setCRCLength(RF24_CRC_8);   // CRC 8-bit
  radio.setChannel(40);             // kênh 40
  radio.setDataRate(RF24_250KBPS);  // 250 kbps
  radio.setPALevel(RF24_PA_LOW);    // công suất vừa

  radio.enableDynamicPayloads();  // BẬT DPL để nhận chuỗi biến độ dài
  // KHÔNG đặt setPayloadSize() nữa, để DPL lo

  // ESP NHẬN uplink từ STM trên ADDR_UP (pipe 0)
  radio.openReadingPipe(0, ADDR_UP);

  // ESP GỬI downlink cho STM trên ADDR_DN
  radio.openWritingPipe(ADDR_DN);

  radio.startListening();  // mặc định ở RX
  radio.printDetails();
  Serial.println("Dang cho du lieu...");
}


void loop() {
  // 1. Duy tri ket noi MQTT
  connectMQTT();
  // 3. Gui du lieu cam bien len MQTT dinh ky
  sendData();  // gui thong tin nhiet do, do am, muc nuoc
}

void wifiSetup() {
  WiFiManager wifiManager;
  //wifiManager.resetSettings();
  wifiManager.autoConnect("ESP8266config");
  Serial.println("✅: WiFi Connected");
  Serial.print(wifiManager.getWiFiSSID(true));
  Serial.print(" --- ");
  Serial.println(wifiManager.getWiFiPass(true));

  espClient.setInsecure();
  client.setServer(BROKER, PORT);
  client.setCallback(callback);
}

// Ham duoc goi khi co du lieu moi tu MQTT Broker
void callback(char *topic, byte *payload, unsigned int length) {
  String response;
  response.reserve(length);
  for (unsigned int i = 0; i < length; i++) response += (char)payload[i];

  Serial.print("📡 Topic: ");
  Serial.println(topic);
  Serial.println("📩 Payload: " + response);

  // 1) Parse -> cập nhật state mong muốn
  XuLyChuoiMQTT(response);

  // 2) Chuẩn bị gói lệnh 4 byte cho STM (KHÔNG gửi ngay tại đây)
  pendingCmd[0] = (byte)garden0.getPump();
  pendingCmd[1] = (byte)garden0.getFan();
  pendingCmd[2] = (byte)garden0.getLight();
  pendingCmd[3] = (byte)garden0.getMode();
  hasPendingCmd = true;  // ReadNRF_RX() sẽ gửi burst 3 phát

  // 3) Phản hồi control để app cập nhật UI
  if (response.indexOf("A") >= 0 && response.indexOf("B") >= 0) sendControlMQTT("light", garden0.getLight());
  if (response.indexOf("B") >= 0 && response.indexOf("C") >= 0) sendControlMQTT("fan", garden0.getFan());
  if (response.indexOf("C") >= 0 && response.indexOf("D") >= 0) sendControlMQTT("pump", garden0.getPump());
  if (response.indexOf("D") >= 0 && response.indexOf("E") >= 0) sendControlMQTT("mode", garden0.getMode());

  Serial.printf("Queued CMD -> P=%d F=%d L=%d M=%d\n",
                pendingCmd[0], pendingCmd[1], pendingCmd[2], pendingCmd[3]);
}


void connectMQTT() {
  // Kiểm tra kết nối WiFi
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi lost, reconnecting...");
    WiFi.reconnect();
    delay(500);
    return;
  }

  // Kết nối MQTT nếu chưa kết nối
  if (!client.connected()) {
    reconnect();
  }

  client.loop();
}

void reconnect() {
  while (!client.connected()) {
    Serial.println("🔗 Connecting to MQTT Broker... ");
    if (client.connect(ID, MQTT_USER, MQTT_PASS)) {
      Serial.println("✅: Connected!");
      client.subscribe(SUB_TOPIC);
      Serial.print("📡 Subscribed to: ");
      Serial.println(SUB_TOPIC);
      Serial.println();
    } else {
      Serial.print("Failed, state=");
      Serial.println(client.state());
      delay(2000);
    }
  }
}

void resetWifi() {
  WiFiManager wifiManager;
  if (digitalRead(PIN_AP) == LOW) {
    Serial.println("RESET ESP");
    if (!wifiManager.startConfigPortal("ESP32configue")) {
      Serial.println("STA MODE");
      wifiManager.resetSettings();
      delay(2000);
      ESP.restart();
    }
  }
}

float getDistance() {
  long duration;
  float distanceCm;
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  duration = pulseIn(ECHO_PIN, HIGH, TIME_OUT);
  if (duration == 0)
    return -1;                   // timeout
  return duration / 29.1 / 2.0;  // cm
}

void DocKhoangCach() {
  static unsigned long lastRead = 0;
  if (millis() - lastRead < 2000)
    return;  // chỉ đo mỗi 2 giây
  lastRead = millis();

  float distance = getDistance();  // khoảng cách từ cảm biến tới mặt nước (cm)
  if (distance <= 0) {
    Serial.println("Echo timeout!");
  } else {
    // Tính mực nước (độ cao nước trong bồn)
    float mucNuoc = 33.0 - distance;  // 33 cm là chiều cao bồn
    if (mucNuoc < 0)
      mucNuoc = 0;  // tránh âm nếu sensor nhiễu
    gate.setDoCao(mucNuoc);

    Serial.print("💧 Muc nuoc (doCao): ");
    Serial.print(mucNuoc, 2);
    Serial.println(" cm");
  }
}

// ===================================================
//   Hàm xử lý chế độ Gate qua MQTT: I1J = manual, I0J = auto
// ===================================================
void XuLyCheDoGate() {
  static bool lastMode = -1;          // Lưu chế độ trước đó (chưa có = -1)
  int currentMode = gate.getCheDo();  // 0 = AUTO, 1 = MANUAL

  // Nếu chế độ thay đổi
  if (currentMode != lastMode) {
    if (currentMode == 1) {
      Serial.println("Gate: chuyển sang chế độ MANUAL");
    } else {
      Serial.println("Gate: chuyển sang chế độ AUTO");
    }
    lastMode = currentMode;  // cập nhật lại giá trị cũ
  }

  // Vẫn thực thi logic điều khiển như trước
  if (currentMode == 1) {
    setPumpManual();
  } else {
    setPumpAuto();
  }
}

void setPumpAuto() {
  if (gate.getDoCao() >= 28.0f) {
    digitalWrite(PUMP, LOW);  // tắt bơm khi bồn đầy
    gate.setMayBom("0");      // cập nhật trạng thái vào Gate
  } else if (gate.getDoCao() <= 5.0f) {
    digitalWrite(PUMP, HIGH);  // bật bơm khi bồn cạn
    gate.setMayBom("1");
  }
}

void setPumpManual() {
  // Bảo vệ: nếu mực nước quá cao, luôn tắt bơm
  if (gate.getDoCao() >= 28.0f) {
    digitalWrite(PUMP, LOW);
    gate.setMayBom("0");
    return;
  }

  // Đọc trạng thái điều khiển thủ công từ MQTT
  bool manualState = gate.getMayBom();  // true = bật, false = tắt
  digitalWrite(PUMP, manualState ? HIGH : LOW);
}

void XuLyChuoiMQTT(String msg) {
  int idxA = msg.indexOf("A");
  int idxB = msg.indexOf("B");
  int idxC = msg.indexOf("C");
  int idxD = msg.indexOf("D");
  int idxE = msg.indexOf("E");
  int idxI = msg.indexOf("I");
  int idxJ = msg.indexOf("J");
  int idxK = msg.indexOf("K");

  if (idxA >= 0 && idxA + 1 < msg.length())
    garden0.setLight(String(msg[idxA + 1]));

  if (idxB >= 0 && idxB + 1 < msg.length())
    garden0.setFan(String(msg[idxB + 1]));

  if (idxC >= 0 && idxC + 1 < msg.length())
    garden0.setPump(String(msg[idxC + 1]));

  if (idxD >= 0 && idxD + 1 < msg.length())
    garden0.setMode(String(msg[idxD + 1]));

  if (idxI >= 0 && idxI + 1 < msg.length())
    gate.setCheDo(String(msg[idxI + 1]));

  if (idxJ >= 0 && idxJ + 1 < msg.length())
    gate.setMayBom(String(msg[idxJ + 1]));

  Serial.println("---Garden 0---");
  garden0.hienthi();
  gate.hienthi();
}

// ===================================================
// 2. NHAN DU LIEU CAM BIEN TU NODE (RX)
// ===================================================
void ReadNRF_RX() {
  static unsigned long lastUplinkMs = 0;

  // 1) Đọc hết uplink (có thể có nhiều gói back-to-back)
  while (radio.available()) {
    uint8_t len = radio.getDynamicPayloadSize();
    if (len == 0 || len > 31) {        // gói lỗi -> xả và tiếp
      radio.flush_rx();
      continue;
    }

    char buffer[32] = {0};             // zero-init để có '\0'
    radio.read(buffer, len);

    // Chỉ nhận các khung text bắt đầu bằng '<'
    if (buffer[0] != '<') {
      continue;                        // không phải uplink cảm biến -> bỏ qua
    }

    // Đảm bảo null-terminate theo đúng độ dài
    uint8_t n = (len < 31) ? len : 31;
    buffer[n] = '\0';

    // Parse "<T H S>"
    const char* p1 = strchr(buffer, '<');
    const char* p2 = strchr(buffer, '>');
    if (!p1 || !p2 || p2 <= p1) {
      continue;
    }

    float t=0, h=0, s=0;
    if (sscanf(p1 + 1, "%f %f %f", &t, &h, &s) == 3) {
      garden0.setNhietDo(t);
      garden0.setDoAm(h);
      garden0.setDoAmDat(s);
      Serial.printf("Node data: T=%.1f | H=%.1f | Soil=%.1f\n", t, h, s);

      // ✅ ĐÁNH DẤU THỜI ĐIỂM VỪA NHẬN UPLINK
      lastUplinkMs = millis();
    }
  }

  // 2) Nếu có lệnh chờ và vẫn còn trong "cửa sổ" RX của STM -> bắn ngay
  unsigned long now = millis();
  if (hasPendingCmd && (now - lastUplinkMs) <= 180 && (now - lastUplinkMs) >= 3) {
    delay(10);                         // cho STM chuyển hẳn sang RX
    radio.stopListening();
    delayMicroseconds(150);

    bool ok = false;
    Serial.printf("[CERR uplink] P=%u F=%u L=%u M=%u\n",pendingCmd[0], pendingCmd[1], pendingCmd[2], pendingCmd[3]);
    for (uint8_t i = 0; i < 5; ++i) {  // burst 5 phát cho chắc
      ok = radio.write(pendingCmd, 4); // 4 byte: pump, fan, light, mode
      Serial.printf("[TX-after-uplink %u/5] P=%u F=%u L=%u M=%u (dt=%lums)\n",
                    (unsigned)i+1, pendingCmd[0], pendingCmd[1], pendingCmd[2], pendingCmd[3],
                    millis() - lastUplinkMs);
      delay(12);
    }

    delayMicroseconds(150);
    radio.startListening();
    Serial.println(ok ? "[TX CMD] OK" : "[TX CMD] FAIL");
    hasPendingCmd = false;             // clear cờ sau khi đã bắn
  }
}



// -------------------------------------------------------
// Đóng gói dữ liệu cảm biến + trạng thái thành chuỗi JSON
// -------------------------------------------------------
String JsonGarden0() {
  String json = "{";
  json += "\"nhietdo\": " + String(garden0.getNhietDo()) + ",";
  json += "\"doam\": " + String(garden0.getDoAm()) + ",";
  json += "\"doamdat\": " + String(garden0.getDoAmDat()) + ",";
  json += "\"light\": " + String(garden0.getLight()) + ",";
  json += "\"fan\": " + String(garden0.getFan()) + ",";
  json += "\"pump\": " + String(garden0.getPump()) + ",";
  json += "\"mode\": " + String(garden0.getMode()) + ",";
  json += "\"chedo\": " + String(gate.getCheDo()) + ",";
  json += "\"maybom\": " + String(gate.getMayBom()) + ",";
  json += "\"docao\": " + String(gate.getDoCao());
  json += "}";

  Serial.println("📤 JSON Sent: " + json);
  return json;
}

// Dong goi va gui len MQTT broker
void sendSensorMQTT() {
  client.publish("subscribe/sensor", JsonGarden0().c_str());
}

void sendControlMQTT(const String &key, int value) {
  String msg = "{ \"" + key + "\": " + String(value) + " }";
  client.publish("subscribe/control", msg.c_str());
}

void sendMQTT() {
  client.publish(PUB_TOPIC, JsonGarden0().c_str());
}

void sendData() {
  static unsigned long last = 0;
  ReadNRF_RX();  // ✅ đọc trước khi gửi

  if (millis() - last >= 5000) {
    client.publish("subscribe/sensor", JsonGarden0().c_str());
    DocKhoangCach();
    XuLyCheDoGate();
    last = millis();
  }
}
