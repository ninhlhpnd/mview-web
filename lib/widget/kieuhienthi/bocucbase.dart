import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';   // ✅ đổi thư viện
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:testproject/Model/cambien.dart';
import 'package:testproject/Model/cambienhienthi.dart';
import 'package:testproject/Model/dulieucambien.dart';
import 'package:testproject/ultis/listcambien.dart' as globals;
import 'package:testproject/widget/kieuhienthi/manhinhbang.dart';
import 'package:testproject/widget/kieuhienthi/manhinhdongho.dart';
import 'package:testproject/widget/kieuhienthi/manhinhdothi.dart';
import 'package:testproject/widget/kieuhienthi/manhinhso.dart';
import 'package:testproject/widget/popup/popupchonsodo.dart';
import 'package:testproject/widget/popup/popupkieuhienthi.dart';
import 'package:testproject/widget/popup/popupphantich.dart';
import 'package:tuple/tuple.dart';

import '../../Model/sodocambien.dart';

class BocucBase extends StatefulWidget {
  const BocucBase({super.key, required this.stream, required this.wide});

  final Stream<DulieuCB> stream;
  final bool wide;

  @override
  State<BocucBase> createState() => _BocucBaseState();
}

class _BocucBaseState extends State<BocucBase> {
  late int kieuHienthi = 1;
  late int? kieuPhanTich;
  late IconData currentIcon = Icons.show_chart_rounded;
  late StreamController<int> streamKieuphantich = StreamController<int>();
  late StreamController<CambienHienthi> streamAddSensor =
      StreamController<CambienHienthi>();
  late StreamController<Map<String, double>> streamPoint =
      StreamController<Map<String, double>>();
  late StreamController<Map<String, Map<String, dynamic>>> streamDiemcat =
      StreamController<Map<String, Map<String, dynamic>>>();

  // Tạo stream kết hợp
  late Stream<Tuple2<int, Map<String, Map<String, dynamic>>>> combinedStream;
  late StreamController<bool> streamXoaCambien = StreamController<bool>();
  List<dynamic> listDeviceSelected = [];

  @override
  Widget build(BuildContext context) {
    var mediaQuery = MediaQuery.of(context);
    return SizedBox(
      width: mediaQuery.size.width,
      height: mediaQuery.size.height,
      child: Column(
        children: [
          Expanded(
              child: Row(
            children: [
              Expanded(
                flex: widget.wide ? 9 : 8, // 90% chiều rộng
                child: Container(
                  margin: const EdgeInsets.only(top: 5),
                  child: _getBocucWidget(),
                ),
              ),
              Expanded(
                flex: widget.wide ? 1 : 2, // 10% chiều rộng
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  // 👈 Dịch xuống 12px từ trên cùng
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    // 👈 Căn trên
                    children: [
                      AddSensorButton(iconData: Icons.add_box, parent: this),
                      const SizedBox(height: 10),
                      PopupButton(parent: this, iconData: currentIcon),
                      const SizedBox(height: 10),
                      PhantichButton(
                          iconData: Icons.insert_chart, parent: this),
                      const SizedBox(height: 10),
                      // Bọc StreamBuilder trong FractionallySizedBox và Padding
                      StreamBuilder<
                          Tuple2<int, Map<String, Map<String, dynamic>>>>(
                        stream: combinedStream,
                        builder: (context, snapshot) {
                          // Phải kiểm tra hasData TRƯỚC khi dùng snapshot.data!
                          if (!snapshot.hasData ||
                              snapshot.data!.item2.isEmpty) {
                            return const SizedBox();
                          }

                          final Map<String, Map<String, dynamic>> ds =
                              snapshot.data!.item2;
                          final int kieuphantich = snapshot.data!.item1;
                          print('kieu phan tich: $kieuphantich');

                          final isMobile =
                              MediaQuery.of(context).size.width < 600;
                          final itemCount = ds.length;

                          final height = isMobile
                              ? MediaQuery.of(context).size.height * 0.15
                              : itemCount == 2
                                  ? MediaQuery.of(context).size.height * 0.26
                                  : itemCount >= 3
                                      ? MediaQuery.of(context).size.height *
                                          0.35
                                      : MediaQuery.of(context).size.height *
                                          0.16;

                          double screenWidth =
                              MediaQuery.of(context).size.width;
                          double screenHeight =
                              MediaQuery.of(context).size.height;
                          double fontSize = screenWidth * 0.009;
                          double paddingHorizontal = screenWidth * 0.002;
                          double paddingVertical = screenHeight * 0.0105;

                          // Map để tra cứu nhanh tên cảm biến
                          final Map<String, SodoCambien> sodoCambienMap = {
                            for (var cambien in globals.SodoCambienList)
                              cambien.bluetoothDevice.name!: cambien,
                          };
                          switch (kieuphantich) {
                            case 0:
                              return buildPhantich(
                                'Tọa độ',
                                height,
                                fontSize,
                                paddingHorizontal,
                                paddingVertical,
                                ds,
                                sodoCambienMap,
                                (data, _) {
                                  final coordinates = data['coordinates'];
                                  print(
                                      'Coordinates: $coordinates, type: ${coordinates.runtimeType}');

                                  if (coordinates == null ||
                                      coordinates is! List ||
                                      coordinates.length < 2) {
                                    return 'X: —  Y: —';
                                  }

                                  double x, y;

                                  // Dạng phẳng: [x, y]
                                  if (coordinates[0] is num &&
                                      coordinates[1] is num) {
                                    x = (coordinates[0] as num).toDouble() *
                                        (globals.tansolaymau / 1000);
                                    y = (coordinates[1] as num).toDouble();
                                  }
                                  // Dạng lồng: [[x0,y0], [x1,y1], ...] -> lấy cặp đầu để hiển thị
                                  else if (coordinates[0] is List &&
                                      (coordinates[0] as List).length >= 2) {
                                    final firstPair = coordinates[0] as List;
                                    if (firstPair[0] is! num ||
                                        firstPair[1] is! num) {
                                      return 'X: —  Y: —';
                                    }
                                    x = (firstPair[0] as num).toDouble() *
                                        (globals.tansolaymau / 1000);
                                    y = (firstPair[1] as num).toDouble();
                                  } else {
                                    return 'X: —  Y: —';
                                  }

                                  return 'X: ${x.toStringAsFixed(2)}  Y: ${y.toStringAsFixed(3)}';
                                },
                              );
                            case 1:
                              return buildPhantich(
                                'Chênh lệch',
                                height,
                                fontSize,
                                paddingHorizontal,
                                paddingVertical,
                                ds,
                                sodoCambienMap,
                                (data, _) {
                                  final coordinates = data['coordinates'];
                                  print(
                                      'Coordinates: $coordinates, type: ${coordinates.runtimeType}');

                                  if (coordinates == null ||
                                      coordinates is! List ||
                                      coordinates.length < 2) {
                                    return 'ΔX: —  ΔY: —';
                                  }

                                  final band0 = coordinates[0];
                                  final band1 = coordinates[1];

                                  if (band0 is! List ||
                                      band1 is! List ||
                                      band0.length < 2 ||
                                      band1.length < 2) {
                                    return 'ΔX: —  ΔY: —';
                                  }
                                  if (band0[0] is! num ||
                                      band0[1] is! num ||
                                      band1[0] is! num ||
                                      band1[1] is! num) {
                                    return 'ΔX: —  ΔY: —';
                                  }

                                  final dxSamples =
                                      ((band1[0] as num) - (band0[0] as num))
                                          .toDouble();
                                  final dy =
                                      ((band1[1] as num) - (band0[1] as num))
                                          .toDouble();

                                  final deltaX =
                                      (dxSamples * (globals.tansolaymau / 1000))
                                          .abs();
                                  final deltaY = dy.abs();

                                  return 'ΔX: ${deltaX.toStringAsFixed(2)}  ΔY: ${deltaY.toStringAsFixed(2)}';
                                },
                              );

                            case 2:
                              return buildPhantich(
                                'Độ dốc',
                                height,
                                fontSize,
                                paddingHorizontal,
                                paddingVertical,
                                ds,
                                sodoCambienMap,
                                (data, _) {
                                  final coordinates = data['coordinates'];
                                  final fit = data['fit'];
                                  print(
                                      'Coordinates: $coordinates, type: ${coordinates.runtimeType}');
                                  print('fit: $fit, type: ${fit.runtimeType}');

                                  // --- Nếu là kieuphantich = 2 ---
                                  if (fit != null && fit is Map) {
                                    final slope = fit['slope'] ?? double.nan;
                                    final intercept =
                                        fit['intercept'] ?? double.nan;
                                    final r2 = fit['r2'] ?? double.nan;

                                    if (slope is num &&
                                        intercept is num &&
                                        r2 is num) {
                                      return 'm: ${slope.toStringAsFixed(2)}  '
                                          'b: ${intercept.toStringAsFixed(2)}';
                                    } else {
                                      return 'm: —  b: —';
                                    }
                                  } else {
                                    return 'm: —  b: —';
                                  }
                                },
                              );
                            case 3:
                              return buildPhantich(
                                'Trung bình',
                                height,
                                fontSize,
                                paddingHorizontal,
                                paddingVertical,
                                ds,
                                sodoCambienMap,
                                (data, _) {
                                  final coordinates = data['coordinates'];
                                  print(
                                      'Coordinates: $coordinates, type: ${coordinates.runtimeType}');

                                  if (coordinates == null ||
                                      coordinates is! List ||
                                      coordinates.length < 3) {
                                    return 'min: —  max: —  avg: —';
                                  }

                                  final min = coordinates[0];
                                  final max = coordinates[1];
                                  final avg = coordinates[2];

                                  if (min is! num ||
                                      max is! num ||
                                      avg is! num)
                                       {
                                    return 'min: —  max: —  avg: —';
                                  }

                                  return 'min: ${min.toStringAsFixed(2)}  max: ${max.toStringAsFixed(2)}  avg: ${avg.toStringAsFixed(2)}';
                                },
                              );
                            case 4:
                              return buildPhantich(
                                'RMS',
                                height,
                                fontSize,
                                paddingHorizontal,
                                paddingVertical,
                                ds,
                                sodoCambienMap,
                                    (data, _) {
                                  final coordinates = data['coordinates'];
                                  print('Coordinates: $coordinates, type: ${coordinates.runtimeType}');

                                  if (coordinates == null ||
                                      coordinates is! List ||
                                      coordinates.length < 1) {
                                    return 'rms —';
                                  }
                                  final rms = coordinates[0];
                                  if (rms is! num)
                                  {
                                    return 'rms: —';
                                  }

                                  return 'rms: ${rms.toStringAsFixed(2)}';
                                },
                              );
                            default:
                              return const SizedBox();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )),
        ],
      ),
    );
  }

  Widget buildPhantich(
    String title,
    double height,
    double fontSize,
    double paddingHorizontal,
    double paddingVertical,
    Map<String, Map<String, dynamic>> ds,
    Map<String, SodoCambien> sodoCambienMap,
    String Function(Map<String, dynamic>, double) valueBuilder,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: FractionallySizedBox(
        widthFactor: 0.75,
        alignment: Alignment.centerRight,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            height: height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        ...ds.entries.toList().asMap().entries.map((mapEntry) {
                          final index = mapEntry.key;
                          final seriesId = mapEntry.value.key;
                          final data = mapEntry.value.value;
                          final coordinates = data['coordinates'];

                          if (coordinates == null || coordinates.length < 1) {
                            return const SizedBox();
                          }

                          final color = globals.listMamau[index];
                          final sodoCambien = sodoCambienMap[seriesId];
                          final tenCambien =
                              sodoCambien?.tenCambien ?? seriesId;

                          return Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: paddingHorizontal * 0.5,
                              vertical: paddingVertical * 0.5,
                            ),
                            child: Container(
                              padding: EdgeInsets.all(paddingVertical),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: color, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 5,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tenCambien,
                                    style: TextStyle(fontSize: fontSize * 0.9),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    valueBuilder(data, fontSize),
                                    style: TextStyle(
                                      fontSize: fontSize * 0.9,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void handleKieuphantich(int kieuphantich) {
    streamKieuphantich.add(kieuphantich);
    // print(kieuphantich);
  }

  void handleKieuhienthi(int kieuhienthi) {
    setState(() {
      if (kieuhienthi != kieuHienthi) {
        listDeviceSelected.clear();
      }
      kieuHienthi = kieuhienthi;
      switch (kieuHienthi) {
        case 1:
          currentIcon = Icons.show_chart_rounded;
          break;
        case 2:
          currentIcon = Icons.onetwothree_outlined;
          break;
        case 3:
          currentIcon = Icons.table_rows_outlined;
          break;
        case 4:
          currentIcon = Icons.speed_outlined;
          break;
        default:
          currentIcon = Icons.question_mark_outlined;
      }
    });
  }

  Widget _getBocucWidget() {
    switch (kieuHienthi) {
      case 1:
        return ManhinhDothi(
          stream: widget.stream,
          streamPhantich: streamKieuphantich.stream,
          streamCambien: streamAddSensor.stream,
          streamControllerDiemcat: streamDiemcat,
          streamControllerXoaCambien: streamXoaCambien,
        );
      case 2:
        return ManhinhSo(
          stream: widget.stream,
          streamAddSensor: streamAddSensor.stream,
        );
      case 3:
        return ManhinhBang(
          stream: widget.stream,
          streamPhantich: streamKieuphantich.stream,
          streamCambien: streamAddSensor.stream,
          streamControllerDiemcat: streamDiemcat,
          streamControllerXoaCambien: streamXoaCambien,
        );
      case 4:
        return ManhinhDongho(
          streamDulieu: widget.stream,
          streamCambien: streamAddSensor.stream,
        );
      default:
        return Container(color: Colors.white);
    }
  }

  @override
  void initState() {
    streamKieuphantich = StreamController<int>.broadcast();
    streamAddSensor = StreamController<CambienHienthi>.broadcast();
    streamDiemcat =
        StreamController<Map<String, Map<String, dynamic>>>.broadcast();
    combinedStream = Rx.combineLatest2(
      streamKieuphantich.stream,
      streamDiemcat.stream,
      (int kieuphantich, Map<String, Map<String, dynamic>> diemcat) =>
          Tuple2(kieuphantich, diemcat),
    );
    // globals.clearData.addListener(() async {
    //   if(globals.clearData.value == true && mounted){
    //     setState(() {
    //       listDeviceSelected.clear();
    //     });
    //   }
    // });

    // Lắng nghe streamAddSensor
    streamAddSensor.stream.listen((CambienHienthi sensor) {
      if (kieuHienthi == 1 || kieuHienthi == 3) {
        setState(() {
          final existing = listDeviceSelected.indexWhere(
              (item) => item.id == sensor.id && item.name == sensor.name);
          if (existing == -1) {
            listDeviceSelected.add(sensor);
          } else {
            listDeviceSelected.removeAt(existing);
          }
        });
      } else if (kieuHienthi == 2 || kieuHienthi == 4) {
        setState(() {
          final existing = listDeviceSelected.indexWhere(
              (item) => item.id == sensor.id && item.name == sensor.name);
          if (existing != -1) {
            // Nếu đã có rồi thì xoá đi
            listDeviceSelected.removeAt(existing);
          } else {
            // Nếu chưa có thì giữ lại 1 item mới
            listDeviceSelected
              ..clear()
              ..add(sensor);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    // TODO: implement dispose
    streamKieuphantich.close();
    streamAddSensor.close();
    streamDiemcat.close();
    super.dispose();
  }
}

class _IconButtonFunctionBocuc extends StatefulWidget {
  const _IconButtonFunctionBocuc(
      {required this.function, required this.iconData, required this.parent});

  final IconData iconData;
  final _BocucBaseState parent;
  final Function() function;

  @override
  State<_IconButtonFunctionBocuc> createState() =>
      _IconButtonFunctionBocucState();
}

class _IconButtonFunctionBocucState extends State<_IconButtonFunctionBocuc> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = screenWidth * 0.014; // Tùy chỉnh tỉ lệ nếu cần
    return InkWell(
      onTap: () {
        widget.function();
      },
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Color(globals.MyColors.mamau['xam']!),
          borderRadius: BorderRadius.circular(5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 5,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            widget.iconData,
            size: iconSize,
          ),
        ),
      ),
    );
  }
}

class PopupButton extends StatefulWidget {
  const PopupButton({super.key, required this.parent, required this.iconData});

  final _BocucBaseState parent;
  final IconData iconData;

  @override
  _PopupButtonState createState() => _PopupButtonState();
}

class _PopupButtonState extends State<PopupButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {}

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
    var size = renderBox.size;

    return OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: _hidePopup,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ), // Bo góc cho toàn bộ khối
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 250,
                  maxHeight: 300,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      spreadRadius: 0,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Popupkieuhienthi(
                  onClose: _hidePopup,
                  onClickKieuhienthi: widget.parent.handleKieuhienthi,
                ),
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
      child: Padding(
        padding: const EdgeInsets.only(right: 4), // padding phải
        child: FractionallySizedBox(
          widthFactor: 0.75, // chiếm 65% chiều rộng của cha
          alignment: Alignment.centerRight, // căn về bên phải
          child: _IconButtonFunctionBocuc(
            function: _showPopup,
            iconData: widget.iconData,
            parent: widget.parent,
          ),
        ),
      ),
    );
  }
}

class AddSensorButton extends StatefulWidget {
  const AddSensorButton(
      {super.key, required this.parent, required this.iconData});

  final _BocucBaseState parent;
  final IconData iconData;

  @override
  State<AddSensorButton> createState() => _AddSensorButtonState();
}

class _AddSensorButtonState extends State<AddSensorButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

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

  void _onChoncambien(CambienHienthi a) {
    widget.parent.streamAddSensor.add(a);
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    return OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: _hidePopup,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.3,
                  // maxHeight: MediaQuery.of(context).size.height * 0.27,
                ),
                padding: EdgeInsets.zero, // Loại bỏ padding ngoài
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 10,
                      spreadRadius: 0,
                      color: Colors.black26,
                      offset: Offset(0, 4), // đổ bóng xuống
                    ),
                  ],
                ),
                child: PopupChonsodo(
                  onClose: _hidePopup,
                  listDeviceSelected: widget.parent.listDeviceSelected,
                  sodocambienList: globals.SodoCambienList,
                  onCambienSelected: _onChoncambien,
                ),
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
      child: Padding(
        padding: const EdgeInsets.only(right: 4), // padding bên phải
        child: FractionallySizedBox(
          widthFactor: 0.75, // rộng 65% so với cha
          alignment: Alignment.centerRight,
          child: _IconButtonFunctionBocuc(
            function: _showPopup,
            iconData: widget.iconData,
            parent: widget.parent,
          ),
        ),
      ),
    );
  }
}

class PhantichButton extends StatefulWidget {
  const PhantichButton(
      {super.key, required this.parent, required this.iconData});

  final _BocucBaseState parent;
  final IconData iconData;

  @override
  State<PhantichButton> createState() => _PhantichButtonState();
}

class _PhantichButtonState extends State<PhantichButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  int? selectedPhantichIndex; // Lưu trạng thái của PopupPhantich

  void _showPopup() {
    if (!globals.requestOff.value) {
      globals.requestOff.value = true;
      setState(() {});
    }
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
    var size = renderBox.size;

    return OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: _hidePopup,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 250, // Giới hạn chiều ngang
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                // boxShadow: [
                //   BoxShadow(
                //     color: Colors.black26,
                //     blurRadius: 5,
                //     offset: Offset(0, 5),
                //   ),
                // ],
              ),
              child: PopupPhantich(
                initialState: selectedPhantichIndex,
                onClose: _hidePopup,
                onPhantichSelected: (index) {
                  setState(() {
                    selectedPhantichIndex = index;
                  });
                  widget.parent.handleKieuphantich(index);
                },
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
      child: Padding(
        padding: const EdgeInsets.only(right: 4), // padding bên phải
        child: FractionallySizedBox(
          widthFactor: 0.75, // chiếm 65% chiều rộng của cha
          alignment: Alignment.centerRight,
          child: _IconButtonFunctionBocuc(
            function: _showPopup,
            iconData: widget.iconData,
            parent: widget.parent,
          ),
        ),
      ),
    );
  }
}
