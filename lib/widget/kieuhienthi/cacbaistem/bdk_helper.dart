import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart'; // ✅ đổi thư viện
import 'package:mview/Model/sodocambien.dart';
import 'package:mview/ultis/listcambien.dart' as globals;

/// Map cổng số D3–D6 sang giá trị số
const Map<String, int> pinMap = {
  "D3": 3,
  "D4": 4,
  "D5": 5,
  "D6": 6,
};

/// Gửi dữ liệu điều khiển tới BDK qua BLE
Future<void> writeDataToBDK(List<int> data) async {
  for (SodoCambien sodocambien in globals.SodoCambienList) {
    BleDevice device = sodocambien.bluetoothDevice;

    // chỉ gửi cho thiết bị có tên bắt đầu bằng "Mlab", "BDK", "Launch" hoặc "Car-"
    final name = device.name;
    if (name == null) continue;
    
    if (!(name.startsWith("Mlab") || name.startsWith("BDK") || name.startsWith("Launch") || name.startsWith("Car"))) {
      continue;
    }
    print('Đang gửi tới: $name');
    List<BleService> services = await device.discoverServices();

    for (BleService service in services) {
      if (globals.serviceUuid.any((u) => u.toLowerCase() == service.uuid.toString().toLowerCase())) {
        for (BleCharacteristic characteristic in service.characteristics) {
          if (globals.characteristicUuid.any((u) => u.toLowerCase() == characteristic.uuid.toString().toLowerCase())) {
            try {
              await characteristic.write(data);
              debugPrint("✅ Đã gửi $data tới $name (${characteristic.uuid})");
            } catch (e) {
              debugPrint("❌ Lỗi khi gửi tới $name: $e");
            }
          }
        }
      }
    }
  }
}

/// Gửi dữ liệu chuỗi tới thiết bị (dành cho BluetoothCar)
Future<void> writeStringData(String data) async {
  List<int> bytes = data.codeUnits;
  await writeDataToBDK(bytes);
}
