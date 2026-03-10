import 'dart:async';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:mview/Model/sodocambien.dart';
import 'package:mview/Model/dulieucambien.dart';
import 'package:mview/ultis/listcambien.dart' as globals;
import 'package:mview/main.dart' show navigatorKey;

class ConnectionManager {
  // Singleton pattern
  static final ConnectionManager _instance = ConnectionManager._internal();
  factory ConnectionManager() => _instance;
  ConnectionManager._internal();

  Timer? _timer;
  bool _initialized = false;

  // Hàm callback để reset UI hoặc Stream từ Main
  void Function()? onDisconnectedAll;
  BuildContext? _context;

  void init({BuildContext? context, void Function()? onDisconnectedAll}) {
    if (_initialized) return;
    _initialized = true;
    _context = context;
    this.onDisconnectedAll = onDisconnectedAll;

    debugPrint("🔌 ConnectionManager started.");

    // 1️⃣ Lắng nghe sự kiện BLE disconnect
    UniversalBle.onConnectionChange = (deviceId, isConnected, error) {

      if (!isConnected) {
        SodoCambien? foundDevice;
        for (final sodo in globals.SodoCambienList) {
          if (sodo.bluetoothDevice.deviceId == deviceId) {
            foundDevice = sodo;
            break;
          }
        }
        final deviceName = foundDevice?.bluetoothDevice.name ?? "Không rõ tên";
        _handleDeviceLost(deviceName, "Mất kết nối Bluetooth");
      }
    };

    // 2️⃣ Kiểm tra định kỳ (phòng trường hợp OS không báo disconnect)
    // _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
    //   for (final sodo in List.of(globals.SodoCambienList)) {
    //     try {
    //       bool connected = await sodo.bluetoothDevice.isConnected;
    //       if (!connected) {
    //         _handleDeviceLost(
    //             sodo.bluetoothDevice.name, "Mất kết nối (timeout)");
    //       }
    //     } catch (e) {
    //       _handleDeviceLost(
    //           sodo.bluetoothDevice.name, "Lỗi kiểm tra kết nối: $e");
    //     }
    //   }
    // });
  }

  void _handleDeviceLost(String? deviceId, String reason) {
    // Nếu device còn trong danh sách thì xoá
    int before = globals.SodoCambienList.length;
    globals.SodoCambienList.removeWhere(
            (sodo) => sodo.bluetoothDevice.deviceId == deviceId);
    if (globals.SodoCambienList.length == before) return;

    debugPrint("💥 Thiết bị $deviceId bị mất kết nối ($reason)");

    // Hiện dialog cảnh báo
    _showDisconnectedDialog(deviceId);
    // Gọi callback để Main reset UI (nếu cần)
    onDisconnectedAll?.call();
  }

  void _showDisconnectedDialog(String? deviceId) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      debugPrint("⚠️ Không thể hiển thị dialog: context null");
      return;
    }

    if (ctx.mounted) {
      showDialog(
        context: ctx,
        barrierDismissible: true,
        builder: (context) {
          return AlertDialog(
            title: const Text("⚠️ Mất kết nối thiết bị"),
            content: Text(
                "Thiết bị có ID:\n$deviceId\nđã bị ngắt kết nối.\n\nCác phép đo sẽ dừng lại."),
            actions: [
              TextButton(
                child: const Text("OK"),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          );
        },
      );
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _initialized = false;
    debugPrint("🧹 ConnectionManager stopped.");
  }
}
