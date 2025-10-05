
import 'package:universal_ble/universal_ble.dart';   // ✅ đổi thư viện

class SodoCambien {
  BleDevice bluetoothDevice;
  String tenCambien;
  List<String>? donvi;
  String? icon;
  List<List<double>>? heso;
  List<int>? tanso;
  int? doPhangiai;
  List<double>? daido;
  SodoCambien({
    required this.bluetoothDevice,
    required this.tenCambien,
    this.donvi,
    this.icon,
    this.heso,
    this.tanso,
    this.doPhangiai,
    this.daido,
});
  @override
  String toString() {
    return 'SodoCambien('
        'bluetoothDevice: ${bluetoothDevice.name}, '  // Giả sử bạn muốn in tên của thiết bị Bluetooth
        'tenCambien: $tenCambien, '
        'donvi: $donvi, '
        'icon: $icon, '
        'heso: $heso, '
        'tanso: $tanso, '
        'doPhangiai: $doPhangiai, '
        'daido: $daido)';
  }
}
