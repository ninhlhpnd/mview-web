import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';   // ✅ đổi thư viện
import '../../../Model/sodocambien.dart';
import '../../../ultis/listcambien.dart' as globals;

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

    // chỉ gửi cho thiết bị có tên bắt đầu bằng "Mlab"
    final name = device.deviceId;
    if (!name.startsWith("Mlab")) {
      continue;
    }
    debugPrint('Đang gửi tới: $name');
    List<BleService> services = await device.discoverServices();

    for (BleService service in services) {
      if (globals.serviceUuid.contains(service.uuid.toString())) {
        for (BleCharacteristic characteristic
        in service.characteristics) {
          if (globals.characteristicUuid
              .contains(characteristic.uuid.toString())) {
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
