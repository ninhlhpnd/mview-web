import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../../Model/dulieucambien.dart';
import '../../../ultis/listcambien.dart' as globals;
import '../bocucbase.dart';

class StemTenluaNuocScreen extends StatefulWidget {
  const StemTenluaNuocScreen(
      {super.key, required this.stream, required this.tenbaihoc});
  final Stream<DulieuCB> stream;
  final String tenbaihoc;

  @override
  State<StemTenluaNuocScreen> createState() => _StemTenluaNuocScreenState();
}

class _StemTenluaNuocScreenState extends State<StemTenluaNuocScreen> {
  String? selectedDeviceId;
  final TextEditingController _sampleRateController =
      TextEditingController(text: "50");

  @override
  void initState() {
    super.initState();
    // Khởi tạo mặc định thiết bị nếu có
    if (globals.SodoCambienList.isNotEmpty) {
      selectedDeviceId = globals.SodoCambienList.first.bluetoothDevice.deviceId;
    }
  }

  @override
  void dispose() {
    _sampleRateController.dispose();
    super.dispose();
  }

  BleDevice? _getSelectedDevice() {
    if (selectedDeviceId == null) return null;
    for (var cb in globals.SodoCambienList) {
      if (cb.bluetoothDevice.deviceId == selectedDeviceId) {
        return cb.bluetoothDevice;
      }
    }
    return null;
  }

  Future<void> _sendStartOffline() async {
    final selectedDevice = _getSelectedDevice();
    if (selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn thiết bị Bluetooth!')),
      );
      return;
    }
    int sampleRate = int.tryParse(_sampleRateController.text) ?? 50;

    // Chuyển tần số lấy mẫu thành 4 byte (Little Endian)
    ByteData byteData = ByteData(4);
    byteData.setInt32(0, sampleRate, Endian.little);

    List<int> frame = [
      0x04,
      byteData.getUint8(0),
      byteData.getUint8(1),
      byteData.getUint8(2),
      byteData.getUint8(3),
    ];

    await _writeToDevice(selectedDevice, frame);
  }

  Future<void> _sendGetOfflineData() async {
    final selectedDevice = _getSelectedDevice();
    if (selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn thiết bị Bluetooth!')),
      );
      return;
    }

    List<int> frame = [0x06, 0x00, 0x00, 0x00, 0x00];
    await _writeToDevice(selectedDevice, frame);
  }

  Future<void> _writeToDevice(BleDevice device, List<int> payload) async {
    try {
      List<BleService> services =
          await UniversalBle.discoverServices(device.deviceId);
      bool sent = false;
      for (BleService service in services) {
        if (globals.serviceUuid.contains(service.uuid.toString())) {
          for (BleCharacteristic characteristic in service.characteristics) {
            if (globals.characteristicUuid
                .contains(characteristic.uuid.toString())) {
              await UniversalBle.write(device.deviceId, service.uuid,
                  characteristic.uuid, Uint8List.fromList(payload));
              debugPrint(
                  "Đã gửi lệnh offline ${payload[0].toRadixString(16)} tới ${device.name}");

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã gửi lệnh tới ${device.name}')),
              );
              sent = true;
              break;
            }
          }
        }
        if (sent) break;
      }

      if (!sent) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Không tìm thấy dịch vụ BLE trên ${device.name}')),
        );
      }
    } catch (e) {
      debugPrint("Lỗi khi gửi dữ liệu offline tới thiết bị: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dropdown list
    final uniqueDevices = <String, BleDevice>{};
    for (var cb in globals.SodoCambienList) {
      uniqueDevices[cb.bluetoothDevice.deviceId] = cb.bluetoothDevice;
    }

    List<DropdownMenuItem<String>> deviceItems =
        uniqueDevices.values.map((device) {
      return DropdownMenuItem<String>(
        value: device.deviceId,
        child: Text(device.name ?? "Unknown Device"),
      );
    }).toList();

    Widget controlPanel = Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Cài Đặt Chế Độ Đo Offline",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue),
            ),
            const SizedBox(height: 15),
            const Text("Chọn Thiết Bị Đích:"),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: uniqueDevices.containsKey(selectedDeviceId)
                      ? selectedDeviceId
                      : null,
                  hint: const Text("Chưa có thiết bị"),
                  items: deviceItems,
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedDeviceId = newValue;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Tần số lấy mẫu (Hz):"),
            const SizedBox(height: 5),
            TextField(
              controller: _sampleRateController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sendStartOffline,
                icon: const Icon(Icons.play_arrow),
                label: const Text("CÀI ĐẶT ĐO OFFLINE"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const Divider(height: 40, thickness: 2),
            const Text(
              "Lấy Dữ Liệu Chuyển Về",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sendGetOfflineData,
                icon: const Icon(Icons.download),
                label: const Text("LẤY DỮ LIỆU ĐÃ LƯU"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Widget mainContent = Center(
      child: BocucBase(stream: widget.stream, wide: true),
    );

    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          toolbarHeight: 20,
          title: Text(
            widget.tenbaihoc,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
        ),
        body: isMobile
            ? Column(
                children: [
                  Expanded(flex: 4, child: mainContent),
                  Container(height: 1, color: Colors.grey.shade300),
                  Expanded(flex: 6, child: controlPanel),
                ],
              )
            : Row(
                children: [
                  Expanded(flex: 3, child: controlPanel),
                  Container(width: 1, color: Colors.grey.shade300),
                  Expanded(flex: 7, child: mainContent),
                ],
              ));
  }
}
