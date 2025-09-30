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

## Help Request Acceptances (Requester Notifications)

- When any squad member accepts your help/medic request, you are notified:
  - In-app banner/toast in foreground
  - System notification in background
  - TTGO overlay via new BLE line(s):

```
HELP_ACK <requestId> <responderName> <distance_m> <direction_deg> <colorHex>
```

- Multiple acceptances within 10s are coalesced; up to 3 overlays are sent, remaining names grouped as “+N others”.
- Acceptances are persisted in `public.help_responses` and streamed via Supabase Realtime.
- RLS mirrors `help_requests`: only active members of the same squad can read/insert.

## Data privacy: Encrypted user locations

User locations in `public.user_squad_locations` are encrypted at rest using PostgreSQL `pgsodium` with a key stored in Supabase Vault. The app reads/writes via RPCs returning decrypted values per-request.

Steps to set up in your Supabase project:

1) Create a 32-byte key and store as Base64 in a secret, then add to Vault as `user_locations_key`.

```bash
openssl rand -base64 32 | tr -d '\n'  # copy output
# in Supabase Dashboard → Vault: add secret with key "user_locations_key" and the Base64 value
```

2) Run migrations (includes encryption columns, triggers, and RPCs):

```bash
supabase db push
```

3) App behavior:
- Flutter `UserSquadLocationService` calls `get_user_location`, `get_members_locations`, and `update_user_location`.
- Realtime change callbacks refetch via RPC to avoid exposing ciphertext.

Backward compatibility:
- A trigger auto-encrypts any legacy plaintext writes and nulls the plaintext columns.
