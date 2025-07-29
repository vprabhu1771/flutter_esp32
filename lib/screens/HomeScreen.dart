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
