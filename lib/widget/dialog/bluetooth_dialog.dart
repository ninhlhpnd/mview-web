import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:get_storage/get_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:progress_dialog_fork/progress_dialog_fork.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:testproject/Model/sodocambien.dart';
import 'package:testproject/ultis/listcambien.dart' as globals;

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
        if (vitri > 0) {
          String tencambien = deviceObj.name!.substring(0, vitri);
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

              // Nút hoàn thành
              Container(
                alignment: Alignment.center,
                padding: EdgeInsets.only(
                    top: 30, bottom: mediaQuery.size.height * 0.02),
                child: SizedBox(
                  height: mediaQuery.size.height * 0.055,
                  child: ElevatedButton(
                    child: AutoSizeText(
                      'Hoàn thành',
                      style: TextStyle(fontSize: mediaQuery.size.width * 0.012),
                      maxLines: 1,
                      minFontSize: 10,
                      textAlign: TextAlign.center,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Color(globals.MyColors.mamau['xanhdatroi']!),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
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
      for (var cambien in globals.cambiens) {
        if (device.name!.substring(0, index) == cambien.id) {
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
