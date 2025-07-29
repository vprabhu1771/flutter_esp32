Here’s a complete example of **controlling an LED using Flutter and ESP32 via Bluetooth Classic (Serial)**.

---

## 🔧 ESP32 Code (Arduino C++)

Use `BluetoothSerial.h` (Classic Bluetooth, not BLE).

### ✅ Wiring

* Connect **LED +** to **GPIO 2** (built-in LED also works).
* Connect **LED -** to **GND**.

### ✅ Arduino Code

```cpp
#include "BluetoothSerial.h"

BluetoothSerial SerialBT;
const int ledPin = 2;

void setup() {
  Serial.begin(115200);
  pinMode(ledPin, OUTPUT);
  SerialBT.begin("ESP32_LED");  // Bluetooth device name
  Serial.println("Bluetooth Started! Pair with ESP32_LED");
}

void loop() {
  if (SerialBT.available()) {
    char command = SerialBT.read();
    if (command == '1') {
      digitalWrite(ledPin, HIGH);
      SerialBT.println("LED ON");
    } else if (command == '0') {
      digitalWrite(ledPin, LOW);
      SerialBT.println("LED OFF");
    }
  }
}
```

Upload to ESP32 using Arduino IDE.

---

## 📱 Flutter App Code

### ✅ pubspec.yaml

```yaml
flutter_bluetooth_serial: ^0.4.0
permission_handler: ^11.0.0
```

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
</manifest>
```

### ✅ main.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_esp32/screens/HomeScreen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(title: "ESP32 LED Control"),
    );
  }
}
```

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';

class HomeScreen extends StatefulWidget {

  final String title;

  const HomeScreen({super.key, required this.title});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  BluetoothConnection? connection;
  bool isConnected = false;
  bool ledOn = false;

  @override
  void initState() {
    super.initState();
    requestPermissions(); // Request permissions on startup
  }

  Future<void> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location, // Required for Android < 12
    ].request();

    if (statuses.values.any((status) => status.isDenied || status.isPermanentlyDenied)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Bluetooth permissions are required.")),
      );
    }
  }

  Future<void> connectToDevice() async {
    BluetoothDevice? device;

    final BluetoothDevice? selectedDevice = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SelectBondedDevicePage(checkAvailability: false),
      ),
    );

    if (selectedDevice != null) {
      device = selectedDevice;
      BluetoothConnection.toAddress(device.address).then((_connection) {
        print('Connected to the device');
        connection = _connection;
        setState(() => isConnected = true);
        connection!.input!.listen((data) {
          print('Data from ESP32: ${String.fromCharCodes(data)}');
        });
      }).catchError((error) {
        print('Cannot connect: $error');
      });
    }
  }

  void toggleLed() {
    if (connection != null && connection!.isConnected) {
      connection!.output.add(
        Uint8List.fromList([
          ledOn ? '0'.codeUnitAt(0) : '1'.codeUnitAt(0),
        ]),
      );
      setState(() => ledOn = !ledOn);
    }
  }

  @override
  void dispose() {
    connection?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: isConnected ? toggleLed : null,
              child: Text(ledOn ? 'Turn OFF LED' : 'Turn ON LED'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: connectToDevice,
              child: Text("Connect to ESP32"),
            ),
          ],
        ),
      ),
    );
  }
}

class SelectBondedDevicePage extends StatelessWidget {
  final bool checkAvailability;

  const SelectBondedDevicePage({required this.checkAvailability});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BluetoothDevice>>(
      future: FlutterBluetoothSerial.instance.getBondedDevices(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        final devices = snapshot.data!;
        return Scaffold(
          appBar: AppBar(title: Text("Select Device")),
          body: ListView(
            children: devices
                .map((device) => ListTile(
              title: Text(device.name ?? ""),
              subtitle: Text(device.address),
              onTap: () => Navigator.of(context).pop(device),
            ))
                .toList(),
          ),
        );
      },
    );
  }

}
```

---

## 📋 Steps to Test

1. Upload the ESP32 Arduino code.
2. Power on ESP32.
3. Pair `ESP32_LED` from Android Bluetooth settings.
4. Run the Flutter app on Android.
5. Tap **"Connect to ESP32"**, select the device.
6. Toggle LED using the button.

---

Would you like a BLE (Bluetooth Low Energy) version instead?
