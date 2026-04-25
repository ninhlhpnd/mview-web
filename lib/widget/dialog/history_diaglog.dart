import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:universal_ble/universal_ble.dart';   // ✅ đổi thư viện
import 'package:permission_handler/permission_handler.dart';

import 'package:get_storage/get_storage.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:mview/ultis/listcambien.dart' as globals;
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
    String? fileName;
    while (true) {
      fileName = await showFileNameDialog(context);

      // Nếu người dùng bấm "Hủy" hoặc không nhập gì thì không xuất
      if (fileName == null || fileName.isEmpty) return;
      
      // Xác định đường dẫn file sẽ lưu
      String targetPath;
      if (Platform.isAndroid) {
        final publicDir = Directory('/storage/emulated/0/Documents');
        targetPath = '${publicDir.path}/$fileName.csv';
      } else {
        final dir = await getApplicationDocumentsDirectory();
        targetPath = '${dir.path}/$fileName.csv';
      }
      
      // Kiểm tra xem file đã tồn tại hay chưa
      if (await File(targetPath).exists()) {
        final bool? overwrite = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('File đã tồn tại'),
            content: Text('File "$fileName.csv" đã tồn tại. Bạn muốn ghi đè hay đổi tên khác?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false), // Đổi tên
                child: Text('Đổi tên'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true), // Ghi đè
                child: Text('Ghi đè', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        
        if (overwrite == true) {
          break; // Tiếp tục ghi đè
        } else {
          continue; // Lặp lại để chọn tên khác
        }
      } else {
        break; // File chưa tồn tại, có thể lưu tiếp
      }
    }

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





    // Sao chép tới thư mục công cộng (Documents) trên Android
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      if (Platform.isAndroid) {
        await Permission.storage.request();
        // Cố gắng ghi vào thư mục Documents chung của thiết bị
        final publicDir = Directory('/storage/emulated/0/Documents');
        if (!await publicDir.exists()) {
          await publicDir.create(recursive: true);
        }
        final publicPath = '${publicDir.path}/$fileName.csv';
        await file.copy(publicPath);
        
        // Lưu đường dẫn vào GetStorage để mở lại sau
        final List<String> saved = (box.read<List<dynamic>>('saved_csv_paths')?.cast<String>() ?? []);
        if (!saved.contains(publicPath)) saved.add(publicPath);
        await box.write('saved_csv_paths', saved);
        
        // Thông báo đường dẫn đã lưu cho người dùng
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File CSV đã được lưu tại: $publicPath'),
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        // Fallback cho iOS / macOS
        final publicPath = filePath;
        final List<String> saved = (box.read<List<dynamic>>('saved_csv_paths')?.cast<String>() ?? []);
        if (!saved.contains(publicPath)) saved.add(publicPath);
        await box.write('saved_csv_paths', saved);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File CSV đã được lưu tại: $publicPath'),
            duration: Duration(seconds: 5),
          ),
        );
      }
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
    List<List<dynamic>> csvData = const CsvToListConverter().convert(csvContent);
    if (csvData.isNotEmpty && csvData[0].length == 1 && csvData[0][0].toString().contains(';')) {
      csvData = const CsvToListConverter(fieldDelimiter: ';').convert(csvContent);
    }

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
        String trimmedHeader = colHeader.trim();
        if (trimmedHeader.isEmpty) continue;

        String deviceName = trimmedHeader;
        String donVi = '';
        final lastOpen = trimmedHeader.lastIndexOf('(');
        final lastClose = trimmedHeader.lastIndexOf(')');
        if (lastOpen != -1 && lastClose != -1 && lastClose > lastOpen) {
          deviceName = trimmedHeader.substring(0, lastOpen).trim();
          donVi = trimmedHeader.substring(lastOpen + 1, lastClose).trim();
        }

        final colIndex = runStartIndex + 1 + deviceCols.indexOf(colHeader); // ✅ SỬA Ở ĐÂY

        // Ép kiểu dữ liệu thành double
        List<double> values = [];
        for (int row = 2; row < csvData.length; row++) {
          if (colIndex >= csvData[row].length) continue;
          final raw = csvData[row][colIndex];
          if (raw != null && raw.toString().trim().isNotEmpty) {
            String valStr = raw.toString().trim().replaceAll(',', '.');
            values.add(double.tryParse(valStr) ?? 0.0);
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
                        // Kiểm tra danh sách file CSV đã lưu và lọc các file còn tồn tại
                        final List<String> rawSavedPaths = (box.read<List<dynamic>>('saved_csv_paths')?.cast<String>() ?? []);
                        final List<String> savedPaths = [];
                        for (String p in rawSavedPaths) {
                          if (await File(p).exists()) savedPaths.add(p);
                        }
                        if (savedPaths.length != rawSavedPaths.length) {
                          await box.write('saved_csv_paths', savedPaths); // cập nhật lại danh sách nếu có file bị xóa
                        }

                        String? chosenPath;
                        if (savedPaths.isNotEmpty) {
                          // Hiển thị dialog chọn file đã lưu
                          chosenPath = await showDialog<String>(
                            context: context,
                            builder: (_) => SimpleDialog(
                              title: const Text('Chọn file CSV đã lưu'),
                              children: savedPaths.map((p) {
                                final parts = p.split('/');
                                final displayName = parts.length >= 2 
                                  ? '${parts[parts.length - 2]}/${parts.last}' 
                                  : parts.last;
                                return SimpleDialogOption(
                                  onPressed: () => Navigator.pop(_, p),
                                  child: Text(displayName),
                                );
                              }).toList(),
                            ),
                          );
                        }
                        // Nếu không có file đã lưu hoặc người dùng hủy, fallback tới FilePicker
                        if (chosenPath == null) {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['csv'],
                          );
                          if (result != null && result.files.single.path != null) {
                            chosenPath = result.files.single.path!;
                          }
                        }

                        if (chosenPath != null) {
                          // Ngắt kết nối các thiết bị BLE hiện tại
                          List<BleDevice> devices = globals.SodoCambienList
                              .map((sodo) => sodo.bluetoothDevice)
                              .toSet()
                              .toList();
                          globals.SodoCambienList.clear();
                          for (var device in devices) {
                            try {
                              await device.disconnect();
                            } catch (e) {
                              print('Error disconnect to device: $e');
                            }
                          }

                          final file = File(chosenPath);
                          final content = await file.readAsString();
                          final parsedHistoryList = await parseCsvToHistoryList(content);
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




