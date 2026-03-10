import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:mview/ultis/listcambien.dart' as globals;
import 'bluetooth_dialog.dart';

class ConnectionDialog extends StatefulWidget {
  const ConnectionDialog({super.key});

  @override
  State<ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<ConnectionDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SerialPort> usbPorts = [];
  List<SerialPort> connectedUsbPorts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.index = 0; // mặc định là Bluetooth
  }

  void _scanUsbPorts() {
    usbPorts.clear();
    for (final name in SerialPort.availablePorts) {
      usbPorts.add(SerialPort(name));
    }
    setState(() {});
  }

  void _connectUsb(SerialPort port) async {
    try {
      if (!port.openReadWrite()) return;
      final config = SerialPortConfig()
        ..baudRate = 115200
        ..bits = 8
        ..stopBits = 1
        ..parity = 0;
      port.config = config;
      connectedUsbPorts.add(port);
      setState(() {});
    } catch (e) {
      debugPrint("Lỗi kết nối USB: $e");
    }
  }

  void _disconnectUsb(SerialPort port) {
    try {
      if (port.isOpen) port.close();
      connectedUsbPorts.remove(port);
      setState(() {});
    } catch (e) {
      debugPrint("Lỗi ngắt USB: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    var mediaQuery = MediaQuery.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: mediaQuery.size.width * 0.55, // 👈 cùng với Bluetooth dialog
        height: mediaQuery.size.height * 0.7, // 👈 cùng với Bluetooth dialog
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              // Header có TabBar
              Container(
                color: Color(globals.MyColors.mamau['xanhdatroi']!),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: const [
                    Tab(icon: Icon(Icons.bluetooth), text: "Bluetooth"),
                    Tab(icon: Icon(Icons.usb), text: "USB"),
                  ],
                ),
              ),

              // Nội dung 2 tab
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Bluetooth
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: const CustomDialogContent(), // dùng lại nguyên body Bluetooth
                    ),

                    // USB
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _buildUsbTab(),
                    ),
                  ],
                ),
              ),

              // Nút hoàn thành
              Container(
                alignment: Alignment.center,
                padding: EdgeInsets.only(
                    top: 10, bottom: mediaQuery.size.height * 0.02),
                child: SizedBox(
                  height: mediaQuery.size.height * 0.055,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      Color(globals.MyColors.mamau['xanhdatroi']!),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Hoàn thành'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsbTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Các cổng USB khả dụng:",
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: usbPorts.length,
            itemBuilder: (context, index) {
              final port = usbPorts[index];
              final connected = connectedUsbPorts.contains(port);
              return ListTile(
                leading: const Icon(Icons.usb),
                title: Text(port.name ?? "Unknown port"),
                trailing: IconButton(
                  icon: Icon(
                    connected ? Icons.link_off : Icons.link,
                    color: connected ? Colors.red : Colors.green,
                  ),
                  onPressed: () {
                    if (connected) {
                      _disconnectUsb(port);
                    } else {
                      _connectUsb(port);
                    }
                  },
                ),
              );
            },
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _scanUsbPorts,
            icon: const Icon(Icons.refresh),
            label: const Text("Quét lại"),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
