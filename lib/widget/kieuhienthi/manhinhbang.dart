import 'dart:async';

import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';

import '../../Model/cambienhienthi.dart';
import '../../Model/dulieucambien.dart';
import '../../ultis/listcambien.dart' as globals;

class ManhinhBang extends StatelessWidget {
  const ManhinhBang(
      {super.key, required this.stream, required this.streamPhantich, required this.streamCambien, required this.streamControllerDiemcat, required this.streamControllerXoaCambien});

  final Stream<DulieuCB> stream;
  final Stream<int> streamPhantich;
  final Stream<CambienHienthi> streamCambien;
  final StreamController <Map<String, Map<String, dynamic>>> streamControllerDiemcat;
  final StreamController <bool> streamControllerXoaCambien;


  @override
  Widget build(BuildContext context) {
    return Container(
      child: TableData(
        stream: stream,
        parent: this,
        streamPhantich: streamPhantich,
        streamControllerDiemcat: streamControllerDiemcat,
        streamControllerXoaCambien: streamControllerXoaCambien,
      ),
    );
  }
}

class TableData extends StatefulWidget {
  const TableData({super.key,
    required this.parent,
    required this.stream,
    required this.streamPhantich,
    required this.streamControllerDiemcat,
    required this.streamControllerXoaCambien });

  final ManhinhBang parent;
  final Stream<DulieuCB> stream;
  final Stream<int> streamPhantich;
  final StreamController <Map<String, Map<String, dynamic>>> streamControllerDiemcat;
  final StreamController <bool> streamControllerXoaCambien;

  @override
  State<TableData> createState() => _TableDataState();
}

class _TableDataState extends State<TableData> {
  late List<CambienHienthi> listCambienbang;
  late StreamSubscription<CambienHienthi> _subscriptionCambien;
  late StreamSubscription<DulieuCB> _dataSubscription;
  late StreamController<Map<String, Map<String, dynamic>>> streamControllerDiemcat;
  late StreamSubscription<int> _phantichSubscription;
  late int? previousKieuPhantich = 7;
  // Danh sách lưu giá trị cảm biến
  Map<String, List<double>> sensorData = {}; // key là id, value là danh sách giá trị của cảm biến theo thời gian
  List<String> timeTicks = []; // Danh sách lưu mốc thời gian

  void _addCambien(CambienHienthi cambien) {
    String key = cambien.id + '(${cambien.donvi})';

    // Kiểm tra xem cảm biến đã có trong sensorData chưa
    if (!sensorData.containsKey(cambien.id)) {
      setState(() {
        // Nếu chưa có, thêm cảm biến vào sensorData
        sensorData[cambien.id] = []; // Tạo một danh sách rỗng cho cảm biến mới
        if(globals.historyViewMode.value == true){
          if (globals.historySelected != null &&
              globals.historySelected['thietbi'] != null &&
              globals.historySelected['thietbi'].containsKey(cambien.id)) {
            sensorData[cambien.id] = globals.historySelected['thietbi'][cambien.id]['data'];

            int maxLength = sensorData.values.map((list) => list.length).fold(0, (a, b) => a > b ? a : b);
            while (timeTicks.length < maxLength) {
              timeTicks.add((timeTicks.length*globals.tansolaymau/1000).toString());
            }
          } else {
            sensorData[cambien.id] = [];
          }
          // sensorData[cambien.id] = globals.historySelected[cambien.id]['data'] ?? [];
        }else{
          sensorData[cambien.id] = [];
        }
      });
    }else{
      sensorData.remove(cambien.id);
    }
  }

  // Biến lưu trữ dữ liệu click cho từng cột
  Map<String, Map<int, String>> clickedData = {};
  Map<String, Map<String, dynamic>> deviceCoordinates = {};

  // Hàm xử lý khi click vào một ô trong cột
  void _handleCellClick(String device, int index, String value) {
    // Nếu chưa có thiết bị này, khởi tạo Map rỗng
    if (!clickedData.containsKey(device)) {
      clickedData[device] = {};
    }

    // Nếu đã có 2 giá trị, xoá cái cũ nhất
    if (clickedData[device]!.length >= 2) {
      final firstKey = clickedData[device]!.keys.first;
      clickedData[device]!.remove(firstKey);
    }

    // Thêm giá trị mới
    clickedData[device]![index] = value;

    if (clickedData[device]!.length == 2) {
      if (!deviceCoordinates.containsKey(device)) {
        deviceCoordinates[device] = {'coordinates': []};
      }
      deviceCoordinates[device]!['coordinates'] = [];

      clickedData[device]!.forEach((index, value) {
        deviceCoordinates[device]!['coordinates'].add([index.toDouble(), double.parse(value)]);
      });

      streamControllerDiemcat.add(deviceCoordinates);
    }
    setState(() {});
  }

  Widget _buildColumn({
    String? device,
    required List<String> values,
    bool isTimeColumn = false,
  }) {
    // Lấy chiều rộng màn hình
    double screenWidth = MediaQuery.of(context).size.width;

    // Tính toán chiều rộng cột, chia đều cho tất cả cột
    double columnWidth = isTimeColumn ? screenWidth * 0.3 : screenWidth * 0.2; // 15% cho cột thời gian, 20% cho các cột cảm biến


    final deviceIndex = isTimeColumn || device == null
        ? -1
        : sensorData.keys.toList().indexOf(device);
    final color = deviceIndex == -1 ? null : globals.listMamau[deviceIndex];
    return Container(
      width: columnWidth,
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tiêu đề cột
          Container(
            padding: const EdgeInsets.all(8),
            child: AutoSizeText(
              isTimeColumn ? 'Thời gian' : device!,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color ?? Colors.black,
                fontSize: 18, // Font mặc định ban đầu
              ),
              maxLines: 1,
              minFontSize: 12,
              maxFontSize: 14,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Cột dữ liệu
          ...values.asMap().entries.map((entry) {
            int index = entry.key;
            String v = entry.value;

            // Kiểm tra xem ô này có đang được chọn không
            bool isSelected = false;
            if(clickedData[device]?[index] != null){
              isSelected = true;
            }
            return InkWell(
              onTap: () {
                if(previousKieuPhantich != 1){
                  return;
                }
                _handleCellClick(device!, index, v); // Gọi hàm xử lý click
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200),
                  ),

                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: (isSelected && previousKieuPhantich == 1) ? (color ?? Colors.black) : Colors.transparent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: AutoSizeText(
                    // double.tryParse(v)?.toStringAsFixed(3) ?? v,
                    isTimeColumn ? v : double.tryParse(v)?.toStringAsFixed(3) ?? v,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 1,
                    minFontSize: 12,
                    maxFontSize: 14,
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width * 0.02, // Padding ngang (trái và phải)
              vertical: MediaQuery.of(context).size.height * 0.02, // Padding dọc (trên và dưới)
            ),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical, // Chỉ scroll dọc
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = MediaQuery.of(context).size.width < 600;
                        final totalWidth = constraints.maxWidth;
                        final numSensors = sensorData.length;
                        final timeColumnWidth = totalWidth * 0.15;
                        final remainingWidth = totalWidth - timeColumnWidth;

                        // Tính width mỗi cột cảm biến
                        double sensorColumnWidth;
                        if (numSensors == 1) {
                          sensorColumnWidth = remainingWidth;
                        } else if (numSensors == 2) {
                          sensorColumnWidth = remainingWidth / 2;
                        } else {
                          sensorColumnWidth = remainingWidth / numSensors;
                        }

                        sensorColumnWidth = totalWidth /  (numSensors + 1);
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Cột thời gian
                            SizedBox(
                              width: sensorColumnWidth,
                              child: _buildColumn(
                                values: timeTicks,
                                isTimeColumn: true,
                              ),
                            ),

                            // Các cột cảm biến
                            ...sensorData.entries.map((entry) {
                              final id = entry.key;
                              final values = entry.value;

                              return SizedBox(
                                width: sensorColumnWidth,
                                child: _buildColumn(
                                  device: id,
                                  values: List.generate(timeTicks.length, (index) {
                                    return (index < values.length) ? values[index].toString() : '';

                                  }),
                                ),
                              );
                            }).toList(),
                          ],
                        );
                      },
                    ),
                  )

                ),
              ],
            ),
          );

        },
      ),
    );
  }

  @override
  void initState() {
    listCambienbang = [];
    _subscriptionCambien = widget.parent.streamCambien.listen((CambienHienthi cambien) {
      _addCambien(cambien);
    });
    _dataSubscription = widget.stream.listen((DulieuCB dulieu) {
      if (dulieu != null && !dulieu.datLai) {
        final sensorId = dulieu.id;
        final values = dulieu.giaTri.map((e) => e).toList();

        // Nếu cảm biến chưa có, khởi tạo danh sách rỗng
        if (!sensorData.containsKey(sensorId)) {
          return;
          sensorData[sensorId] = [];
        }

        // Thêm từng giá trị vào danh sách của cảm biến
        sensorData[sensorId]!.addAll(values);

        // Cập nhật số lượng timeTicks sao cho bằng chiều dài lớn nhất trong các danh sách
        int maxLength = sensorData.values.map((list) => list.length).fold(0, (a, b) => a > b ? a : b);

        // Đảm bảo timeTicks có đủ độ dài tương ứng
        while (timeTicks.length < maxLength) {
          timeTicks.add((timeTicks.length*globals.tansolaymau/1000).toString());
        }

        setState(() {});
      }else{
        if(globals.historyViewMode.value){
          for (var key in sensorData.keys) {
            sensorData[key] = [];
            if(globals.historyViewMode.value == true){
              if (globals.historySelected != null &&
                  globals.historySelected['thietbi'] != null &&
                  globals.historySelected['thietbi'].containsKey(key)) {
                sensorData[key] = globals.historySelected['thietbi'][key]['data'];
                print(globals.historySelected['thietbi'][key]['data']);

                timeTicks.clear();
                int maxLength = sensorData.values.map((list) => list.length).fold(0, (a, b) => a > b ? a : b);
                while (timeTicks.length < maxLength) {
                  timeTicks.add((timeTicks.length*globals.tansolaymau/1000).toString());
                }
              }
            }
          }
          if (!mounted) return;
          setState(() {
            // cập nhật UI
          });
        }else{
          for (var key in sensorData.keys) {
            sensorData[key] = [];
          }
          timeTicks.clear();
        }
      }
    });
    streamControllerDiemcat = widget.streamControllerDiemcat;
    _phantichSubscription = widget.streamPhantich.listen((value) {
      // ✅ Xử lý mỗi khi có giá trị mới từ streamPhantich
      if(previousKieuPhantich != value){
        clickedData.clear();
        deviceCoordinates.clear();
        streamControllerDiemcat.add(deviceCoordinates);
        setState(() {});
      }
      previousKieuPhantich = value;


      // Thực hiện thêm các hành động nếu cần
    });


  }

  @override
  void dispose() {
    _subscriptionCambien.cancel();
    _dataSubscription.cancel();
    _phantichSubscription.cancel();
    super.dispose();
  }
}
