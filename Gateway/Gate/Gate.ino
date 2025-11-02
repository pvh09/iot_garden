#include <RF24.h>
#include <RF24_config.h>
#include <nRF24L01.h>
#include <printf.h>

#include <ESP8266WiFi.h> //https://github.com/esp8266/Arduino
#include <DNSServer.h>
#include <ESP8266WebServer.h>
#include <WiFiManager.h> //https://github.com/tzapu/WiFiManager
#include <PubSubClient.h>
#include <SoftwareSerial.h>
#include "Model.h"
#include <WiFiClientSecure.h>

#include <SPI.h>
#include <nRF24L01.h>
#include <RF24.h>

// --- NRF24 ---
#define CE_PIN 4  // GPIO4
#define CSN_PIN 5 // GPIO5

RF24 radio(CE_PIN, CSN_PIN);                      // CE=D2, CSN=D1
const byte diachi[5] = {'A', 'B', 'C', 'D', 'E'}; // giống STM32

#define LED 2
#define PIN_AP 0

#define PUMP 15
#define TRIG_PIN 16
#define ECHO_PIN 2
#define TIME_OUT 5000

const char *ID = "GateWay";
const char *PUB_TOPIC = "subscribe/sensor"; // ✅  Gửi dữ liệu cảm biến
const char *SUB_TOPIC = "publish";          // Flutter gửi lệnh xuống
const char *BROKER = "18043847e2864c2caba0ff6f607cbb8f.s1.eu.hivemq.cloud";
const int PORT = 8883;
const char *MQTT_USER = "smartiot";
const char *MQTT_PASS = "Abc112233";

String inputString;
bool stringComplete = false;

Garden garden0 = Garden(0, 0, 0, 0, 0, 0, 0);
Gate gate = Gate(0, 0, 0);

float docao = 0.0f;
int pump;

bool mqttCommandPending = false;

WiFiClientSecure espClient;
PubSubClient client(espClient);
SoftwareSerial Serial_ESP(13, 5); // RX D1 noi voi chan D4 - TX D6 noi voi chan 3

// ====== Khai báo ======
void wifiSetup();
void callback(char *topic, byte *payload, unsigned int length);
void connectMQTT();
void reconnect();
void resetWifi();

void Xulychuoi_node(String node_data);

float getDistance();
void DocKhoangCach();

void XuLyCheDoGate(); // đọc gate.getCheDo(): "0" auto, "1" manual
void setPumpAuto();
void setPumpManual();

void XuLyChuoiMQTT(String msg); // parse I..J (mode), F..G (maybom)

String JsonGarden0();
void sendMQTT();
void sendData();

void setup()
{
  Serial.begin(115200);
  pinMode(PIN_AP, INPUT_PULLUP);
  pinMode(LED, OUTPUT);

  if (digitalRead(PIN_AP) == LOW)
  {
    WiFiManager wm;
    wm.resetSettings();
    Serial.println(" WiFi credentials cleared!");
  }

  wifiSetup();
  NRFSetup(); // khởi tạo NRF24L01 sau khi WiFi đã sẵn sàng

  pinMode(PUMP, OUTPUT);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  digitalWrite(PUMP, LOW);
}

void NRFSetup()
{
  Serial.println("Khoi dong nRF24...");
  if (!radio.begin())
  {
    Serial.println("Khong tim thay module nRF24!");
    while (1)
      ;
  }
  Serial.println("Da khoi dong thanh cong!");

  // --- Cấu hình giống STM32 ---
  radio.setAutoAck(true);          // bật auto-ack (khớp STM)
  radio.enableDynamicPayloads();   // cho phép payload linh hoạt
  radio.setRetries(5, 15);         // retry delay 15×250µs, 5 lần
  radio.setCRCLength(RF24_CRC_8);  // CRC 8-bit
  radio.setChannel(40);            // channel = 40
  radio.setDataRate(RF24_250KBPS); // tốc độ 250kbps
  radio.setPALevel(RF24_PA_LOW);   // công suất vừa phải

  // --- Mở pipe nhận ---
  radio.openReadingPipe(0, diachi); // pipe 0 để phản hồi ACK đúng TX_ADDR
  radio.openWritingPipe(diachi);
  radio.startListening(); // chuyển sang RX mode

  // --- In ra cấu hình để kiểm tra ---
  radio.printDetails();

  Serial.println("Dang cho du lieu...");
}

void loop()
{
  // 1. Duy tri ket noi MQTT
  connectMQTT();
  // 3. Gui du lieu cam bien len MQTT dinh ky
  sendData(); // gui thong tin nhiet do, do am, muc nuoc
}

void wifiSetup()
{
  WiFiManager wifiManager;
  // wifiManager.resetSettings();
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
void callback(char *topic, byte *payload, unsigned int length)
{
  String response;
  for (int i = 0; i < length; i++)
    response += (char)payload[i];

  Serial.print("📡 Topic: ");
  Serial.println(topic);
  Serial.println("📩 Payload: " + response);

  // 1. Phan tich chuoi va cap nhat gia tri light, fan, pump, mode, gate
  XuLyChuoiMQTT(response);

  // 2. Danh dau co lenh moi (loop se gui NRF mot lan)
  mqttCommandPending = true;

  // 3. Gui phan hoi trang thai len MQTT de app cap nhat lai
  if (response.indexOf("A") >= 0 && response.indexOf("B") >= 0)
  {
    sendControlMQTT("light", garden0.getLight()); // A..B = LIGHT
    Serial.printf("MQTT Update → LIGHT: %d\n", garden0.getLight());
  }

  if (response.indexOf("B") >= 0 && response.indexOf("C") >= 0)
  {
    sendControlMQTT("fan", garden0.getFan()); // B..C = FAN
    Serial.printf("MQTT Update → FAN: %d\n", garden0.getFan());
  }

  if (response.indexOf("C") >= 0 && response.indexOf("D") >= 0)
  {
    sendControlMQTT("pump", garden0.getPump()); // C..D = PUMP
    Serial.printf("MQTT Update → PUMP: %d\n", garden0.getPump());
  }

  if (response.indexOf("D") >= 0 && response.indexOf("E") >= 0)
  {
    sendControlMQTT("mode", garden0.getMode()); // D..E = MODE
    Serial.printf("MQTT Update → MODE: %d\n", garden0.getMode());
  }
}

void connectMQTT()
{
  // Kiểm tra kết nối WiFi
  if (WiFi.status() != WL_CONNECTED)
  {
    Serial.println("WiFi lost, reconnecting...");
    WiFi.reconnect();
    delay(500);
    return;
  }

  // Kết nối MQTT nếu chưa kết nối
  if (!client.connected())
  {
    reconnect();
  }

  client.loop();
}

void reconnect()
{
  while (!client.connected())
  {
    Serial.println("🔗 Connecting to MQTT Broker... ");
    if (client.connect(ID, MQTT_USER, MQTT_PASS))
    {
      Serial.println("✅: Connected!");
      client.subscribe(SUB_TOPIC);
      Serial.print("📡 Subscribed to: ");
      Serial.println(SUB_TOPIC);
      Serial.println();
    }
    else
    {
      Serial.print("Failed, state=");
      Serial.println(client.state());
      delay(2000);
    }
  }
}

void resetWifi()
{
  WiFiManager wifiManager;
  if (digitalRead(PIN_AP) == LOW)
  {
    Serial.println("RESET ESP");
    if (!wifiManager.startConfigPortal("ESP32configue"))
    {
      Serial.println("STA MODE");
      wifiManager.resetSettings();
      delay(2000);
      ESP.restart();
    }
  }
}

float getDistance()
{
  long duration;
  float distanceCm;
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  duration = pulseIn(ECHO_PIN, HIGH, TIME_OUT);
  if (duration == 0)
    return -1;                  // timeout
  return duration / 29.1 / 2.0; // cm
}

void DocKhoangCach()
{
  static unsigned long lastRead = 0;
  if (millis() - lastRead < 2000)
    return; // chỉ đo mỗi 2 giây
  lastRead = millis();

  float distance = getDistance(); // khoảng cách từ cảm biến tới mặt nước (cm)
  if (distance <= 0)
  {
    Serial.println("Echo timeout!");
  }
  else
  {
    // Tính mực nước (độ cao nước trong bồn)
    float mucNuoc = 33.0 - distance; // 33 cm là chiều cao bồn
    if (mucNuoc < 0)
      mucNuoc = 0; // tránh âm nếu sensor nhiễu
    gate.setDoCao(mucNuoc);

    Serial.print("💧 Muc nuoc (doCao): ");
    Serial.print(mucNuoc, 2);
    Serial.println(" cm");
  }
}

// ===================================================
//   Hàm xử lý chế độ Gate qua MQTT: I1J = manual, I0J = auto
// ===================================================
void XuLyCheDoGate()
{
  static bool lastMode = -1;         // Lưu chế độ trước đó (chưa có = -1)
  int currentMode = gate.getCheDo(); // 0 = AUTO, 1 = MANUAL

  // Nếu chế độ thay đổi
  if (currentMode != lastMode)
  {
    if (currentMode == 1)
    {
      Serial.println("Gate: chuyển sang chế độ MANUAL");
    }
    else
    {
      Serial.println("Gate: chuyển sang chế độ AUTO");
    }
    lastMode = currentMode; // cập nhật lại giá trị cũ
  }

  // Vẫn thực thi logic điều khiển như trước
  if (currentMode == 1)
  {
    setPumpManual();
  }
  else
  {
    setPumpAuto();
  }
}

void setPumpAuto()
{
  if (gate.getDoCao() >= 28.0f)
  {
    digitalWrite(PUMP, LOW); // tắt bơm khi bồn đầy
    gate.setMayBom("0");     // cập nhật trạng thái vào Gate
  }
  else if (gate.getDoCao() <= 5.0f)
  {
    digitalWrite(PUMP, HIGH); // bật bơm khi bồn cạn
    gate.setMayBom("1");
  }
}

void setPumpManual()
{
  // Bảo vệ: nếu mực nước quá cao, luôn tắt bơm
  if (gate.getDoCao() >= 28.0f)
  {
    digitalWrite(PUMP, LOW);
    gate.setMayBom("0");
    return;
  }

  // Đọc trạng thái điều khiển thủ công từ MQTT
  bool manualState = gate.getMayBom(); // true = bật, false = tắt
  digitalWrite(PUMP, manualState ? HIGH : LOW);
}

void XuLyChuoiMQTT(String msg)
{
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
// 1. GUI LENH XUONG NODE (TX)
// ===================================================
void ReadNRF_TX()
{
  radio.stopListening();
  delayMicroseconds(150);
  radio.flush_tx(); 

  static byte cmd[4] = {
      (byte)garden0.getPump(),
      (byte)garden0.getFan(),
      (byte)garden0.getLight(),
      (byte)garden0.getMode()};
  Serial.printf("CMD raw bytes (Pump Fan Light Mode): %d %d %d %d\n",
                cmd[0], cmd[1], cmd[2], cmd[3]);
  const uint8_t MAX_RETRY = 3;
  bool ok = false;

  for (uint8_t i = 0; i < MAX_RETRY; i++)
  {
    ok = radio.write(cmd, sizeof(cmd));
    if (ok)
      break; // thành công -> thoát vòng lặp
    Serial.printf("Retry %d/3 failed...\n", i + 1);
    delay(20); // đợi nhẹ 20ms trước khi gửi lại
  }

  Serial.printf("ESP→STM STATUS: %s\n", ok ? "✅ OK" : "🚫 FAIL");
  // Serial.printf("CMD raw bytes (Pump Fan Light Mode): %d %d %d %d\n",
  //               cmd[0], cmd[1], cmd[2], cmd[3]);

  delayMicroseconds(150);
  radio.startListening(); // quay lại RX mode
}

// ===================================================
// 2. NHAN DU LIEU CAM BIEN TU NODE (RX)
// ===================================================
void ReadNRF_RX()
{
  // Luôn ở chế độ lắng nghe để nhận dữ liệu cảm biến
  if (!radio.available())
    return;

  char buffer[32] = {0};
  radio.read(&buffer, radio.getDynamicPayloadSize());

  String raw = String(buffer);
  int startIdx = raw.indexOf('<');
  int endIdx = raw.indexOf('>');
  if (startIdx < 0 || endIdx <= startIdx)
    return;

  String data = raw.substring(startIdx + 1, endIdx);

  float t = 0, h = 0, s = 0;

  if (sscanf(data.c_str(), "%f %f %f",
             &t, &h, &s) == 3)
  {

    garden0.setNhietDo(t);
    garden0.setDoAm(h);
    garden0.setDoAmDat(s);

    Serial.printf("Node data: T=%.1f | H=%.1f | Soil=%.1f\n",
                  t, h, s);
  }
  else
  {
    Serial.printf("Parse fail: %s\n", data.c_str());
  }

  // =============================================
  // 🔁 GỬI LỆNH MQTT NGAY SAU KHI NHẬN GÓI STM
  // =============================================
  if (mqttCommandPending)
  {
    delay(80); // cho STM chuyển sang RX
    ReadNRF_TX();
    mqttCommandPending = false;
  }
}

// -------------------------------------------------------
// Đóng gói dữ liệu cảm biến + trạng thái thành chuỗi JSON
// -------------------------------------------------------
String JsonGarden0()
{
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
void sendSensorMQTT()
{
  client.publish("subscribe/sensor", JsonGarden0().c_str());
}

void sendControlMQTT(const String &key, int value)
{
  String msg = "{ \"" + key + "\": " + String(value) + " }";
  client.publish("subscribe/control", msg.c_str());
}

void sendMQTT()
{
  client.publish(PUB_TOPIC, JsonGarden0().c_str());
}

void sendData()
{
  static unsigned long last = 0;
  ReadNRF_RX(); // ✅ đọc trước khi gửi

  if (millis() - last >= 2000)
  {
    client.publish("subscribe/sensor", JsonGarden0().c_str());
    DocKhoangCach();
    XuLyCheDoGate();
    last = millis();
  }
}
