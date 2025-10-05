import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:universal_ble/universal_ble.dart';   // ✅ đổi thư viện
import 'package:get_storage/get_storage.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:testproject/ultis/listcambien.dart' as globals;
import 'package:share_plus/share_plus.dart';

class HistoryDialogContent extends StatefulWidget {
  final void Function(Map<String, dynamic> selectedItem)? onView;

  const HistoryDialogContent({super.key, this.onView});

  @override
  _HistoryDialogContentState createState() => _HistoryDialogContentState();
}


class _HistoryDialogContentState extends State<HistoryDialogContent> {
  List<Map<String, dynamic>> historyList = [];
  Set<int> selectedIndexes = {};
  final box = GetStorage();

  Future<String?> showFileNameDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();

    if (Platform.isIOS) {
      return showCupertinoDialog<String>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: Text('Nhập tên file'),
          content: Column(
            children: [
              SizedBox(height: 10),
              CupertinoTextField(
                controller: controller,
                placeholder: 'Tên file (không có .csv)',
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: Text('Hủy'),
              onPressed: () => Navigator.pop(context, null),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: Text('OK'),
              onPressed: () {
                final text = controller.text.trim();
                Navigator.pop(context, text.isEmpty ? null : text);
              },
            ),
          ],
        ),
      );
    } else {
      return showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Nhập tên file'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Tên file (không có .csv)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                Navigator.pop(context, text.isEmpty ? null : text);
              },
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> exportSelectedCsv({
    required BuildContext context,
    required List<Map<String, dynamic>> historyList,
    required Set<int> selectedIndexes,
  }) async {
    // Hiển thị hộp thoại nhập tên file
    final TextEditingController fileNameController = TextEditingController();
    final fileName = await showFileNameDialog(context);

    // Nếu người dùng bấm "Hủy" hoặc không nhập gì thì không xuất
    if (fileName == null || fileName.isEmpty) return;

    final selectedData = selectedIndexes.isEmpty
        ? historyList
        : selectedIndexes.map((i) => historyList[i]).toList();
    final List<List<dynamic>> csvRows = [];

    // Dòng 1: Số lần chạy
    List<String> headerRunCount = [];
    // Dòng 2: Chi tiết cột
    List<String> headerDetail = [];

    for (int i = 0; i < selectedData.length; i++) {
      final dataMap = Map<String, dynamic>.from(selectedData[i]);
      final thietbis = Map<String, dynamic>.from(dataMap['thietbi']);

      int colCount = 1 + thietbis.length;
      headerRunCount.add('Chạy ${dataMap['time']} (${dataMap['tansolaymau'] / 1000}Hz)');
      for (int j = 1; j < colCount; j++) {
        headerRunCount.add('');
      }

      headerDetail.add('Thời gian');
      for (final tbKey in thietbis.keys) {
        final tbValue = Map<String, dynamic>.from(thietbis[tbKey]);
        final donVi = tbValue['donVi'] ?? '';
        headerDetail.add('$tbKey ($donVi)');
      }
    }

    csvRows.add(headerRunCount);
    csvRows.add(headerDetail);

    int maxRows = 0;
    for (final raw in selectedData) {
      final dataMap = Map<String, dynamic>.from(raw);
      final thietbis = Map<String, dynamic>.from(dataMap['thietbi']);
      for (final tb in thietbis.values) {
        final tbMap = Map<String, dynamic>.from(tb);
        final len = (tbMap['data'] as List).length;
        if (len > maxRows) maxRows = len;
      }
    }

    for (int i = 0; i < maxRows; i++) {
      final row = <dynamic>[];

      for (final raw in selectedData) {
        final dataMap = Map<String, dynamic>.from(raw);
        final thietbis = Map<String, dynamic>.from(dataMap['thietbi']);
        final sampleRate = dataMap['tansolaymau'] ?? 1000;
        final time = i * (sampleRate / 1000);

        row.add(time.toStringAsFixed(3));
        for (final tb in thietbis.values) {
          final tbMap = Map<String, dynamic>.from(tb);
          final values = tbMap['data'] as List;
          row.add(i < values.length ? values[i].toStringAsFixed(3) : '');
        }
      }

      csvRows.add(row);
    }

    final csv = const ListToCsvConverter().convert(csvRows);
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/$fileName.csv';
    final file = File(filePath);
    await file.writeAsString(csv);
    if (Platform.isIOS || Platform.isMacOS) {
      await Share.shareXFiles([XFile(filePath)], text: 'Xuất dữ liệu CSV');
    }

    // Nếu đang chạy trên Windows, thông báo đường dẫn
    if (Platform.isWindows) {
      final normalizedPath = filePath.replaceAll('/', '\\');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File được lưu tại: $normalizedPath'),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }


  Future<List<Map<String, dynamic>>> parseCsvToHistoryList(String csvContent) async {
    final csvData = const CsvToListConverter().convert(csvContent);

    if (csvData.length < 2) return [];

    final runTitleRow = csvData[0].map((e) => e.toString()).toList(); // "Chạy 1 (1.0Hz)"
    final headerRow = csvData[1].map((e) => e.toString()).toList();   // "Thời gian (s)", ...

    // Xác định vị trí các "Thời gian (s)" cho từng chạy
    final List<int> runIndexes = [];
    for (int i = 0; i < headerRow.length; i++) {
      if (headerRow[i].startsWith('Thời gian')) {
        runIndexes.add(i);
      }
    }

    final int runsCount = runIndexes.length;

    // Map vị trí chạy => list tên cột thiết bị
    Map<int, List<String>> deviceColumnsPerRun = {};
    for (int runStartIndex in runIndexes) {
      List<String> deviceCols = [];

      int start = runStartIndex + 1;
      int nextRunPos = runIndexes.firstWhere(
            (idx) => idx > runStartIndex,
        orElse: () => headerRow.length,
      );

      for (int j = start; j < nextRunPos; j++) {
        deviceCols.add(headerRow[j]);
      }

      deviceColumnsPerRun[runStartIndex] = deviceCols;
    }

    List<Map<String, dynamic>> historyList = [];

    for (int runIndex = 0; runIndex < runsCount; runIndex++) {
      int runStartIndex = runIndexes[runIndex];
      List<String> deviceCols = deviceColumnsPerRun[runIndexes[runIndex]]!; //
      String runTitle = runTitleRow[runIndexes[runIndex]];                  //
      final regHz = RegExp(r'\(([\d.]+)Hz\)');
      final matchHz = regHz.firstMatch(runTitle);
      double hz = matchHz != null ? double.tryParse(matchHz.group(1)!) ?? 1.0 : 1.0;
      int tansolaymau = (hz * 1000).round(); // đổi Hz -> ms


      // Lấy số lần chạy N từ "Chạy N (XHz)"
      final regRunN = RegExp(r'Chạy (\d+)');
      final matchRunN = regRunN.firstMatch(runTitle);
      int lanChay = matchRunN != null ? int.tryParse(matchRunN.group(1)!) ?? 1 : 1;

      Map<String, dynamic> thietbiMap = {};

      for (String colHeader in deviceCols) {
        final reg = RegExp(r'^(.*?) \((.*?)\)$');
        final match = reg.firstMatch(colHeader);
        if (match == null) continue;

        final deviceName = match.group(1) ?? '';
        final donVi = match.group(2) ?? '';

        final colIndex = runStartIndex + 1 + deviceCols.indexOf(colHeader); // ✅ SỬA Ở ĐÂY

        // Ép kiểu dữ liệu thành double
        List<double> values = [];
        for (int row = 2; row < csvData.length; row++) {
          final raw = csvData[row][colIndex];
          if (raw != null && raw.toString().trim().isNotEmpty) {
            values.add(double.tryParse(raw.toString()) ?? 0.0);
          }
        }
        thietbiMap[deviceName] = {
          'donVi': donVi,
          'data': values,
        };
      }
      historyList.add({
        'thietbi': thietbiMap,
        'tansolaymau': tansolaymau,
        'time': lanChay,
      });
    }

    return historyList;
  }




  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  void loadHistory() {
    final List<dynamic>? storedList = box.read('history_list');
    if (storedList != null) {
      setState(() {
        historyList = List<Map<String, dynamic>>.from(storedList);
      });
    }
  }

  void deleteHistoryItem(int index) {
    setState(() {
      historyList.removeAt(index);
      box.write('history_list', historyList);
    });
  }

  @override
  Widget build(BuildContext context) {
    var mediaQuery = MediaQuery.of(context);

    return SizedBox(
      height: mediaQuery.size.height * 0.6,
      width: mediaQuery.size.width * 0.35,
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
                  vertical: mediaQuery.size.height * 0.008,
                  horizontal: mediaQuery.size.width * 0.012,
                ),
                child: Center(
                  child: AutoSizeText(
                    'Lịch sử',
                    style: TextStyle(
                      fontSize: mediaQuery.size.width * 0.012,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 1,
                    minFontSize: 10,
                  ),
                ),
              ),

              // Action Icons
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionIcon(
                      icon: Icons.folder_open,
                      label: 'Mở',
                      onTap: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['csv'],
                        );

                        if (result != null && result.files.single.path != null) {
                          List<BleDevice> devices = globals.SodoCambienList
                              .map((sodo) => sodo.bluetoothDevice)
                              .toSet() // loại bỏ trùng
                              .toList();

                          globals.SodoCambienList.clear();
                          for (var device in devices) {
                            try {
                              // Connect to the device
                              await device.disconnect();
                              if (mounted) {
                                for (int i = 0; i < globals.SodoCambienList.length; i++) {
                                  if (device == globals.SodoCambienList[i].bluetoothDevice) {
                                    globals.SodoCambienList.removeAt(i);
                                    break;
                                  }
                                }
                              }
                            } catch (e) {
                              // Handle connection errors
                              print('Error disconnect to device: $e');
                            }
                          }

                          final file = File(result.files.single.path!);
                          final content = await file.readAsString();

                          final parsedHistoryList = await parseCsvToHistoryList(content);

                          // Gán lại biến toàn cục hoặc cập nhật trạng thái:
                          setState(() {
                            historyList = parsedHistoryList;
                            selectedIndexes = {};
                            box.write('history_list', historyList);
                          });
                        }
                      },
                    ),

                    _ActionIcon(
                      icon: Icons.save,
                      label: 'Lưu',
                      onTap: () {
                        exportSelectedCsv(
                          context: context,
                          historyList: historyList,
                          selectedIndexes: selectedIndexes,
                        );
                      },
                    ),
                    _ActionIcon(
                      icon: Icons.remove_red_eye,
                      label: 'Xem',
                      isActive: selectedIndexes.length == 1,
                      onTap: () {
                        if(selectedIndexes.length == 1){
                          final selectedItem = historyList[selectedIndexes.first];
                          widget.onView?.call(selectedItem);
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                    _ActionIcon(icon: Icons.delete, label: 'Xóa',onTap: () {
                      setState(() {
                        // Tạo danh sách mới loại bỏ các phần tử theo index đã chọn
                        historyList = [
                          for (int i = 0; i < historyList.length; i++)
                            if (!selectedIndexes.contains(i)) historyList[i]
                        ];
                        box.write('history_list', historyList);
                        selectedIndexes.clear();
                      });

                    }),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Danh sách lịch sử
              Expanded(
                child: historyList.isEmpty
                    ? const Center(child: Text("Không có dữ liệu"))
                    : ListView.builder(
                  itemCount: historyList.length,
                  itemBuilder: (context, index) {
                    final item = historyList[index];
                    final isSelected = selectedIndexes.contains(index);

                    return ListTile(
                      leading: isSelected
                          ? const Icon(Icons.check, color: Colors.green)
                          : const SizedBox(width: 24), // Giữ chỗ cho icon
                      title: Text('Lần ${item['time']} - ${(1000 / (item['tansolaymau'] ?? 0)).toInt()} Hz'),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            selectedIndexes.remove(index);
                          } else {
                            selectedIndexes.add(index);
                          }
                        });
                      },
                    );
                  },
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}


class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _ActionIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? Color(globals.MyColors.mamau['xanhdatroi']!)
        : Colors.grey;

    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}




