## TTGO T-Display BLE (ESP32) firmware example

Below is a minimal Arduino-style sketch for ESP32 (TTGO T-Display) that exposes a Nordic UART Service (NUS). It prints buttons A/B over BLE and echoes any received text back to the phone. Use Arduino IDE with ESP32 core or PlatformIO.

```cpp
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// NUS UUIDs
static BLEUUID SERVICE_UUID("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
static BLEUUID RX_CHAR_UUID("6E400002-B5A3-F393-E0A9-E50E24DCCA9E"); // write
static BLEUUID TX_CHAR_UUID("6E400003-B5A3-F393-E0A9-E50E24DCCA9E"); // notify

BLEServer *pServer = nullptr;
BLECharacteristic *pTxChar = nullptr;
bool deviceConnected = false;

// TTGO T-Display buttons (GPIOs may vary by board revision)
const int BTN_A = 35; // left (input only)
const int BTN_B = 0;  // right

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* server) { deviceConnected = true; }
  void onDisconnect(BLEServer* server) { deviceConnected = false; }
};

class RxCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    std::string value = pCharacteristic->getValue();
    if (value.length() > 0 && pTxChar) {
      pTxChar->setValue((uint8_t*)value.data(), value.length());
      pTxChar->notify(); // echo back
    }
  }
};

void setup() {
  Serial.begin(115200);
  pinMode(BTN_A, INPUT);
  pinMode(BTN_B, INPUT_PULLUP);

  BLEDevice::init("TTGO TDisplay");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);
  pTxChar = pService->createCharacteristic(
    TX_CHAR_UUID, BLECharacteristic::PROPERTY_NOTIFY
  );
  pTxChar->addDescriptor(new BLE2902());

  BLECharacteristic *pRxChar = pService->createCharacteristic(
    RX_CHAR_UUID, BLECharacteristic::PROPERTY_WRITE
  );
  pRxChar->setCallbacks(new RxCallbacks());

  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->start();
}

unsigned long lastButtonCheck = 0;
int lastA = HIGH, lastB = HIGH;

void loop() {
  if (deviceConnected && millis() - lastButtonCheck > 100) {
    lastButtonCheck = millis();
    int a = digitalRead(BTN_A);
    int b = digitalRead(BTN_B);
    if (a != lastA) {
      lastA = a;
      const char *msg = a == LOW ? "BTN_A_PRESS" : "BTN_A_RELEASE";
      pTxChar->setValue((uint8_t*)msg, strlen(msg));
      pTxChar->notify();
    }
    if (b != lastB) {
      lastB = b;
      const char *msg = b == LOW ? "BTN_B_PRESS" : "BTN_B_RELEASE";
      pTxChar->setValue((uint8_t*)msg, strlen(msg));
      pTxChar->notify();
    }
  }
}
```

In the app, open the Tracker tab, scan for devices named like "TTGO TDisplay", connect, and use the input to send strings. Button events will appear under "Received messages".

# squad_tracker_flutter

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
