import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:get_storage/get_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:progress_dialog_fork/progress_dialog_fork.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:mview/Model/sodocambien.dart';
import 'package:mview/ultis/listcambien.dart' as globals;

class CustomDialogContent extends StatefulWidget {
  const CustomDialogContent({super.key});

  @override
  _CustomDialogContentState createState() => _CustomDialogContentState();
}

class _CustomDialogContentState extends State<CustomDialogContent> {
  List<BleDevice> foundDevices = [];
  List<BleDevice> connectedDevices = [];

  // removed: scanSubscription and connectionSubscriptions (we use global callbacks)
  late ProgressDialog pr;
  bool _isPrCreated = false;
  bool _isPrShowing = false;

  @override
  void initState() {
    super.initState();
    debugPrint(
        ">>> MAIN START: SodoCambienList length = ${globals.SodoCambienList.length}");

    // Set global callbacks (works for web and native)
    UniversalBle.onScanResult = _handleScanResult;
    UniversalBle.onConnectionChange = _handleConnectionChange;

    foundDevices.clear();
    restoreConnectedDevices();
    startScan();

  }

  Future<bool> requestBlePermissions(BuildContext context) async {
    if (kIsWeb) return true; // web ko cần runtime permissions

    if (Platform.isAndroid) {
      // Danh sách permission nên request trên Android (API 31+ cần bluetoothScan/connect)
      final permissions = <Permission>[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise, // optional, nhưng request safe
        // thêm location để tương thích Android <12 (API <=30)
        Permission.locationWhenInUse,
      ];

      final statuses = await permissions.request();

      // Kiểm tra trạng thái quan trọng
      final scanStatus = statuses[Permission.bluetoothScan];
      final connectStatus = statuses[Permission.bluetoothConnect];
      final locationStatus = statuses[Permission.locationWhenInUse];

      // Nếu permission trả về null (ví dụ permission không tồn tại trên SDK đó),
      // ta coi như "granted" để không block.
      bool scanGranted = scanStatus?.isGranted ?? true;
      bool connectGranted = connectStatus?.isGranted ?? true;
      bool locationGranted = locationStatus?.isGranted ?? true;

      // Điều kiện thành công: scan + connect được cấp.
      if (scanGranted && connectGranted) {
        return true;
      }

      // Nếu có permission bị permanentlyDenied -> show dialog dẫn tới Settings
      bool anyPermanentlyDenied =
          statuses.values.any((s) => s.isPermanentlyDenied);
      if (anyPermanentlyDenied) {
        await _showOpenSettingsDialog(context,
            title: 'Cần quyền Bluetooth',
            message:
                'Ứng dụng cần quyền Bluetooth để quét thiết bị. Vui lòng bật quyền trong Cài đặt.');
        return false;
      }

      // Nếu chưa granted nhưng không permanentlyDenied (bị denied tạm) -> có thể gọi lại hoặc báo lỗi
      return false;
    }

    if (Platform.isIOS) {
      // iOS: request bluetooth permission
      final status = await Permission.bluetooth.request();
      if (status.isGranted) return true;
      if (status.isPermanentlyDenied) {
        await _showOpenSettingsDialog(context,
            title: 'Cần quyền Bluetooth',
            message:
                'Ứng dụng cần quyền Bluetooth. Vui lòng bật quyền trong Cài đặt.');
      }
      return false;
    }

    // Default: nếu platform khác (desktop) -> ok
    return true;
  }

  Future<void> _showOpenSettingsDialog(BuildContext context,
      {required String title, required String message}) async {
    final open = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false), child: Text('Hủy')),
          TextButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: Text('Mở Cài đặt')),
        ],
      ),
    );

    if (open == true) {
      openAppSettings(); // từ permission_handler
    }
  }

  @override
  void dispose() {
    super.dispose();
    // Cleanup global callbacks and stop scanning
    try {
      UniversalBle.onScanResult = null;
      UniversalBle.onConnectionChange = null;
      UniversalBle.stopScan();
    } catch (e) {
      debugPrint("dispose: stopScan/onX null error: $e");
    }

    // hide progress dialog if still showing
    if (_isPrShowing) {
      try {
        pr.hide();
      } catch (_) {}
      _isPrShowing = false;
    }
  }

  // Future<void> checkBleAvailability(BuildContext context) async {
  //   try {
  //     var isAvailable = await UniversalBle.getBluetoothAvailabilityState();
  //
  //     if (!isAvailable.) {
  //       // ⚠️ Không hỗ trợ BLE
  //       if (context.mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(
  //             content: Text("Thiết bị hoặc trình duyệt không hỗ trợ Bluetooth Low Energy!"),
  //             backgroundColor: Colors.red,
  //           ),
  //         );
  //       }
  //     } else {
  //       debugPrint("✅ Thiết bị có hỗ trợ BLE");
  //     }
  //   } catch (e) {
  //     debugPrint("Lỗi khi kiểm tra BLE: $e");
  //     if (context.mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text("Lỗi khi kiểm tra BLE: $e"),
  //           backgroundColor: Colors.orange,
  //         ),
  //       );
  //     }
  //   }
  // }
  // --------------------------
  // Scan handling (global)
  // --------------------------
  void _handleScanResult(BleDevice device) {
    final deviceName = device.name ?? "";

    // apply same filter logic as your original code
    if (deviceName.isNotEmpty &&
        !foundDevices.any((d) => d.deviceId == device.deviceId) &&
        !connectedDevices.any((d) => d.deviceId == device.deviceId) &&
        globals.scanFilter.any((name) => deviceName.contains(name))) {
      if (mounted) {
        setState(() {
          foundDevices.add(device);
        });
        debugPrint('$deviceName found!');
      }
    }
  }

  Future<void> startScan() async {
    if(!await requestBlePermissions(context)) {
      debugPrint("BLE permissions not granted");
      return;
    }
    try {
      await UniversalBle.stopScan();
    } catch (e) {
      // ignore
    }

    try {
      await UniversalBle.startScan(
        scanFilter: ScanFilter(
          withServices: globals.serviceUuid,
          withNamePrefix: globals.scanFilter,
        ),
      );
    } catch (e) {
      debugPrint("startScan error: $e");
    }
  }

  Future<void> stopScan() async {
    try {
      await UniversalBle.stopScan();
      // optionally clear found devices or keep them
    } catch (e) {
      debugPrint("stopScan error: $e");
    }
  }

  // --------------------------
  // Connection handling (global)
  // --------------------------
  void _handleConnectionChange(
      String deviceId, bool isConnected, String? error) {
    debugPrint("onConnectionChange: $deviceId => $isConnected (err: $error)");

    // hide PR if showing (safely)
    if (_isPrShowing) {
      try {
        pr.hide();
      } catch (e) {
        debugPrint("Error hiding PR: $e");
      }
      _isPrShowing = false;
    }

    if (isConnected) {
      // Nếu đang xem lịch sử mà người dùng kết nối Bluetooth thực tế, thoát chế độ lịch sử
      if (globals.historyViewMode.value) {
        globals.historyViewMode.value = false;
        globals.historySelected = {};
        globals.clearData.value = true; // Yêu cầu đồ thị xóa dữ liệu cũ
      }
      // Xóa luôn lịch sử các lần chạy củ trên app (để khi chạy lại sẽ bắt đầu từ lần 1)
      GetStorage().remove('history_list');

      // find device in foundDevices (if present), else construct a minimal one
      BleDevice? found;
      try {
        found = foundDevices.firstWhere((d) => d.deviceId == deviceId);
      } catch (_) {
        found = null;
      }

      final deviceObj = found ?? BleDevice(deviceId: deviceId, name: "Unknown");

      if (!connectedDevices.any((d) => d.deviceId == deviceId)) {
        setState(() {
          connectedDevices.add(deviceObj);
          foundDevices.removeWhere((d) => d.deviceId == deviceId);
        });

        // Update globals.SodoCambienList same as your original logic:
        int vitri = (deviceObj.name ?? "").indexOf('-');
        String tencambien = "";
        if (vitri > 0) {
          tencambien = deviceObj.name!.substring(0, vitri);
        } else if ((deviceObj.name ?? "").startsWith("Car")) {
          tencambien = "Car";
        }

        if (tencambien.isNotEmpty) {
          if (globals.cambienMapping.containsKey(tencambien)) {
            List<int> indices = globals.cambienMapping[tencambien]!;
            List<SodoCambien> data = indices.map((i) {
              return SodoCambien(
                bluetoothDevice: deviceObj,
                tenCambien: globals.cambiens[i].name,
                donvi: globals.cambiens[i].donvi,
                icon: globals.cambiens[i].icon,
                heso: globals.cambiens[i].heso,
                daido: globals.cambiens[i].daido,
                doPhangiai: globals.cambiens[i].dophangiai,
              );
            }).toList();
            globals.SodoCambienList.addAll(data);
            globals.SodoCambienListHistory.addAll(data);
          } else {
            for (int i = 0; i < globals.cambiens.length; i++) {
              if (tencambien == globals.cambiens[i].id) {
                SodoCambien data = SodoCambien(
                    bluetoothDevice: deviceObj,
                    tenCambien: globals.cambiens[i].name,
                    donvi: globals.cambiens[i].donvi,
                    icon: globals.cambiens[i].icon,
                    heso: globals.cambiens[i].heso,
                    daido: globals.cambiens[i].daido,
                    doPhangiai: globals.cambiens[i].dophangiai);
                globals.SodoCambienList.add(data);
                globals.SodoCambienListHistory.add(data);
                break;
              }
            }
          }
        }
      }
    } else {
      // Disconnected
      globals.SodoCambienList.removeWhere(
          (sodo) => sodo.bluetoothDevice.deviceId == deviceId);
      if (!mounted) return;
      setState(() {
        connectedDevices.removeWhere((d) => d.deviceId == deviceId);
      });
    }
  }

  Future<void> connectBluetooth(BleDevice device) async {
    // create PR if not created
    if (!_isPrCreated) showProgressdialog();

    try {
      // show and track
      _isPrShowing = true;
      await pr.show();

      debugPrint("🔹 Connecting to ${device.deviceId}");
      await UniversalBle.connect(device.deviceId);
      int mtu = await UniversalBle.requestMtu(device.deviceId, 512);

      // DO NOT hide here; onConnectionChange will hide when the connection is established
      debugPrint("✅ connect request sent for ${device.deviceId}");
    } catch (e) {
      debugPrint("Error connecting: $e");
      if (_isPrShowing) {
        try {
          await pr.hide();
        } catch (_) {}
        _isPrShowing = false;
      }
    }
  }

  Future<void> disconnectBluetooth(BleDevice device) async {
    try {
      await UniversalBle.disconnect(device.deviceId);
      // onConnectionChange will update UI/globals when the disconnect is confirmed
    } catch (e) {
      debugPrint("Error disconnect: $e");
      // ensure UI cleaned up
      globals.SodoCambienList.removeWhere(
          (sodo) => sodo.bluetoothDevice.deviceId == device.deviceId);
      if (mounted) {
        setState(() {
          connectedDevices.removeWhere((d) => d.deviceId == device.deviceId);
        });
      }
    }
  }

  void restoreConnectedDevices() {
    if (mounted) {
      setState(() {
        connectedDevices =
            globals.SodoCambienList.map((sodo) => sodo.bluetoothDevice)
                .toSet()
                .toList();
      });
    }
  }

  void showProgressdialog() {
    pr = ProgressDialog(
      context,
      type: ProgressDialogType.Download,
      textDirection: TextDirection.ltr,
      isDismissible: false,
      customBody: Container(
        width: MediaQuery.of(context).size.width * 0.3,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Connecting...',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
    pr.style(
        message: '',
        backgroundColor: Colors.white,
        elevation: 10.0,
        borderRadius: 10.0);
    _isPrCreated = true;
  }

  // UI building unchanged (only minor internal calls updated)
  @override
  Widget build(BuildContext context) {
    var mediaQuery = MediaQuery.of(context);
    return SizedBox(
      height: mediaQuery.size.height * 0.7,
      width: mediaQuery.size.width * 0.55,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.white,
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                color: Color(globals.MyColors.mamau['xanhdatroi']!),
                padding: EdgeInsets.symmetric(
                  vertical: mediaQuery.size.height * 0.01,
                  horizontal: mediaQuery.size.width * 0.015,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: AutoSizeText(
                        'Giao Diện Kết Nối Cảm Biến',
                        style: TextStyle(
                          fontSize: mediaQuery.size.width * 0.012,
                          color: Colors.white,
                          fontWeight: FontWeight.normal,
                          decoration: TextDecoration.none,
                        ),
                        maxLines: 1,
                        minFontSize: 12,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: IconButton(
                        onPressed: () {
                          openBluetoothSettings();
                        },
                        icon: Icon(
                          Icons.bluetooth,
                          color: Colors.white,
                          size: mediaQuery.size.width * 0.015,
                        ),
                        tooltip: 'Tìm thiết bị Bluetooth',
                      ),
                    ),
                  ],
                ),
              ),

              // Nội dung
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: mediaQuery.size.width * 0.02),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: mediaQuery.size.height * 0.02),
                        AutoSizeText('Các thiết bị đã kết nối',
                            style: TextStyle(
                                fontSize: mediaQuery.size.width * 0.014,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: mediaQuery.size.height * 0.01),
                        Container(
                          padding: EdgeInsets.all(mediaQuery.size.width * 0.01),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: getListViewConnected(),
                        ),
                        SizedBox(height: mediaQuery.size.height * 0.02),
                        AutoSizeText('Thiết bị xung quanh',
                            style: TextStyle(
                                fontSize: mediaQuery.size.width * 0.014,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: mediaQuery.size.height * 0.01),
                        Container(
                          padding: EdgeInsets.all(mediaQuery.size.width * 0.01),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: getListViewDevice(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ListView getListViewDevice() {
    return ListView.separated(
      scrollDirection: Axis.vertical,
      itemBuilder: (context, position) {
        return _FoundDevice(parent: this, device: foundDevices[position]);
      },
      separatorBuilder: (context, index) => const Divider(
          color: Colors.grey, thickness: 1, indent: 24, endIndent: 24),
      itemCount: foundDevices.length,
      shrinkWrap: true,
    );
  }

  ListView getListViewConnected() {
    return ListView.separated(
      scrollDirection: Axis.vertical,
      itemBuilder: (context, position) {
        return _ConnectedDevice(
            parent: this, device: connectedDevices[position]);
      },
      separatorBuilder: (context, index) => const Divider(
          color: Colors.grey, thickness: 1, indent: 24, endIndent: 24),
      itemCount: connectedDevices.length,
      shrinkWrap: true,
    );
  }

  // openBluetoothSettings left mostly as-is (works on non-web). On web it will print debug.
  Future<void> openBluetoothSettings() async {
    if (kIsWeb) {
      debugPrint('Open Bluetooth settings not supported on web');
      return;
    }
    if (Platform.isAndroid) {
      const androidIntent = 'android.settings.BLUETOOTH_SETTINGS';
      await launchUrl(
        Uri.parse(
            'intent://$androidIntent#Intent;scheme=android;package=com.android.settings;end'),
      );
    } else if (Platform.isIOS) {
      const url = 'App-Prefs:root=Bluetooth';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        await launchUrl(Uri.parse('App-Prefs:'));
      }
    } else if (Platform.isWindows) {
      const url = 'ms-settings:bluetooth';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      }
    } else {
      debugPrint('Hệ điều hành không được hỗ trợ');
    }
  }
}

class _FoundDevice extends StatelessWidget {
  const _FoundDevice({required this.parent, required this.device});

  final _CustomDialogContentState parent;
  final BleDevice device;

  @override
  Widget build(BuildContext context) {
    String? image = 'assets/icons/temp.jpg';
    String? tencambien;
    int index = device.name?.indexOf('-') ?? -1;
    if (index > 0) {
      String prefix = device.name!.substring(0, index);
      for (var cambien in globals.cambiens) {
        if (prefix == cambien.id) {
          image = cambien.icon;
          tencambien = cambien.name;
          break;
        }
      }
    } else if (device.name?.startsWith("Car") ?? false) {
      for (var cambien in globals.cambiens) {
        if (cambien.id == "Car") {
          image = cambien.icon;
          tencambien = cambien.name;
          break;
        }
      }
    }

    double imageSize = MediaQuery.of(context).size.width * 0.035;
    imageSize = imageSize.clamp(20.0, 40.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(image!,
                width: imageSize, height: imageSize, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () {
                parent.connectBluetooth(device);
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoSizeText(tencambien ?? "Unknown",
                        maxLines: 1,
                        minFontSize: 8,
                        maxFontSize: 12,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    AutoSizeText(device.name ?? "",
                        maxLines: 1,
                        minFontSize: 6,
                        maxFontSize: 11,
                        style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectedDevice extends StatelessWidget {
  const _ConnectedDevice({required this.parent, required this.device});

  final _CustomDialogContentState parent;
  final BleDevice device;

  @override
  Widget build(BuildContext context) {
    String? image = 'assets/icons/temp.jpg';
    String? tencambien;
    int index = device.name?.indexOf('-') ?? -1;
    if (index > 0) {
      for (var cambien in globals.cambiens) {
        if (device.name!.substring(0, index) == cambien.id) {
          image = cambien.icon;
          tencambien = cambien.name;
          break;
        }
      }
    }
    double imageSize = MediaQuery.of(context).size.width * 0.035;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(image!,
                  width: imageSize, height: imageSize, fit: BoxFit.cover)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AutoSizeText(tencambien ?? "Unknown",
                    maxLines: 1,
                    minFontSize: 8,
                    maxFontSize: 12,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                AutoSizeText(device.name ?? "",
                    maxLines: 1,
                    minFontSize: 6,
                    maxFontSize: 11,
                    style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(FontAwesomeIcons.xmark,
                size: 14, color: Color.fromARGB(255, 145, 191, 227)),
            onPressed: () {
              parent.disconnectBluetooth(device);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
