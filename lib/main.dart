import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mview/widget/dialog/connection_dialog.dart';
import 'package:mview/widget/kieuhienthi/cacbaistem/stemthuycanh.dart';
import 'package:universal_ble/universal_ble.dart'; // ✅ đổi thư viện
import 'package:auto_size_text/auto_size_text.dart';
import 'package:get_storage/get_storage.dart';
import 'package:synchronized/synchronized.dart';
import 'package:mview/Model/dulieucambien.dart';
import 'package:mview/Model/sodocambien.dart';
import 'package:mview/ultis/listcambien.dart' as globals;
import 'package:mview/widget/dialog/config_diaglog.dart';
import 'package:mview/widget/dialog/history_diaglog.dart';
import 'package:mview/widget/dialog/thumuc_dialog.dart';
import 'package:mview/widget/kieuhienthi/cacbaistem/lenmensuachua.dart';
import 'package:mview/widget/kieuhienthi/cacbaistem/nhakinhthongminh.dart';
import 'package:mview/widget/kieuhienthi/cacbaistem/stemlosaynongsan.dart';
import 'package:mview/widget/kieuhienthi/cacbaistem/stemtenluanuoc.dart'; // import mới
import 'package:mview/widget/manhinhchinh/bocuc1manhinh.dart';
import 'package:mview/widget/manhinhchinh/bocuc2manhinhdoc.dart';
import 'package:mview/widget/manhinhchinh/bocuc2manhinhngang.dart';
import 'package:mview/widget/manhinhchinh/bocuc3manhinh.dart';
import 'package:mview/widget/manhinhchinh/manhinhdoctheodiem.dart';
import 'package:mview/widget/manhinhchinh/manhinhdongxoaychieu.dart';
import 'package:mview/widget/manhinhchinh/manhinhhome.dart';
import 'package:mview/widget/manhinhchinh/manhinhsongam.dart';
import 'package:mview/widget/popup/popupbocuc.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/foundation.dart';
import 'Model/cambien.dart';
import 'manager/connection_manager.dart';
import 'widget/dialog/bluetooth_dialog.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  if (kIsWeb) {
    runApp(const TestApp());
  } else if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    WindowOptions options = const WindowOptions(
      fullScreen: true, // Toàn màn hình
      center: true,
      // titleBarStyle: TitleBarStyle.hidden, // Ẩn thanh tiêu đề nếu muốn
    );
    windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      // await windowManager.setPreventClose(true); // Ngăn người dùng đóng nếu cần
      await windowManager.setFullScreen(false); // Toàn màn hình
      await windowManager
          .maximize(); // cửa sổ full màn hình nhưng vẫn có thanh tiêu đề
      await windowManager.setResizable(false);
    });
    runApp(const TestApp());
  } else {
    runApp(const TestApp());
  }
  final box = GetStorage();
  await box.remove('history_list');
  // Lấy danh sách hiện tại từ storage (nếu có)
  List<Map<String, dynamic>> currentHistoryy = box.read('history_list') ?? [];
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    return MaterialApp(
      navigatorKey: navigatorKey, // 👈 thêm dòng này
      theme: ThemeData(
        textTheme: GoogleFonts
            .dmSansTextTheme(), // Replace 'roboto' with your desired font
      ),
      home: SafeArea(
        child: Scaffold(
          body: MainWidget(),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainWidget extends StatefulWidget {
  const MainWidget({super.key});

  @override
  State<StatefulWidget> createState() {
    return MyWidget();
  }
}

class MyWidget extends State<MainWidget> {
  late int _selectedBocuc = 0;
  late StreamController<DulieuCB> _streamController;
  final box = GetStorage();
  List<String> selectedPorts = [];
  final Map<String, int> portMap = {
    "A1": 1,
    "A2": 2,
    "S1": 3,
    "S2": 4,
    "S3": 5,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double height = constraints.maxHeight;

        return Column(
          children: [
            SizedBox(
              height: height * 0.12, // 10% cho thanh công cụ
              child: _ThanhCongCu(parent: this),
            ),
            Container(
              height: height * 0.01, // hoặc height * 0.01 nếu muốn theo tỷ lệ
              color: Colors.black, // padding có màu đen
            ), // Padding cố định 8px giữa các phần
            SizedBox(
              height: height * 0.87, // Trừ phần padding ra để tránh tràn
              child: Container(
                color: Colors.white,
                child: _getBocucWidget(),
              ),
            ),
          ],
        );
      },
    );
  }

  void bluetoothButton() {
    showDialog(
      context: context,
      barrierDismissible: true, // bấm ra ngoài để đóng
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          elevation: 10,
          child: Stack(
            children: [
              const ConnectionDialog(),
            ],
          ),
        );
      },
    );
  }

  void thumucButton() async {
    final result = await showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: const ThumucDialog(),
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedBocuc = result + 10; // lưu vào biến
      });
      print("Người dùng chọn bài số: $_selectedBocuc");
    }
  }

  void configButton() {
    showDialog(
      context: context,
      barrierDismissible: true, // bấm ra ngoài để đóng
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          elevation: 10,
          child: Stack(
            children: [
              const ConfigDialogContent(),
            ],
          ),
        );
      },
    );
  }

  void historyButton() {
    showDialog(
      context: context,
      barrierDismissible: true, // bấm ra ngoài để đóng
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          elevation: 10,
          child: Stack(
            children: [
              HistoryDialogContent(
                onView: (selectedItem) {
                  viewHistory(selectedItem);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void viewHistory(Map<String, dynamic> selectedItem) async {
    globals.tansolaymau = selectedItem['tansolaymau'];
    globals.historyViewMode.value = true;
    globals.historySelected = selectedItem;
    _streamController.add(DulieuCB(
        id: '', tenCambien: '', giaTri: [], datLai: true, xoaCambien: true));
    // print("Đang xem: $selectedItem");

    // final List<String> tenThietBiTrongHistory = (selectedItem['thietbi'] as Map<String, dynamic>).keys.toList();
    //
    // globals.SodoCambienList = globals.SodoCambienListHistory
    //     .where((cb) => tenThietBiTrongHistory.contains(cb.tenCambien))
    //     .toList();

    setState(() {}); // Nếu cần cập nhật giao diện
  }

  void HomeButton() {
    _streamController.add(DulieuCB(
        id: '', tenCambien: '', giaTri: [], datLai: true, xoaCambien: true));
  }

  void DangPhatTrien() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 20.0, horizontal: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.construction,
                  size: 40,
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tính năng đang phát triển!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void CongcuButton() {}

  @override
  void initState() {
    _streamController = StreamController<DulieuCB>.broadcast();

    globals.clearData.addListener(() async {
      if (globals.clearData.value == true && mounted) {
        _streamController.add(DulieuCB(
            id: '',
            tenCambien: '',
            giaTri: [],
            datLai: true,
            xoaCambien: true));
        globals.clearData.value = false;
      }
    });
    ConnectionManager().init(
        context: context,
        onDisconnectedAll: () {
          // Callback khi tất cả thiết bị bị ngắt kết nối
          setState(() {
            // Nếu đang ở chế độ Start => Dừng lại
            if (globals.isStartPress) {
              globals.isStartPress = false;
              globals.requestOff.value =
                  true; // để widget start nhận được tín hiệu
            }
          });
        });
  }

  final Map<BleDevice, StreamSubscription<List<int>>> _subscriptions = {};
  int timeHistory = 1;
  Map<String, dynamic> history = {
    'thietbi': {},
  };
  final Map<String, List<double>> _bufferedValues = {};
  Timer? _timer;
  final Lock _lock = Lock();

  void startBatchStream() {
    _timer?.cancel(); // nếu có timer cũ
    int time = globals.tansolaymau >= 50
        ? globals.tansolaymau
        : 50; // thời gian lấy mẫu
    if (_selectedBocuc == 6) time = 200;
    _timer = Timer.periodic(Duration(milliseconds: time), (_) {
      _lock.synchronized(() {
        _bufferedValues.forEach((key, values) {
          final parts = key.split(',');
          final tenCambien = parts.length > 1 ? parts.sublist(1).join(',') : '';
          if (values.isNotEmpty) {
            _streamController.add(DulieuCB(
              id: key,
              tenCambien: tenCambien,
              // or parse sensor name if needed
              giaTri: List.of(values),
              datLai: false,
              xoaCambien: false,
            ));
            // print('values from $key: $values');
            values.clear();
          }
        });
      });
    });
  }

  void stopBatchStream() {
    _timer?.cancel();
    _timer = null;
  }

  void writeToDevices(List<int> data, bool isStart) async {
    bool first = false;
    Set<dynamic> processedDeviceIds =
        {}; // dùng dynamic để tương thích với kiểu device của bạn

    if (isStart) {
      _streamController.add(DulieuCB(
        id: '',
        tenCambien: '',
        giaTri: [],
        datLai: true,
        xoaCambien: true,
      ));
      startBatchStream();
    } else {
      saveHistoryToStorage();
      stopBatchStream();
    }

    int totalDevices =
        globals.SodoCambienList.map((e) => e.bluetoothDevice).toSet().length;
    int finishedDevices = 0;

    for (SodoCambien sodocambien in globals.SodoCambienList) {
      final device = sodocambien.bluetoothDevice;
      final deviceId = device.deviceId;
      if (processedDeviceIds.contains(deviceId)) {
        continue;
      }
      processedDeviceIds.add(deviceId);

      try {
        // discover services via universal_ble (auto-discover)
        List<BleService> services =
            await UniversalBle.discoverServices(deviceId);

        for (BleService service in services) {
          final serviceUuid = service.uuid;
          if (!globals.serviceUuid.contains(serviceUuid)) continue;

          for (final characteristic in service.characteristics) {
            final charUuid = characteristic.uuid;
            if (!globals.characteristicUuid.contains(charUuid)) continue;

            // 1) Bật notify trước khi write để không mất gói đầu tiên
            try {
              await UniversalBle.subscribeNotifications(
                  deviceId, serviceUuid, charUuid);
            } catch (e) {
              debugPrint(
                  "subscribeNotifications failed for ${device.name} $serviceUuid/$charUuid : $e");
              // nếu subscribe thất bại, vẫn thử write (tuỳ bạn) — ở đây ta tiếp tục
            }

            // 2) Nếu đang bắt đầu đo (isStart) thì tạo subscription (1 subscription per device)
            if (isStart) {
              if (!_subscriptions.containsKey(device)) {
                // dùng characteristicValueStream để chỉ lắng nghe đúng đặc tính này
                final subscription =
                    UniversalBle.characteristicValueStream(deviceId, charUuid)
                        .listen((rawUint8) async {
                  // rawUint8 là Uint8List (List<int>), giữ nguyên xử lý cũ của bạn
                  final dataList = rawUint8; // Uint8List implements List<int>
                  // print(
                  //     "📥 Data received (${dataList.length} bytes): "
                  //         "${dataList.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}"
                  // );

                  int vitriX = device.name?.indexOf('-') ?? -1;
                  String tcb = "";
                  if (vitriX > 0) {
                    tcb = device.name?.substring(0, vitriX) ?? '';
                  }

                  if (_selectedBocuc >= 10 && tcb == "Mlab") {
                    xuLyDuLieuStem(device, dataList);
                  } else {
                    if (dataList.isNotEmpty &&
                        dataList[0] == 0x02 &&
                        dataList[dataList.length - 1] == 0x03) {
                      int vitri = device.name?.indexOf('-') ?? -1;
                      String tencambien = "";
                      if (vitri > 0) {
                        tencambien = device.name?.substring(0, vitri) ?? '';
                      }
                      List<double> listGiatriCambien = [];
                      if (tencambien == "V&A") {
                        xuLyDulieuDongap(device, dataList);
                      } else if (tencambien == "SoundF") {
                        xuLyDulieuAmthanh(device, dataList);
                      } else if (tencambien == "QD") {
                        xuLyDulieuQuangdien(device, dataList);
                      } else if (tencambien == "Alt_Acc") {
                        xuLyDulieuDocao(device, dataList);
                      } else {
                        String name = "";
                        for (Cambien cambien in globals.cambiens) {
                          if (cambien.id == tencambien) {
                            name = cambien.name;
                            break;
                          }
                        }
                        String key = '${device.name},$name';

                        for (int i = 0; i < (dataList.length - 2) / 4; i++) {
                          // tạo view trực tiếp trên Uint8List
                          ByteData byteData = ByteData.sublistView(
                              Uint8List.fromList(dataList),
                              i * 4 + 1,
                              i * 4 + 5);
                          double value = byteData.getFloat32(0, Endian.little);
                          listGiatriCambien.add(value);
                        }
                        _lock.synchronized(() {
                          _bufferedValues.putIfAbsent(key, () => []);
                          _bufferedValues[key]!.addAll(listGiatriCambien);
                        });
                      }

                      // xử lý điều kiện dừng / lưu history (giữ nguyên)
                      if ((globals.selectedKetThuc == 3 &&
                              globals.soLuongCount < globals.soLuongMau) ||
                          globals.selectedKetThuc == 1 ||
                          (globals.selectedKetThuc == 2 &&
                              (globals.soLuongCount *
                                      globals.tansolaymau /
                                      1000) <
                                  globals.selectedThoigianMs / 1000)) {
                        globals.soLuongCount += listGiatriCambien.length;

                        // Lưu dữ liệu vào history
                        if (!history['thietbi'].containsKey(device.name)) {
                          history['thietbi'][device.name] = {
                            'donVi': sodocambien.donvi![0],
                            'data': listGiatriCambien,
                          };
                        } else {
                          history['thietbi'][device.name]['data']
                              .addAll(listGiatriCambien);
                        }
                      } else {
                        // hết điều kiện -> dừng thiết bị này
                        final sub = _subscriptions[device];
                        if (sub != null) {
                          await sub.cancel();
                          _subscriptions.remove(device);
                        }
                        globals.isStartPress = false;
                        globals.soLuongCount = 0;
                        List<int> stopData = [0x02, 0x79, 0x00, 0x00, 0x03];

                        // gửi lệnh stop tới thiết bị bằng universal_ble
                        try {
                          await UniversalBle.write(deviceId, serviceUuid,
                              charUuid, Uint8List.fromList(stopData));
                        } catch (e) {
                          debugPrint(
                              "Error writing stopData to ${device.name}: $e");
                        }

                        // tắt notify cho đặc tính
                        try {
                          await UniversalBle.unsubscribe(
                              deviceId, serviceUuid, charUuid);
                        } catch (e) {
                          debugPrint(
                              "unsubscribe failed for ${device.name}: $e");
                        }

                        finishedDevices++;
                        if (finishedDevices == totalDevices) {
                          saveHistoryToStorage();
                        }
                        setState(() {});
                      }
                    }
                  }
                });

                _subscriptions[device] = subscription;
              }
            } // end if isStart

            // 3) Viết dữ liệu (viết sau khi đã subscribe để không mất gói)
            try {
              await UniversalBle.write(
                deviceId,
                serviceUuid,
                charUuid,
                Uint8List.fromList(data),
              );
            } catch (e) {
              print('Error writing to ${device.name}: $e');
              // nếu write lỗi thì tiếp tục device khác
              continue;
            }

            // 4) Nếu không phải isStart (tức là stop), gỡ subscription và reset như cũ
            if (!isStart) {
              final sub = _subscriptions[device];
              if (sub != null) {
                await sub.cancel();
                _subscriptions.remove(device);
              }
              globals.soLuongCount = 0;

              // tắt notify nếu vẫn còn
              try {
                await UniversalBle.unsubscribe(deviceId, serviceUuid, charUuid);
              } catch (e) {
                debugPrint("unsubscribe error for ${device.name}: $e");
              }

              setState(() {});
            }
          } // end for characteristics
        } // end for services
      } catch (e) {
        debugPrint("Error in writeToDevices for ${device.name}: $e");
      }
    } // end for each SodoCambien
  }

  void xuLyDulieuDongap(BleDevice device, List<int> data) {
    List<double> mangAp = [];
    List<double> mangDong = [];

    int payloadSize = data.length - 2;

    if (payloadSize % 4 != 0) {
      print("BLE: Payload không chia hết cho 4: $payloadSize");
      return;
    }

    for (int i = 0; i < payloadSize; i += 4) {
      int index = i + 1; // bỏ byte đầu tiên (0x02)

      if (index + 3 >= data.length - 1) {
        print("BLE: Bỏ qua mẫu cuối do thiếu byte");
        break;
      }

      int rawVoltage = data[index] | (data[index + 1] << 8);
      double voltage = (rawVoltage / 100.0) - 24.0;

      int rawCurrent = data[index + 2] | (data[index + 3] << 8);
      double current = (rawCurrent / 1000.0) - 2.0;
      // _bufferedValues.add(voltage);
      mangAp.add(voltage);
      mangDong.add(current);
    }
    final keyAp = "${device.name},${globals.cambiens[11].name}";
    final keyDong = "${device.name},${globals.cambiens[10].name}";

    _lock.synchronized(() {
      _bufferedValues.putIfAbsent(keyAp, () => []);
      _bufferedValues.putIfAbsent(keyDong, () => []);

      _bufferedValues[keyAp]!.addAll(mangAp);
      _bufferedValues[keyDong]!.addAll(mangDong);
    });
  }

  void xuLyDulieuQuangdien(BleDevice device, List<int> data) {
    List<double> mangAp = [];
    List<double> mangDong = [];

    if (data.length < 10) return; // ít nhất phải có 1 mẫu

    int payloadSize = data.length - 2; // bỏ 0x02 và 0x03

    if (payloadSize % 8 != 0) {
      print("BLE: Payload không chia hết cho 8: $payloadSize");
      return;
    }

    Uint8List bytes = Uint8List.fromList(data);
    ByteData byteData = bytes.buffer.asByteData();

    for (int i = 0; i < payloadSize; i += 8) {
      int index = i + 1; // bỏ byte start 0x02

      if (index + 7 >= data.length - 1) {
        print("BLE: Bỏ qua mẫu cuối do thiếu byte");
        break;
      }

      double voltage = byteData.getFloat32(index, Endian.little);
      double current = byteData.getFloat32(index + 4, Endian.little);

      mangAp.add(voltage);
      mangDong.add(current);
    }

    final keyAp = "${device.name},${globals.cambiens[11].name}";
    final keyDong = "${device.name},${globals.cambiens[10].name}";

    _lock.synchronized(() {
      _bufferedValues.putIfAbsent(keyAp, () => []);
      _bufferedValues.putIfAbsent(keyDong, () => []);

      _bufferedValues[keyAp]!.addAll(mangAp);
      _bufferedValues[keyDong]!.addAll(mangDong);
    });
  }

  void xuLyDulieuDocao(BleDevice device, List<int> data) {
    List<double> mangAltitude = [];
    List<double> mangAccelZ = [];

    if (data.length < 10) return; // ít nhất phải có 1 mẫu

    int payloadSize = data.length - 2; // bỏ 0x02 và 0x03

    if (payloadSize % 8 != 0) {
      print("BLE: Payload không chia hết cho 8: $payloadSize");
      return;
    }

    Uint8List bytes = Uint8List.fromList(data);
    ByteData byteData = bytes.buffer.asByteData();

    for (int i = 0; i < payloadSize; i += 8) {
      int index = i + 1; // bỏ byte start 0x02

      if (index + 7 >= data.length - 1) {
        print("BLE: Bỏ qua mẫu cuối do thiếu byte");
        break;
      }

      double altitude = byteData.getFloat32(index, Endian.little);
      double accZ = byteData.getFloat32(index + 4, Endian.little);

      mangAltitude.add(altitude);
      mangAccelZ.add(accZ);
    }

    final keyAltitude = "${device.name},${globals.cambiens[15].name}";
    final keyAccZ = "${device.name},${globals.cambiens[16].name}";

    _lock.synchronized(() {
      _bufferedValues.putIfAbsent(keyAltitude, () => []);
      _bufferedValues.putIfAbsent(keyAccZ, () => []);

      _bufferedValues[keyAltitude]!.addAll(mangAltitude);
      _bufferedValues[keyAccZ]!.addAll(mangAccelZ);
    });
  }

  final Map<String, PackGroup> _packGroups = {};

  void xuLyDulieuAmthanh(BleDevice device, List<int> data) {
    if (data.length < 3) return;

    int packetIndex = data[1];
    final keyAmthanh = "${device.name},${globals.cambiens[12].name}";
    final keyGroup = device.name;

    // 🟢 Trường hợp đặc biệt: packIndex == 20 → dữ liệu float
    if (packetIndex == 20) {
      List<double> mangAmthanh = [];

      int payloadSize = data.length - 3;
      if (payloadSize % 4 != 0) {
        print("BLE: Payload không chia hết cho 4: $payloadSize");
        return;
      }

      for (int i = 0; i < payloadSize; i += 4) {
        int index = i + 2;
        if (index + 3 >= data.length) break;

        Uint8List floatBytes =
            Uint8List.fromList(data.sublist(index, index + 4));
        ByteData byteData = ByteData.sublistView(floatBytes);
        double amthanh = byteData.getFloat32(0, Endian.little);

        mangAmthanh.add(amthanh);
      }

      _lock.synchronized(() {
        _bufferedValues.putIfAbsent(keyAmthanh, () => []);
        _bufferedValues[keyAmthanh]!.addAll(mangAmthanh);
      });

      return; // ⛔️ Không xử lý tiếp phía dưới
    }
    int payloadSize = data.length - 3;
    if (payloadSize % 2 != 0) {
      print("BLE: Payload không chia hết cho 2: $payloadSize");
      return;
    }

    List<double> mangAmthanh = [];

    for (int i = 0; i < payloadSize; i += 2) {
      int index = i + 2;
      if (index + 1 >= data.length) break;

      int raw = (data[index] & 0xFF) | ((data[index + 1] & 0xFF) << 8);
      double amthanh = (raw / 1000.0) - 10.0;
      mangAmthanh.add(amthanh);
    }
    // String formattedPack = mangAmthanh.map((x) => x.toStringAsFixed(2)).join(', ');
    // print("Pack float index $packetIndex, số mẫu: ${mangAmthanh.length}, dữ liệu: $formattedPack");

    // 🧠 Gom 4 pack lại theo đúng thứ tự
    _packGroups.putIfAbsent(keyGroup!, () => PackGroup());
    final group = _packGroups[keyGroup]!;

    group.addPack(packetIndex, mangAmthanh);

    if (group.isComplete()) {
      List<double> fullWave = group.merge();

      // String formatted = fullWave.map((x) => x.toStringAsFixed(2)).join(', ');
      // print("Group đủ 4 pack, số mẫu: ${fullWave.length}, dữ liệu: $formatted");

      _lock.synchronized(() {
        _bufferedValues.putIfAbsent(keyAmthanh, () => []);
        _bufferedValues[keyAmthanh]!.addAll(fullWave);
      });

      group.reset(); // chuẩn bị cho nhóm tiếp theo
    }
  }

  void xuLyDuLieuStem(BleDevice device, List<int> frame) {
    final values = parseDueFrame(frame);
    if (values.length != selectedPorts.length) {
      print("Frame error: port count mismatch");
      return;
    }

    for (int i = 0; i < selectedPorts.length; i++) {
      double sensorValue = values[i] * 1.0;
      String sensorId = selectedPorts[i];

      final key = "${device.name},$sensorId";
      // print(key);
      _lock.synchronized(() {
        _bufferedValues.putIfAbsent(key, () => []);
        _bufferedValues[key]!.add(sensorValue);
      });
    }
  }

  List<int> parseDueFrame(List<int> frame) {
    if (frame.length < 4) return [];

    if (frame.first != 0x02 || frame.last != 0x03) {
      print("Frame error: wrong markers");
      return [];
    }

    int len = frame[1];
    if (len != frame.length - 3) {
      print("Frame error: len mismatch");
      return [];
    }

    List<int> values = [];
    for (int i = 2; i < frame.length - 1; i += 2) {
      int hi = frame[i];
      int lo = frame[i + 1];
      int value = (hi << 8) | lo;
      values.add(value);
    }

    return values; // trả về list giá trị theo đúng thứ tự port
  }

  void saveHistoryToStorage() async {
    history['tansolaymau'] = globals.tansolaymau;
    history['time'] = timeHistory;
    timeHistory++;
    // Lấy danh sách hiện tại từ storage (nếu có)
    List<Map<String, dynamic>> currentHistory = box.read('history_list') ?? [];

    // Thêm item mới vào danh sách
    currentHistory.add(history);

    // Lưu lại danh sách vào GetStorage
    await box.write('history_list', currentHistory);
    history = {'thietbi': {}};
    print('History saved to storage');
  }

  @override
  void dispose() {
    _streamController.close();
    for (var bleDevice in globals.SodoCambienList) {
      UniversalBle.disconnect(bleDevice.bluetoothDevice.deviceId);
    }
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      box.remove('history_list');
      print('App closed, history_list cleared');
    }
  }

  Widget _getBocucWidget() {
    switch (_selectedBocuc) {
      case 0:
        return ManhinhHome(
          onClickManhinhHome: HandleBocucSelected,
        );
      case 1:
        return Bocuc1Manhinh(
          stream: _streamController.stream,
        );
      case 2:
        return Bocuc2Manhinhngang(stream: _streamController.stream);
      case 3:
        return Bocuc2Manhinhdoc(stream: _streamController.stream);
      case 4:
        return Bocuc3Manhinh(stream: _streamController.stream);
      case 5:
        return ManhinhDocTheoDiem(stream: _streamController.stream);
      case 6:
        return Manhinhdongxoaychieu(streamReadData: _streamController.stream);
      case 7:
        return const ManhinhSongam();
      case 10:
        return StemNhaKinh(
          stream: _streamController.stream,
          tenbaihoc: globals.lession[_selectedBocuc - 10],
        );
      case 11:
        return StemLoSayNongSan(
          stream: _streamController.stream,
          tenbaihoc: globals.lession[_selectedBocuc - 10],
          onPortsChanged: (ports) {
            selectedPorts = ports;
            print("Cổng đã chọn: $selectedPorts");
          },
        );
      case 12:
        return StemSuaChua(
          stream: _streamController.stream,
          tenbaihoc: globals.lession[_selectedBocuc - 10],
        );
      case 13:
        return StemThuyCanhScreen(
          stream: _streamController.stream,
          tenbaihoc: globals.lession[_selectedBocuc - 10],
        );
      case 14:
        return StemTenluaNuocScreen(
          stream: _streamController.stream,
          tenbaihoc: globals.lession[_selectedBocuc - 10],
        );
      default:
        return Container(color: Colors.white);
    }
  }

  void HandleBocucSelected(int bocuc) {
    setState(() {
      _selectedBocuc = bocuc;
    });
  }
}

class FunctionButton extends StatelessWidget {
  const FunctionButton({
    super.key,
    required this.nameButton,
    required this.iconButton,
    required this.function,
  });

  final String nameButton;
  final IconData iconButton;
  final void Function()? function;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: function,
      child: SizedBox(
        height: double.infinity,
        width: MediaQuery.of(context).size.width * 0.09,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              flex: 4, // Giảm flex để button nhỏ lại
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Icon(
                    iconButton,
                    size: 60, // nhỏ lại
                    color: Color(globals.MyColors.mamau['xanhdatroi']!),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2, // Tăng flex cho text
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AutoSizeText(
                  nameButton,
                  maxLines: 2,
                  minFontSize: 10,
                  maxFontSize: 18,
                  // chữ to hơn
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13), // chữ mặc định to
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThanhCongCu extends StatelessWidget {
  const _ThanhCongCu({required this.parent});

  final MyWidget parent;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE1E1E1),
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          // Nhóm 5 button đầu tiên sát trái có padding và spacing giữa các button
          Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FunctionButton(
                  function: () => parent.HandleBocucSelected(0),
                  nameButton: 'Home',
                  iconButton: Icons.home,
                ),
                const SizedBox(width: 8),
                FunctionButton(
                  function: parent.bluetoothButton,
                  nameButton: 'Kết nối',
                  iconButton: Icons.bluetooth,
                ),
                const SizedBox(width: 8),
                FunctionButton(
                  function: parent.DangPhatTrien,
                  nameButton: 'Công cụ',
                  iconButton: Icons.build,
                ),
                const SizedBox(width: 8),
                PopupButton(parent: parent),
                const SizedBox(width: 8),
                Container(
                  child: FunctionButton(
                    function: parent.thumucButton,
                    nameButton: 'Thư mục',
                    iconButton: Icons.folder,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  child: FunctionButton(
                    function: parent.configButton,
                    nameButton: 'Cài đặt',
                    iconButton: Icons.settings,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  child: FunctionButton(
                    function: parent.historyButton,
                    nameButton: 'Lịch sử',
                    iconButton: Icons.history,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StartMainWidget(parent: parent),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PopupButton extends StatefulWidget {
  final MyWidget parent;

  const PopupButton({super.key, required this.parent});

  @override
  _PopupButtonState createState() => _PopupButtonState();
}

class _PopupButtonState extends State<PopupButton> {
  final LayerLink _layerLink = LayerLink();
  late MyWidget funtionparent;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    funtionparent = widget.parent;
  }

  void _showPopup() {
    if (_overlayEntry == null) {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
    }
  }

  void _hidePopup() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    return OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: _hidePopup,
        child: Material(
          color: Colors.transparent,
          child: Center(
            // Căn giữa Popup
            child: Container(
              width: MediaQuery.of(context).size.width * 0.2,
              height: MediaQuery.of(context).size.width * 0.2,
              child: PopupBocuc(
                onClose: _hidePopup,
                onBocucSelected: funtionparent.HandleBocucSelected,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: FunctionButton(
        function: _showPopup,
        nameButton: 'Bố cục',
        iconButton: Icons.widgets,
      ),
    );
  }
}

class _StartMainWidget extends StatefulWidget {
  const _StartMainWidget({required this.parent});

  final MyWidget parent;

  @override
  State<_StartMainWidget> createState() => _StartMainWidgetState();
}

class _StartMainWidgetState extends State<_StartMainWidget> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _StartPressFunction,
      child: SizedBox(
        height: double.infinity,
        width: MediaQuery.of(context).size.width * 0.09,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              flex: 4, // đồng bộ với FunctionButton
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: globals.isStartPress
                      ? Color(globals.MyColors.mamau['doStop']!)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Icon(
                    globals.isStartPress ? Icons.stop : Icons.play_arrow,
                    size: 60, // đồng bộ với FunctionButton
                    color: globals.isStartPress
                        ? Colors.white
                        : const Color(0xFF1FB6FC),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2, // đồng bộ với FunctionButton
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AutoSizeText(
                  globals.isStartPress ? "Dừng lại" : "Bắt đầu",
                  maxLines: 2,
                  minFontSize: 10,
                  maxFontSize: 18,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13), // chữ mặc định to
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    globals.requestOff.addListener(() async {
      if (globals.requestOff.value == true) {
        List<int> data = [0x02, 0x79, 0x00, 0x00, 0x03];
        if (globals.isStartPress) {
          widget.parent.writeToDevices(data, false);
          setState(() {
            globals.isStartPress = false;
            globals.requestOff.value = false;
          });
        }
      }
    });
  }

  void _StartPressFunction() {
    // Kiểm tra danh sách rỗng
    if (globals.SodoCambienList.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Thông báo"),
          content: const Text("Chưa có cảm biến nào được chọn!"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return; // Dừng không thực hiện tiếp
    }
    globals.historyViewMode.value = false;

    // Nếu có dữ liệu thì tiếp tục như bình thường
    setState(() {
      globals.isStartPress = !globals.isStartPress;
    });

    if (globals.isStartPress) {
      List<int> data = [0x01];
      if (widget.parent._selectedBocuc == 6) {
        data[0] = 0x03;
        ByteData byteData = ByteData(4);
        byteData.setInt32(0, globals.tansolaymau * 1000);
        List<int> byteArray = byteData.buffer.asUint8List();
        data.addAll(byteArray);
      } else if (widget.parent._selectedBocuc == 11) {
        data[0] = 0x02; // start
        data.addAll(
            buildFrame(widget.parent.selectedPorts, globals.tansolaymau));
      } else {
        ByteData byteData = ByteData(4);
        byteData.setInt32(0, globals.tansolaymau);
        List<int> byteArray = byteData.buffer.asUint8List();
        data.addAll(byteArray);
      }
      widget.parent.writeToDevices(data, true);
    } else {
      // Gửi lệnh dừng
      List<int> data = [0x02, 0x79, 0x00, 0x00, 0xFF];
      widget.parent.writeToDevices(data, false);
    }
  }

  List<int> buildFrame(List<String> selectedPorts, int tanSo) {
    List<int> data = [];

    // map tên cổng sang số

    // phần payload (chưa có len, start, end)
    List<int> payload = [];

    payload.add(0x00); // command

    for (var p in selectedPorts) {
      if (widget.parent.portMap.containsKey(p)) {
        payload.add(widget.parent.portMap[p]!);
      }
    }
    // tần số -> 2 byte big-endian
    payload.add((tanSo >> 8) & 0xFF); // high byte
    payload.add(tanSo & 0xFF); // low byte
    // len = độ dài payload
    data.add(payload.length);
    // add payload
    data.addAll(payload);
    // end
    data.add(0xFF);
    return data;
  }
}

class PackGroup {
  int? startIndex; // Khởi tạo khi gặp pack đầu tiên
  Map<int, List<double>> pendingPacks = {};

  void reset() {
    startIndex = null;
    pendingPacks.clear();
  }

  bool addPack(int packIndex, List<double> values) {
    if (startIndex == null) {
      // Chỉ nhận pack bắt đầu từ index 1 hoặc bất kỳ giá trị bạn chọn là đầu
      startIndex = packIndex;
      pendingPacks[packIndex] = values;
      return isComplete();
    }

    // Nếu nhận pack ngoài dải [startIndex, startIndex+3] thì reset
    if (packIndex < startIndex! || packIndex > startIndex! + 3) {
      print("PackGroup: Nhận pack không hợp lệ ($packIndex), reset nhóm.");
      reset();
      startIndex = packIndex;
      pendingPacks[packIndex] = values;
      return isComplete();
    }

    // Nếu nhận pack đã có thì cảnh báo
    if (pendingPacks.containsKey(packIndex)) {
      print("PackGroup: Nhận pack lặp ($packIndex), ghi đè.");
    }

    pendingPacks[packIndex] = values;
    return isComplete();
  }

  bool isComplete() {
    if (startIndex == null) return false;
    for (int i = 0; i < 4; i++) {
      if (!pendingPacks.containsKey(startIndex! + i)) {
        return false;
      }
    }
    return true;
  }

  List<double> merge() {
    List<double> merged = [];
    if (startIndex == null) return merged;
    for (int i = 0; i < 4; i++) {
      merged.addAll(pendingPacks[startIndex! + i]!);
    }
    return merged;
  }
}
