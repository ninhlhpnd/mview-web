import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../Model/cambienhienthi.dart';
import '../../Model/dulieucambien.dart';
import '../../ultis/listcambien.dart' as globals;
import '../popup/popupchonsodo.dart';

class ManhinhDocTheoDiem extends StatefulWidget {
  const ManhinhDocTheoDiem({super.key, required this.stream});

  final Stream<DulieuCB> stream;

  @override
  State<ManhinhDocTheoDiem> createState() => _ManhinhDocTheoDiemState();
}

class _ManhinhDocTheoDiemState extends State<ManhinhDocTheoDiem> {
  final GlobalKey<_ChartWidgetState> chartKey = GlobalKey<_ChartWidgetState>();

  CambienHienthi? cambienX;
  CambienHienthi? cambienY;

  final List<Map<String, double>> dataPoints = [];
  final List<TextEditingController> xControllers = [];
  final List<TextEditingController> yControllers = [];
  final List<int?> chartUids = []; // keep uid for confirmed point in each row
  final ScrollController scrollController = ScrollController();
  late StreamSubscription<DulieuCB> _subscription;

  double? latestX;
  double? latestY;
  int currentRow = 0;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();

    // 5 dòng trống ban đầu
    for (int i = 0; i < 5; i++) {
      dataPoints.add({'x': 0, 'y': 0});
      xControllers.add(TextEditingController());
      yControllers.add(TextEditingController());
    }

    // lắng nghe dữ liệu stream
    _subscription = widget.stream.listen((dulieu) {
      // Nếu chưa chọn cảm biến X,Y thì bỏ qua
      if (cambienX == null || cambienY == null) return;

      // Nếu dữ liệu trùng với cảm biến X hoặc Y thì cập nhật
      if (dulieu.tenCambien == cambienX!.name) {
        latestX = dulieu.giaTri.isNotEmpty ? dulieu.giaTri[0] : null;
      }
      if (dulieu.tenCambien == cambienY!.name) {
        latestY = dulieu.giaTri.isNotEmpty ? dulieu.giaTri[0] : null;
      }

      // Cập nhật dòng hiện tại hiển thị tạm thời
      if (currentRow < dataPoints.length) {
        setState(() {
          dataPoints[currentRow]['x'] = latestX ?? 0;
          dataPoints[currentRow]['y'] = latestY ?? 0;
          xControllers[currentRow].text =
              (latestX ?? 0).toStringAsFixed(2);
          yControllers[currentRow].text =
              (latestY ?? 0).toStringAsFixed(2);
        });
      }
    });
  }

  void confirmCurrentPoint() {
    // Nếu chưa có dữ liệu hợp lệ, bỏ qua
    if (latestX == null || latestY == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Chưa có dữ liệu để thêm điểm")),
      );
      return;
    }

    // Thêm vào biểu đồ
    chartKey.currentState?.addPoint(latestX!, latestY!);

    // Sang dòng tiếp theo
    setState(() {
      dataPoints[currentRow]['x'] = latestX!;
      dataPoints[currentRow]['y'] = latestY!;
      xControllers[currentRow].text = latestX!.toStringAsFixed(2);
      yControllers[currentRow].text = latestY!.toStringAsFixed(2);

      currentRow++;
      latestX = null;
      latestY = null;

      // Nếu hết dòng, thêm dòng mới
      if (currentRow >= dataPoints.length) {
        dataPoints.add({'x': 0, 'y': 0});
        xControllers.add(TextEditingController());
        yControllers.add(TextEditingController());
      }

      // Cuộn xuống cuối
      Future.delayed(const Duration(milliseconds: 200), () {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  void deletePointRow(int row) {
    if (row < 0 || row >= dataPoints.length) return;

    chartKey.currentState?.removePointAt(row); // Xóa điểm trên chart
    setState(() {
      // Xóa dữ liệu dòng tương ứng trong bảng
      dataPoints.removeAt(row);
      xControllers.removeAt(row);
      yControllers.removeAt(row);

      // Nếu xóa xong không còn dòng nào → tạo lại 5 dòng trắng
      if (dataPoints.isEmpty) {
        for (int i = 0; i < 5; i++) {
          dataPoints.add({'x': 0, 'y': 0});
          xControllers.add(TextEditingController());
          yControllers.add(TextEditingController());
        }
        currentRow = 0;
        return;
      }

      // Cập nhật currentRow hợp lý
      if (row < currentRow) {
        currentRow = currentRow - 1;
      } else if (currentRow >= dataPoints.length) {
        currentRow = dataPoints.length - 1;
      }

      // Đảm bảo không < 0
      if (currentRow < 0) currentRow = 0;
    });
  }


  void deleteAllPoints() {
    chartKey.currentState?.removeAllPoints();
    setState(() {
      dataPoints.clear();
      xControllers.clear();
      yControllers.clear();
      for (int i = 0; i < 5; i++) {
        dataPoints.add({'x': 0, 'y': 0});
        xControllers.add(TextEditingController());
        yControllers.add(TextEditingController());
      }
      currentRow = 0;
    });
  }
  @override
  void dispose() {
    for (var c in xControllers) {
      c.dispose();
    }
    for (var c in yControllers) {
      c.dispose();
    }
    scrollController.dispose();
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 900;
        return Row(
          children: [
            _buildBangDuLieu(isMobile, constraints.maxWidth),
            _buildBieuDo(isMobile),
          ],
        );
      },
    );
  }

  Widget _buildBangDuLieu(bool isMobile, double maxWidth) {
    Widget bangDuLieu = Padding(
      padding: EdgeInsets.all(isMobile ? 8 : 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 8 : 16),
          child: Column(
            children: [
                    // Nút chọn cảm biến X/Y
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.ssid_chart, size: 18),
                            label: Text(
                              cambienX?.name ?? "Chọn cảm biến trục X",
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () =>
                                _showPopupChonSodo(context, isX: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade50,
                              foregroundColor: Colors.blue.shade900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon:
                            const Icon(Icons.analytics_outlined, size: 18),
                            label: Text(
                              cambienY?.name ?? "Chọn cảm biến trục Y",
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () =>
                                _showPopupChonSodo(context, isX: false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade50,
                              foregroundColor: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Bảng dữ liệu
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey.shade50,
                        ),
                        child: Column(
                          children: [
                            Container(
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12)),
                              ),
                              child: const Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceAround,
                                children: [
                                  Text("Trục X",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Text("Trục Y",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                controller: scrollController,
                                itemCount: dataPoints.length,
                                itemBuilder: (context, index) {
                                  return Container(
                                    color: index == currentRow
                                        ? Colors.blue.shade50
                                        : (index % 2 == 0
                                        ? Colors.white
                                        : Colors.grey.shade100),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    child: Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: xControllers[index],
                                            decoration: InputDecoration(
                                              border: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                    color:
                                                    Colors.grey.shade300),
                                              ),
                                              isDense: true,
                                              contentPadding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 4,
                                                  horizontal: 6),
                                            ),
                                            style:
                                            const TextStyle(fontSize: 13),
                                            keyboardType:
                                            TextInputType.numberWithOptions(
                                                decimal: true),
                                            onChanged: (val) {
                                              final x =
                                                  double.tryParse(val) ?? 0;
                                              // lấy y từ controller hiện tại
                                              final y = double.tryParse(
                                                  yControllers[index]
                                                      .text) ??
                                                  0;
                                              // cập nhật vào cả dataPoints local & chart
                                              setState(() {
                                                dataPoints[index]['x'] = x;
                                                dataPoints[index]['y'] = y;
                                              });
                                              chartKey.currentState
                                                  ?.updatePoint(index, x, y);
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: TextField(
                                            controller: yControllers[index],
                                            decoration: InputDecoration(
                                              border: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                    color:
                                                    Colors.grey.shade300),
                                              ),
                                              isDense: true,
                                              contentPadding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 4,
                                                  horizontal: 6),
                                            ),
                                            style:
                                            const TextStyle(fontSize: 13),
                                            keyboardType:
                                            TextInputType.numberWithOptions(
                                                decimal: true),
                                            onChanged: (val) {
                                              final y =
                                                  double.tryParse(val) ?? 0;
                                              final x = double.tryParse(
                                                  xControllers[index]
                                                      .text) ??
                                                  0;
                                              setState(() {
                                                dataPoints[index]['x'] = x;
                                                dataPoints[index]['y'] = y;
                                              });
                                              chartKey.currentState
                                                  ?.updatePoint(index, x, y);
                                            },
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                          onPressed: () => deletePointRow(index),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: confirmCurrentPoint,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text("Thêm điểm", overflow: TextOverflow.ellipsis, maxLines: 1),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: deleteAllPoints,
                            icon: const Icon(Icons.clear_all, size: 16),
                            label: const Text("Xóa tất cả", overflow: TextOverflow.ellipsis, maxLines: 1),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade400,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ),
                      ],
                    ),

                  ],
                ),
              ),
            ),
          );


    if (isMobile) {
      double panelWidth = maxWidth * 0.45;
      if (panelWidth < 250) panelWidth = 250;
      return SizedBox(
        width: panelWidth,
        child: bangDuLieu,
      );
    } else {
      return Expanded(
        flex: 1,
        child: bangDuLieu,
      );
    }
  }

  Widget _buildBieuDo(bool isMobile) {
    return Expanded(
      flex: isMobile ? 3 : 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 8 : 16),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 8 : 12),
            child: _ChartWidget(key: chartKey),
          ),
        ),
      ),
    );
  }

  void _showPopupChonSodo(BuildContext context, {required bool isX}) {
    // Nếu đã mở, đóng trước
    _overlayEntry?.remove();
    _overlayEntry = null;

    // Tạo overlay
    _overlayEntry = OverlayEntry(
      builder: (context) {
        bool isMobile = MediaQuery.of(context).size.width < 900;
        return GestureDetector(
          onTap: _hidePopup, // click ngoài để tắt
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: GestureDetector(
                onTap: () {}, // chặn tap trong popup
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isMobile
                        ? MediaQuery.of(context).size.width * 0.6
                        : MediaQuery.of(context).size.width * 0.3,
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                padding: EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 10,
                      spreadRadius: 0,
                      color: Colors.black26,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: PopupChonsodo(
                  sodocambienList: globals.SodoCambienList,
                  listDeviceSelected: [],
                  onClose: _hidePopup,
                  onCambienSelected: (CambienHienthi cambien) {
                    _hidePopup(); // đóng popup trước
                    // gọi cập nhật an toàn
                    if (!mounted) return;
                    setState(() {
                      if (isX) {
                        cambienX = cambien;
                      } else {
                        cambienY = cambien;
                      }
                      currentRow = 0;
                      // cập nhật tiêu đề trục bên chart
                    });

                    final xTitle = cambienX == null
                        ? "Trục X"
                        : "${cambienX!.name} (${cambienX!.donvi ?? ''})";
                    final yTitle = cambienY == null
                        ? "Trục Y"
                        : "${cambienY!.name} (${cambienY!.donvi ?? ''})";
                    chartKey.currentState?.setAxisTitles(x: xTitle, y: yTitle);
                    chartKey.currentState?.clear();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      },
    );

    // Hiển thị overlay
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hidePopup() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

//
// ==================== WIDGET BIỂU ĐỒ ====================
//
class _ChartWidget extends StatefulWidget {
  const _ChartWidget({super.key});

  @override
  State<_ChartWidget> createState() => _ChartWidgetState();
}

class _ChartWidgetState extends State<_ChartWidget> {
  final List<Map<String, double>> dataPoints = []; // lưu theo thứ tự thêm
  String _xTitle = "Trục X";
  String _yTitle = "Trục Y";

  Rect? _selectionRect;
  Offset? _dragStart;
  Offset? _dragEnd;

  bool _isZoomMode = true;
  bool _isAnalysisOn = false;
  String _analysisMode = "none";
  String _analysisText = "";

  Offset? _tooltipPosition;
  String? _tooltipText;

  List<Map<String, double>> _bestFitLine = [];
  Set<int> _highlightedIndexes = {}; // index theo thứ tự dataPoints

  final GlobalKey _chartKey = GlobalKey();

  // Helper: build render list sorted by x but keep original index
  List<Map<String, dynamic>> get _renderPoints {
    final list = List<Map<String, dynamic>>.generate(
      dataPoints.length,
          (i) => {'x': dataPoints[i]['x']!, 'y': dataPoints[i]['y']!, 'i': i},
    );
    list.sort((a, b) => (a['x'] as double).compareTo(b['x'] as double));
    return list;
  }

  // ========= QUẢN LÝ DỮ LIỆU =========
  void addPoint(double x, double y) {
    setState(() {
      dataPoints.add({'x': x, 'y': y});
    });
  }
// Xóa điểm theo index
  void removePointAt(int index) {
    if (index < 0 || index >= dataPoints.length) return;
    setState(() {
      dataPoints.removeAt(index);
      // ép redraw
      final refreshed = List<Map<String, double>>.from(dataPoints);
      dataPoints
        ..clear()
        ..addAll(refreshed);
      // clear selection và phân tích
      _selectionRect = null;
      _highlightedIndexes.clear();
      _analysisText = "";
      _bestFitLine.clear();
    });
  }

// Xóa tất cả điểm
  void removeAllPoints() {
    setState(() {
      dataPoints.clear();
      _selectionRect = null;
      _highlightedIndexes.clear();
      _analysisText = "";
      _bestFitLine.clear();
      _tooltipText = null;
    });
  }

  void updatePoint(int index, double x, double y) {
    if (index < 0) return;

    setState(() {
      // mở rộng nếu cần
      while (dataPoints.length <= index) {
        dataPoints.add({'x': 0.0, 'y': 0.0});
      }

      // cập nhật điểm tại index
      dataPoints[index]['x'] = x;
      dataPoints[index]['y'] = y;

      // Force Syncfusion rebuild path: tạo copy -> clear -> addAll
      final refreshed = List<Map<String, double>>.from(dataPoints);
      dataPoints
        ..clear()
        ..addAll(refreshed);

      // nếu đang có vùng chọn thì cập nhật lại vùng / phân tích
      if (_selectionRect != null) {
        _selectPointsInRect(live: false);
        if (_isAnalysisOn) _performAnalysis();
      } else if (_isAnalysisOn && _highlightedIndexes.isNotEmpty) {
        _performAnalysis();
      }
    });
  }

  void clear() {
    setState(() {
      dataPoints.clear();
      _selectionRect = null;
      _analysisText = "";
      _bestFitLine.clear();
      _tooltipText = null;
      _highlightedIndexes.clear();
    });
  }

  void setAxisTitles({required String x, required String y}) {
    setState(() {
      _xTitle = x;
      _yTitle = y;
    });
  }

  // ========= BUILD UI =========
  @override
  Widget build(BuildContext context) {
    final renderPoints = _renderPoints;

    return Column(
      children: [
        // toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => setState(() => _isZoomMode = true),
                  icon: Icon(Icons.zoom_in,
                      color: _isZoomMode ? Colors.white : Colors.blue),
                  label: const Text("Zoom"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor:
                      _isZoomMode ? Colors.blue : Colors.blue.shade50),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _isZoomMode = false),
                  icon: Icon(Icons.crop_square,
                      color: !_isZoomMode ? Colors.white : Colors.green),
                  label: const Text("Chọn vùng"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor:
                      !_isZoomMode ? Colors.green : Colors.green.shade50),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isAnalysisOn = !_isAnalysisOn;
                      if (!_isAnalysisOn) {
                        _analysisMode = "none";
                        _analysisText = "";
                        _bestFitLine.clear();
                      } else if (_analysisMode == "none") {
                        _analysisMode = "minmax";
                      }
                      _performAnalysis();
                    });
                  },
                  icon: Icon(Icons.analytics_outlined,
                      color: _isAnalysisOn ? Colors.white : Colors.orange),
                  label: Text(_isAnalysisOn ? "Tắt phân tích" : "Phân tích"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor:
                      _isAnalysisOn ? Colors.orange : Colors.orange.shade50),
                ),
                const SizedBox(width: 8),
                if (_isAnalysisOn)
                  DropdownButton<String>(
                    value: _analysisMode == "none" ? "minmax" : _analysisMode,
                    onChanged: (val) {
                      setState(() => _analysisMode = val ?? "minmax");
                      _performAnalysis();
                    },
                    items: const [
                      DropdownMenuItem(value: "coordinate", child: Text("Tọa độ")),
                      DropdownMenuItem(value: "delta", child: Text("Chênh lệch")),
                      DropdownMenuItem(value: "minmax", child: Text("Min/Max")),
                      DropdownMenuItem(value: "avg", child: Text("Trung bình")),
                      DropdownMenuItem(value: "slope", child: Text("Đường fit")),
                    ],
                  ),
                const SizedBox(width: 8),
                // nút xóa selection
                if (_selectionRect != null)
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectionRect = null;
                        _highlightedIndexes.clear();
                        _analysisText = "";
                        _bestFitLine.clear();
                      });
                    },
                    child: const Text("Xóa vùng"),
                  ),
              ],
            ),
          ),
        ),

        // chart area
        Expanded(
          child: Stack(
            key: _chartKey,
            children: [
              // SfCartesianChart
              Positioned.fill(
                child: SfCartesianChart(
                  primaryXAxis: NumericAxis(
                    title: AxisTitle(text: _xTitle),
                    majorGridLines:
                    const MajorGridLines(width: 0.4, dashArray: [5, 4]),
                  ),
                  primaryYAxis: NumericAxis(
                    title: AxisTitle(text: _yTitle),
                    majorGridLines:
                    const MajorGridLines(width: 0.4, dashArray: [5, 4]),
                  ),
                  zoomPanBehavior: ZoomPanBehavior(
                    enablePinching: _isZoomMode,
                    enablePanning: _isZoomMode,
                  ),
                  series: <CartesianSeries>[
                    LineSeries<Map<String, dynamic>, double>(
                      animationDuration: 0,
                      dataSource: renderPoints,
                      xValueMapper: (p, _) => p['x'] as double,
                      yValueMapper: (p, _) => p['y'] as double,
                      markerSettings: const MarkerSettings(isVisible: true, width: 7, height: 7),
                      pointColorMapper: (p, index) {
                        final orig = p['i'] as int;
                        return _highlightedIndexes.contains(orig) ? Colors.red : Colors.blue;
                      },
                      color: Colors.blue,
                      width: 2,
                      onPointTap: (ChartPointDetails details) {
                        final sortedIdx = details.pointIndex ?? -1;
                        if (sortedIdx < 0 || sortedIdx >= renderPoints.length) return;

                        final origIdx = renderPoints[sortedIdx]['i'] as int;

                        Offset pos = const Offset(12, 12);
                        try {
                          if (details.dataPoints != null &&
                              details.dataPoints!.length > sortedIdx &&
                              details.dataPoints![sortedIdx].region != null) {
                            final regionCenter = details.dataPoints![sortedIdx].region!.center;
                            final box = _chartKey.currentContext?.findRenderObject() as RenderBox?;
                            if (box != null) {
                              try {
                                pos = box.globalToLocal(regionCenter);
                              } catch (_) {
                                pos = regionCenter;
                              }
                            } else {
                              pos = regionCenter;
                            }
                          }
                        } catch (_) {
                          final box = _chartKey.currentContext?.findRenderObject() as RenderBox?;
                          if (box != null && dataPoints.isNotEmpty) {
                            final size = box.size;
                            const leftPadding = 60.0;
                            const rightPadding = 20.0;
                            const topPadding = 20.0;
                            const bottomPadding = 40.0;
                            final plotRect = Rect.fromLTWH(
                              leftPadding,
                              topPadding,
                              size.width - leftPadding - rightPadding,
                              size.height - topPadding - bottomPadding,
                            );
                            final xMin = dataPoints.map((e) => e['x']!).reduce(min);
                            final xMax = dataPoints.map((e) => e['x']!).reduce(max);
                            final yMin = dataPoints.map((e) => e['y']!).reduce(min);
                            final yMax = dataPoints.map((e) => e['y']!).reduce(max);
                            final x = dataPoints[origIdx]['x']!;
                            final y = dataPoints[origIdx]['y']!;
                            final px = plotRect.left + ((x - xMin) / (xMax - xMin + 1e-9)) * plotRect.width;
                            final py = plotRect.top + (1 - ((y - yMin) / (yMax - yMin + 1e-9))) * plotRect.height;
                            pos = Offset(px, py);
                          }
                        }

                        setState(() {
                          _tooltipText = "X = ${dataPoints[origIdx]['x']!.toStringAsFixed(3)}\nY = ${dataPoints[origIdx]['y']!.toStringAsFixed(3)}";
                          _tooltipPosition = pos;
                        });
                      },
                    ),
                    // best-fit line
                    if (_bestFitLine.isNotEmpty)
                      LineSeries<Map<String, double>, double>(
                        dataSource: _bestFitLine,
                        xValueMapper: (p, _) => p['x']!,
                        yValueMapper: (p, _) => p['y']!,
                        color: Colors.orange,
                        dashArray: const [6, 4],
                        width: 2,
                      ),
                  ],
                ),
              ),

              // selection rectangle live draw + gesture handling (only when not zoom mode)
              if (!_isZoomMode)
                Positioned.fill(
                  child: GestureDetector(
                    onPanStart: (details) {
                      setState(() {
                        _dragStart = details.localPosition;
                        _dragEnd = details.localPosition;
                        _selectionRect = Rect.fromPoints(_dragStart!, _dragEnd!);
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        _dragEnd = details.localPosition;
                        _selectionRect = Rect.fromPoints(_dragStart!, _dragEnd!);
                        // live highlight while dragging
                        _selectPointsInRect(live: true);
                      });
                    },
                    onPanEnd: (details) {
                      // finalize selection and analysis
                      _selectPointsInRect(live: false);
                      if (_isAnalysisOn) _performAnalysis();
                    },
                  ),
                ),

              // selection rect overlay + close button + analysis text
              if (_selectionRect != null)
                Positioned.fromRect(
                  rect: _selectionRect!,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      border: Border.all(color: Colors.green, width: 1),
                    ),
                    child: Stack(
                      children: [
                        if (_analysisText.isNotEmpty)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(_analysisText,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        Positioned(
                          right: 6,
                          top: 6,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectionRect = null;
                                _highlightedIndexes.clear();
                                _analysisText = "";
                                _bestFitLine.clear();
                              });
                            },
                            child: Container(
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // tooltip
              if (_tooltipText != null && _tooltipPosition != null)
                Positioned(
                  left: _tooltipPosition!.dx,
                  top: _tooltipPosition!.dy - 48,
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.black87, borderRadius: BorderRadius.circular(6)),
                        child: Text(_tooltipText!, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      Positioned(
                        right: -6,
                        top: -6,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _tooltipText = null;
                              _tooltipPosition = null;
                            });
                          },
                          child: const CircleAvatar(radius: 8, backgroundColor: Colors.redAccent, child: Icon(Icons.close, color: Colors.white, size: 10)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // chọn điểm trong vùng
  // live: nếu true thì chỉ highlight; nếu false thì finalize selection (and optionally analyze)
  void _selectPointsInRect({bool live = false}) {
    if (_selectionRect == null || dataPoints.isEmpty) {
      setState(() {
        _highlightedIndexes.clear();
      });
      return;
    }

    final box = _chartKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final size = box.size;

    // NOTE: these paddings may need adjustment to match your chart layout exactly.
    const double leftPadding = 60.0;
    const double rightPadding = 20.0;
    const double topPadding = 20.0;
    const double bottomPadding = 40.0;

    final plotRect = Rect.fromLTWH(
      leftPadding,
      topPadding,
      size.width - leftPadding - rightPadding,
      size.height - topPadding - bottomPadding,
    );

    // compute min/max across dataPoints (to map value->pixel)
    final xMin = dataPoints.map((e) => e['x']!).reduce(min);
    final xMax = dataPoints.map((e) => e['x']!).reduce(max);
    final yMin = dataPoints.map((e) => e['y']!).reduce(min);
    final yMax = dataPoints.map((e) => e['y']!).reduce(max);

    final sel = _selectionRect!;
    final selected = <int>[];

    for (int i = 0; i < dataPoints.length; i++) {
      final p = dataPoints[i];
      // map value -> pixel
      final px = plotRect.left + ((p['x']! - xMin) / (xMax - xMin + 1e-9)) * plotRect.width;
      final py = plotRect.top + (1 - ((p['y']! - yMin) / (yMax - yMin + 1e-9))) * plotRect.height;
      if (sel.overlaps(Rect.fromCircle(center: Offset(px, py), radius: 8))) {
        selected.add(i);
      }
    }

    setState(() {
      _highlightedIndexes = selected.toSet();
    });

    if (!live && _isAnalysisOn) {
      _performAnalysis();
    }
  }

  // phân tích điểm đã chọn (_highlightedIndexes)
  void _performAnalysis() {
    if (!_isAnalysisOn || _highlightedIndexes.isEmpty) {
      setState(() {
        _analysisText = "";
        _bestFitLine.clear();
      });
      return;
    }

    final points = _highlightedIndexes.toList()..sort();
    final xs = points.map((i) => dataPoints[i]['x']!).toList();
    final ys = points.map((i) => dataPoints[i]['y']!).toList();

    switch (_analysisMode) {
      case "coordinate":
      // show coordinates of points (we'll summarize)
        final buf = StringBuffer();
        for (int i = 0; i < xs.length; i++) {
          buf.writeln("(${xs[i].toStringAsFixed(2)}, ${ys[i].toStringAsFixed(2)})");
          if (i >= 4) {
            buf.writeln("..."); // avoid too long
            break;
          }
        }
        _analysisText = buf.toString();
        _bestFitLine.clear();
        break;
      case "delta":
        final dx = xs.last - xs.first;
        final dy = ys.last - ys.first;
        _analysisText = "ΔX=${dx.toStringAsFixed(2)}, ΔY=${dy.toStringAsFixed(2)}";
        _bestFitLine.clear();
        break;
      case "minmax":
        final ymin = ys.reduce(min);
        final ymax = ys.reduce(max);
        _analysisText = "Min=${ymin.toStringAsFixed(2)}, Max=${ymax.toStringAsFixed(2)}";
        _bestFitLine.clear();
        break;
      case "avg":
        final avg = ys.reduce((a, b) => a + b) / ys.length;
        _analysisText = "Avg=${avg.toStringAsFixed(2)}";
        _bestFitLine.clear();
        break;
      case "slope":
        final n = xs.length;
        final sumX = xs.reduce((a, b) => a + b);
        final sumY = ys.reduce((a, b) => a + b);
        final sumXY = List.generate(n, (i) => xs[i] * ys[i]).reduce((a, b) => a + b);
        final sumX2 = xs.map((x) => x * x).reduce((a, b) => a + b);
        final b = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX + 1e-9);
        final a = (sumY - b * sumX) / n;
        _analysisText = "Y=${a.toStringAsFixed(2)} + ${b.toStringAsFixed(2)}X";
        // draw best-fit across min/max x of selected points
        final x1 = xs.first;
        final x2 = xs.last;
        _bestFitLine = [
          {'x': x1, 'y': a + b * x1},
          {'x': x2, 'y': a + b * x2},
        ];
        break;
      default:
        _analysisText = "";
        _bestFitLine.clear();
    }

    setState(() {});
  }
}
