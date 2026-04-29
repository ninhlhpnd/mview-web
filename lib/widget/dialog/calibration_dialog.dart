import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:mview/ultis/listcambien.dart' as globals;
import 'package:mview/Model/sodocambien.dart';

class CalibrationDialog extends StatefulWidget {
  const CalibrationDialog({super.key});

  @override
  State<CalibrationDialog> createState() => _CalibrationDialogState();
}

class _CalibrationDialogState extends State<CalibrationDialog> {
  List<BleDevice> connectedDevices = [];
  Set<String> selectedDeviceIds = {};
  
  final TextEditingController _calib1Controller = TextEditingController();
  final TextEditingController _calib2Point1Controller = TextEditingController();
  final TextEditingController _calib2Point2Controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Lấy danh sách thiết bị đang kết nối từ globals
    connectedDevices = globals.SodoCambienList
        .map((e) => e.bluetoothDevice)
        .fold<Map<String, BleDevice>>({}, (map, device) {
          map[device.deviceId] = device;
          return map;
        })
        .values
        .toList();
    
    // Mặc định chọn tất cả
    selectedDeviceIds = connectedDevices.map((d) => d.deviceId).toSet();
  }

  @override
  void dispose() {
    _calib1Controller.dispose();
    _calib2Point1Controller.dispose();
    _calib2Point2Controller.dispose();
    super.dispose();
  }

  void _showDeviceSelection() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Chọn cảm biến"),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: connectedDevices.length,
                  itemBuilder: (context, index) {
                    final device = connectedDevices[index];
                    return CheckboxListTile(
                      title: Text(device.name ?? "Thiết bị không tên"),
                      subtitle: Text(device.deviceId),
                      value: selectedDeviceIds.contains(device.deviceId),
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            selectedDeviceIds.add(device.deviceId);
                          } else {
                            selectedDeviceIds.remove(device.deviceId);
                          }
                        });
                        setState(() {}); // Cập nhật UI chính
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      selectedDeviceIds = connectedDevices.map((d) => d.deviceId).toSet();
                    });
                    setState(() {});
                  },
                  child: const Text("Chọn tất cả"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Uint8List _floatToLittleEndian(double value) {
    ByteData bdata = ByteData(4);
    bdata.setFloat32(0, value, Endian.little);
    return bdata.buffer.asUint8List();
  }

  Future<void> _sendCalibData(int type, int point, String valueStr) async {
    if (valueStr.isEmpty) return;
    
    List<double> values = [];
    try {
      if (valueStr.contains(',')) {
        values = valueStr.split(',').map((e) => double.parse(e.trim())).toList();
      } else {
        values = [double.parse(valueStr)];
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Giá trị nhập vào không hợp lệ")),
      );
      return;
    }

    for (String deviceId in selectedDeviceIds) {
      final device = connectedDevices.firstWhere((d) => d.deviceId == deviceId);
      
      // Xây dựng gói tin
      List<int> packet = [];
      packet.add(0x05); // Header
      packet.add(type); // 0x01: 1 điểm, 0x02: 2 điểm

      if (type == 0x02) {
        packet.add(point); // 0x01: điểm 1, 0x02: điểm 2
      }

      // Xử lý dữ liệu
      int vitriGach = device.name?.indexOf('-') ?? -1;
      String tenPrefix = vitriGach > 0 ? device.name!.substring(0, vitriGach) : "";

      if (tenPrefix == "V&A" && values.length >= 2) {
        // Đặc biệt cho V&A: Dòng và Áp
        packet.addAll(_floatToLittleEndian(values[0])); // Dòng
        packet.addAll(_floatToLittleEndian(values[1])); // Áp
      } else {
        packet.addAll(_floatToLittleEndian(values[0]));
      }
      
      packet.add(0x03); // Footer

      // Gửi dữ liệu qua BLE
      try {
        // Tìm service và characteristic phù hợp (lấy cái đầu tiên trong danh sách globals cho đơn giản)
        // Trong thực tế, có thể cần duyệt qua để tìm cái đúng
        String serviceId = globals.serviceUuid[0];
        String charId = globals.characteristicUuid[0];

        await UniversalBle.write(deviceId, serviceId, charId, Uint8List.fromList(packet));
        
        String msg = type == 0x01 
            ? "Hiệu chỉnh tại điểm ${values.join(',')}" 
            : "Hiệu chỉnh điểm $point: ${values.join(',')}";
            
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$msg thành công cho ${device.name}")),
        );
      } catch (e) {
        debugPrint("Lỗi gửi calib cho $deviceId: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.4,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Hiệu chỉnh cảm biến",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 10),
          const Text("Chọn cảm biến hiệu chỉnh:"),
          const SizedBox(height: 5),
          InkWell(
            onTap: _showDeviceSelection,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedDeviceIds.isEmpty
                          ? "Chưa chọn cảm biến"
                          : selectedDeviceIds.length == connectedDevices.length
                              ? "Tất cả cảm biến"
                              : "${selectedDeviceIds.length} cảm biến đã chọn",
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Chế độ 1 điểm
          const Text("Hiệu chỉnh 1 điểm:", style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _calib1Controller,
                  decoration: const InputDecoration(
                    hintText: "Giá trị chuẩn",
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => _sendCalibData(0x01, 0, _calib1Controller.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(globals.MyColors.mamau['xanhdatroi']!),
                  foregroundColor: Colors.white,
                ),
                child: const Text("Hiệu chỉnh"),
              ),
            ],
          ),
          
          const SizedBox(height: 30),
          
          // Chế độ 2 điểm
          const Text("Hiệu chỉnh 2 điểm:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _calib2Point1Controller,
                  decoration: const InputDecoration(
                    hintText: "Giá trị điểm 1",
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => _sendCalibData(0x02, 0x01, _calib2Point1Controller.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(globals.MyColors.mamau['xanhdatroi']!),
                  foregroundColor: Colors.white,
                ),
                child: const Text("Điểm 1"),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _calib2Point2Controller,
                  decoration: const InputDecoration(
                    hintText: "Giá trị điểm 2",
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => _sendCalibData(0x02, 0x02, _calib2Point2Controller.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(globals.MyColors.mamau['xanhdatroi']!),
                  foregroundColor: Colors.white,
                ),
                child: const Text("Điểm 2"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
