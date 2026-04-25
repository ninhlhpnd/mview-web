#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <ESP32Servo.h>

BLEServer* pServer = NULL;
BLECharacteristic* pTxCharacteristic;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// Cấu hình chân điều khiển
#define PIN_CONTROL 18 // D18
Servo myServo;

#define CHARACTERISTIC_UUID_TX "4a5c0000-0003-0000-0000-5c1e741f1c00"
#define SERVICE_UUID "4a5c0000-0000-0000-0000-5c1e741f1c00"

class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
  };
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
  }
};

class MyCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) {
    String value = pCharacteristic->getValue();
    if (value.length() >= 6) {
      uint8_t* data = (uint8_t*)value.data();
      
      // Kiểm tra Header (0x02) và Footer (0xFF)
      if (data[0] == 0x02 && data[value.length() - 1] == 0xFF) {
        uint8_t len = data[1];
        uint8_t cmd = data[2];
        uint8_t port = data[3];
        uint8_t val = data[4];

        Serial.printf("Received: Cmd=%d, Port=%d, Value=%d\n", cmd, port, val);

        if (cmd == 1) { // Lệnh SET (Digital/PWM)
          // Ở đây ta có thể kiểm tra port nếu muốn, ví dụ port 18
          analogWrite(PIN_CONTROL, val); 
          Serial.printf("SET Pin %d to %d\n", PIN_CONTROL, val);
        } 
        else if (cmd == 2) { // Lệnh SET SERVO
          if (!myServo.attached()) {
            myServo.attach(PIN_CONTROL);
          }
          myServo.write(val);
          Serial.printf("SET SERVO Pin %d to %d deg\n", PIN_CONTROL, val);
        }
      }
    }
  }
};

void setup() {
  Serial.begin(115200);

  // Cấu hình chân ra
  pinMode(PIN_CONTROL, OUTPUT);

  // Khởi tạo BLE
  BLEDevice::init("Launch-001");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  BLEDevice::setMTU(512);

  BLEService* pService = pServer->createService(SERVICE_UUID);
  pTxCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID_TX,
    BLECharacteristic::PROPERTY_NOTIFY | BLECharacteristic::PROPERTY_WRITE);
  pTxCharacteristic->addDescriptor(new BLE2902());
  pTxCharacteristic->setCallbacks(new MyCallbacks());

  pService->start();
  pServer->getAdvertising()->start();

  Serial.println("Launch-001 is ready and advertising...");
}

void loop() {
  // Xử lý trạng thái kết nối
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->getAdvertising()->start();
    Serial.println("Re-advertising...");
    oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
    Serial.println("Device connected!");
  }
}
