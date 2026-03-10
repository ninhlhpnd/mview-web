import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';
import '../../../Model/sodocambien.dart';
import '../../../ultis/listcambien.dart' as globals;
import 'bdk_helper.dart' as sendData;

import '../../../Model/dulieucambien.dart';

class StemThuyCanhScreen extends StatefulWidget {
  final String tenbaihoc;
  final Stream<DulieuCB> stream;

  const StemThuyCanhScreen(
      {super.key, required this.stream, required this.tenbaihoc});

  @override
  State<StemThuyCanhScreen> createState() => _StemThuyCanhScreenState();
}

class _StemThuyCanhScreenState extends State<StemThuyCanhScreen> {
  bool denOn = false;
  bool bomOn = false;
  StreamSubscription<Uint8List>? _bdkNotifySub;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      initBDKNotification();
    });
  }

  @override
  void dispose() {
    debugPrint("🧹 Dispose → huỷ BLE notification");
    _cancelBDKNotification();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      backgroundColor: const Color(0xFFF2F7FB),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildControlCard(
              title: "ĐÈN",
              icon: Icons.lightbulb,
              isOn: denOn,
              onTap: () {
                setState(() => denOn = !denOn);
                sendData.writeDataToBDK([
                  1, // đại diện ĐÈN
                  denOn ? 1 : 0, // trạng thái
                ]);
              },
              onColor: Colors.amber,
              offColor: Colors.grey.shade400,
            ),
            const SizedBox(width: 16),
            _buildControlCard(
              title: "BƠM",
              icon: Icons.water_drop,
              isOn: bomOn,
              onTap: () {
                setState(() => bomOn = !bomOn);
                sendData.writeDataToBDK([
                  2, // đại diện ĐÈN
                  bomOn ? 1 : 0, // trạng thái
                ]);
              },
              onColor: Colors.blue,
              offColor: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlCard({
    required String title,
    required IconData icon,
    required bool isOn,
    required VoidCallback onTap,
    required Color onColor,
    required Color offColor,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24, // ⬅️ tăng cho icon thoáng
          ),
          decoration: BoxDecoration(
            color: isOn ? onColor.withOpacity(0.15) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isOn ? onColor : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 96,
                color: isOn ? onColor : offColor,
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isOn ? onColor : offColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isOn ? "ĐANG BẬT" : "ĐANG TẮT",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> initBDKNotification() async {
    for (SodoCambien sodocambien in globals.SodoCambienList) {
      final device = sodocambien.bluetoothDevice;
      final name = device.name;

      if (name == null) continue;

      // ✅ chỉ xử lý BDK
      if (!name.startsWith("BDK")) continue;

      debugPrint("🔍 Phát hiện thiết bị BDK: $name");

      try {
        final services = await device.discoverServices();

        for (final service in services) {
          if (!globals.serviceUuid.contains(service.uuid.toString())) continue;

          for (final characteristic in service.characteristics) {
            if (!globals.characteristicUuid
                .contains(characteristic.uuid.toString())) continue;

            try {
              await UniversalBle.subscribeNotifications(
                device.deviceId,
                service.uuid.toString(),
                characteristic.uuid.toString(),
              );

              debugPrint(
                  "🔔 Đã subscribe notification: $name ${characteristic.uuid}");
            } catch (e) {
              debugPrint("⚠️ subscribeNotifications failed for $name "
                  "${service.uuid}/${characteristic.uuid} : $e");
            }
            listenBDKNotification(device.deviceId, characteristic.uuid.toString());
          }
        }
      } catch (e) {
        debugPrint("❌ discoverServices failed for $name : $e");
      }
    }
  }

  void listenBDKNotification(
    String deviceId,
    String charUuid,
  ) {
    _bdkNotifySub = UniversalBle.characteristicValueStream(deviceId, charUuid)
        .listen((rawUint8) {
      // rawUint8: Uint8List
      if (rawUint8.length < 2) {
        debugPrint("⚠️ Dữ liệu không hợp lệ: $rawUint8");
        return;
      }

      final int denState = rawUint8[0]; // byte 1: đèn
      final int bomState = rawUint8[1]; // byte 2: bơm/quạt

      debugPrint("📥 RX BLE -> ĐÈN:$denState | BƠM:$bomState");

      // cập nhật UI
      setState(() {
        denOn = denState == 1;
        bomOn = bomState == 1;
      });
    }, onError: (e) {
      debugPrint("❌ BLE notify error: $e");
    });
  }

  Future<void> _cancelBDKNotification() async {
    for (SodoCambien sodocambien in globals.SodoCambienList) {
      final device = sodocambien.bluetoothDevice;
      final name = device.name;

      if (name == null) continue;
      if (!name.startsWith("BDK")) continue;

      try {
        await UniversalBle.unsubscribe(
          device.deviceId,
          globals.serviceUuid.first,
          globals.characteristicUuid.first,
        );

        debugPrint("🔕 Đã unsubscribe: $name");
      } catch (e) {
        debugPrint("⚠️ unsubscribe error for $name: $e");
      }
    }

    // Huỷ stream listener luôn
    await _bdkNotifySub?.cancel();
    _bdkNotifySub = null;
  }
}
