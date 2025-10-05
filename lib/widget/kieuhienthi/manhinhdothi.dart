import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:testproject/Model/cambienhienthi.dart';
import 'package:testproject/Model/dulieucambien.dart';
import 'package:testproject/ultis/listcambien.dart' as globals;
import 'package:testproject/widget/kieuhienthi/manhinhsododothi.dart';

class ManhinhDothi extends StatelessWidget {
  const ManhinhDothi(
      {super.key,
      required this.stream,
      required this.streamPhantich,
      required this.streamCambien,
      required this.streamControllerDiemcat,
      required this.streamControllerXoaCambien});

  final Stream<DulieuCB> stream;
  final Stream<int> streamPhantich;
  final Stream<CambienHienthi> streamCambien;
  final StreamController<Map<String, Map<String, dynamic>>>
      streamControllerDiemcat;
  final StreamController<bool> streamControllerXoaCambien;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: LineChart(
        stream: stream,
        parent: this,
        streamPhantich: streamPhantich,
        streamControllerDiemcat: streamControllerDiemcat,
        streamControllerXoaCambien: streamControllerXoaCambien,
      ),
    );
  }
}

class LineChart extends StatefulWidget {
  const LineChart(
      {super.key,
      required this.stream,
      required this.parent,
      required this.streamPhantich,
      required this.streamControllerDiemcat,
      required this.streamControllerXoaCambien});

  final Stream<DulieuCB> stream;
  final ManhinhDothi parent;
  final Stream<int> streamPhantich;
  final StreamController<Map<String, Map<String, dynamic>>>
      streamControllerDiemcat;
  final StreamController<bool> streamControllerXoaCambien;

  @override
  _LineChartState createState() => _LineChartState();
}

class _LineChartState extends State<LineChart> {
  final List<ChartData> _chartData = [];
  Timer? _timer;
  late int sodothi = 0;
  late final List<PlotBand> _plotBand = [];
  final GlobalKey<SfCartesianChartState> _chartKey = GlobalKey();
  late double minX = 0, maxX = 0;
  late double minY = 0, maxY = 0;
  late int? previousKieuPhantich = 7;
  late StreamSubscription<CambienHienthi> _subscriptionCambien;
  final List<LineSeries<ChartData, double>> _lineSeriesList = [];
  final List<LineSeries<ChartData, double>> _bestfitSeriesList = [];

  final Map<String, List<ChartData>> _sensorDataMap = {};
  final Map<String, int> _listSodiem = {};
  late Map<String, ChartSeriesController> _chartSeriesController = {};
  late StreamController<Map<String, Map<String, dynamic>>>
      streamControllerDiemcat;
  late StreamController<bool> streamControllerXoaCambien;
  late StreamSubscription<DulieuCB> _dataSubscription;
  Map<String, List<double>> deviceCoordinates = {};
  double maxValueAbs = 1;
  double _zoomCenterX = 0.5;
  double _zoomCenterY = 0.5;
  double? _panStartMinX, _panStartMaxX, _panStartMinY, _panStartMaxY;
  Offset? _panStartPos;
  double _lastVisibleMinX = 0, _lastVisibleMaxX = 0;
  double _lastVisibleMinY = 0, _lastVisibleMaxY = 0;
  bool _isManualZoomY = false;
  @override
  void initState() {
    super.initState();

    _subscriptionCambien =
        widget.parent.streamCambien.listen((CambienHienthi cambien) {
      addNewLineSeries(cambien);
    });
    streamControllerDiemcat = widget.streamControllerDiemcat;
    streamControllerXoaCambien = widget.streamControllerXoaCambien;
    _dataSubscription = widget.stream.listen((dulieu) {
      print(dulieu);
      if (dulieu != null) {
        if (dulieu.datLai) {
          _resetZoomY();
          if (globals.historyViewMode.value) {
            maxValueAbs = 0;
            _maxYBase = 0;

            for (var cambienId in _sensorDataMap.keys) {
              final controller = _chartSeriesController[cambienId];
              final dataList = _sensorDataMap[cambienId];
              final oldLength = dataList?.length ?? 0;
              dataList?.clear();

              _listSodiem[cambienId] = 0;

              // Lấy lại dữ liệu từ lịch sử nếu có
              if (globals.historySelected != null &&
                  globals.historySelected['thietbi'] != null &&
                  globals.historySelected['thietbi'].containsKey(cambienId)) {
                final data =
                    globals.historySelected['thietbi'][cambienId]['data'];
                final newPoints = <ChartData>[];

                for (int i = 0; i < data.length; i++) {
                  final y = data[i];
                  final x = i.toDouble(); // reset lại từ 0
                  newPoints.add(ChartData(x, y));

                  if (y.abs() > maxValueAbs) {
                    maxValueAbs = y.abs();
                    _maxYBase =
                        maxValueAbs > _maxYBase ? maxValueAbs : _maxYBase;
                  }
                }

                dataList?.addAll(newPoints);
                _listSodiem[cambienId] = dataList?.length ?? 0;

                // Cập nhật lại biểu đồ bằng updateDataSource
                if (controller != null && newPoints.isNotEmpty) {
                  final addedIndexes =
                      List.generate(newPoints.length, (index) => index);
                  controller.updateDataSource(addedDataIndexes: addedIndexes);
                }
              }
            }
            print(maxValueAbs);
            print(_maxYBase);

            if (!mounted) return;
            setState(() {});
          } else {
            for (var cambienId in _sensorDataMap.keys) {
              _sensorDataMap[cambienId]?.clear();
              _listSodiem[cambienId] = 0;
            }
            setState(() {});
          }

          // Reset toàn bộ cảm biến

          if (dulieu.xoaCambien) {
            streamControllerXoaCambien.add(true);
          }
          maxValueAbs = 0;
          return;
        } else {
          // Thêm dữ liệu mới
          _sensorDataMap.putIfAbsent(dulieu.id, () => []);
          final dataList = _sensorDataMap[dulieu.id]!;

          final oldLength = _listSodiem[dulieu.id] ?? 0;
          final newPoints = <ChartData>[];

          for (int i = 0; i < dulieu.giaTri.length; i++) {
            final y = dulieu.giaTri[i];
            // final x = ((oldLength + i) * globals.tansolaymau / 1000).toDouble();
            final x = (oldLength + i).toDouble();
            // print('x: ${x}');
            // print('y: ${y}');
            newPoints.add(ChartData(x, y));

            if (y.abs() > maxValueAbs) {
              maxValueAbs = y.abs();
            }
          }

          // Thêm vào danh sách dữ liệu
          dataList.addAll(newPoints);

          // Cập nhật biểu đồ
          if (_chartSeriesController[dulieu.id] != null) {
            final addedIndexes = List.generate(
              newPoints.length,
              (index) => oldLength + index,
            );

            _chartSeriesController[dulieu.id]?.updateDataSource(
              addedDataIndexes: addedIndexes,
            );
          }

          // Cập nhật lại số điểm đã render
          _listSodiem[dulieu.id] = dataList.length;
        }
      }
    });
  }

  @override
  void dispose() {
    if (_timer != null && _timer!.isActive) {
      _timer!.cancel();
      print("cancle timer");
    }

    _chartData.clear();
    _subscriptionCambien.cancel();
    // streamControllerDiemcat.close();
    // streamControllerXoaCambien.close();
    super.dispose();

    // print("dispose");
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Column(
            children: [
              StreamBuilder<DulieuCB>(
                stream: widget.stream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.active &&
                      snapshot.hasData) {}
                  return Expanded(child: _buildChart());
                },
              ),
              StreamBuilder<int>(
                stream: widget.streamPhantich,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.active &&
                      snapshot.hasData) {
                    int kieuphantich = snapshot.data!;
                    // print(kieuphantich);
                    if (kieuphantich != previousKieuPhantich) {
                      previousKieuPhantich = kieuphantich;
                      switch (kieuphantich) {
                        case 0:
                          _drawOnePlotBand();
                          break;
                        case 1:
                          // Xử lý kiểu phân tích 1
                          _drawTwoPlotBand();
                          break;
                        case 2:
                          // Xử lý kiểu phân tích 2
                          _drawTwoPlotBand();
                          break;
                        case 3:
                          // Xử lý kiểu phân tích 3
                          _drawTwoPlotBand();
                          break;
                        case 4:
                          // Xử lý kiểu phân tích 4
                          _drawTwoPlotBand();
                          break;

                        default:
                          // Trường hợp không có giá trị
                          clearPlotBand();
                          break;
                      }
                    }
                  }
                  return Container(); // Có thể tùy chỉnh UI tại đây
                },
              ),
            ],
          ),
        ),
        SodoDothi(
          streamCambien: widget.parent.streamCambien,
        )
      ],
    );
  }

  void _drawOnePlotBand() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chartKey.currentState != null) {
        _chartKey.currentState!.setState(() {
          // Cập nhật trực tiếp plotBand
          double middleX = (minX + maxX) / 2;
          double bandWidthInPixels = 2;

          double chartWidthInUnits = maxX - minX;
          double screenWidthInPixels = MediaQuery.of(context).size.width;

          double bandWidthInUnits =
              (bandWidthInPixels / screenWidthInPixels) * chartWidthInUnits;
          _plotBand.clear();
          _plotBand.add(
            PlotBand(
              isVisible: true,
              start: middleX - bandWidthInUnits / 2,
              end: middleX + bandWidthInUnits / 2,
              color: Colors.black.withOpacity(0.5),
            ),
          );
        });
      }
    });
  }

  void _drawTwoPlotBand() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chartKey.currentState != null) {
        _chartKey.currentState!.setState(() {
          // Cập nhật trực tiếp plotBand
          double bandWidthInPixels = 2;

          double chartWidthInUnits = maxX - minX;
          double screenWidthInPixels = MediaQuery.of(context).size.width;

          double bandWidthInUnits =
              (bandWidthInPixels / screenWidthInPixels) * chartWidthInUnits;
          _plotBand.clear();
          _plotBand.addAll([
            PlotBand(
              isVisible: true,
              start: minX,
              end: minX + bandWidthInUnits,
              color: Colors.black.withOpacity(0.5),
            ),
            PlotBand(
              isVisible: true,
              start: maxX - bandWidthInUnits,
              end: maxX,
              color: Colors.black.withOpacity(0.5),
            ),
          ]);
        });
      }
    });
  }

  void clearPlotBand() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chartKey.currentState != null) {
        _chartKey.currentState!.setState(() {
          _plotBand.clear();
        });
      }
      setState(() {
        _bestfitSeriesList.clear();
      });
    });
  }

  double _maxXBase = 3; // Giá trị này tùy theo dữ liệu của bạn
  double _maxYBase = 1; // Cho trục Y nếu cần zoom theo chiều dọc

  double _zoomFactorX = 1.0;
  double _zoomFactorY = 1.0;
  String modeZoom = '';

  void _handlePointerDown(PointerDownEvent event, BoxConstraints constraints) {
    if (previousKieuPhantich != 7 && previousKieuPhantich != null) {
      return;
    }
    final tapY = event.localPosition.dy;
    final chartHeight = constraints.maxHeight;
    final tapX = event.localPosition.dx;
    final chartWidth = constraints.maxWidth;

    // Nếu zoom trục X
    if (tapY >= chartHeight - 60 && tapY <= chartHeight) {
      setState(() {
        modeZoom = 'x';
        final tapRatio = tapX / chartWidth;
        _zoomCenterX = tapRatio.clamp(0.0, 1.0);
      });
    }
    // Nếu zoom trục Y
    else if (tapX >= 0 && tapX <= 60) {
      setState(() {
        modeZoom = 'y';
        final tapRatio = 1 - tapY / chartHeight; // đảo ngược trục
        _isManualZoomY = true; // 👈 user đang zoom thủ công Y

        _zoomCenterY = tapRatio.clamp(0.0, 1.0);
      });
    }
    // Nếu click trong vùng biểu đồ → pan
    else {
      setState(() {
        modeZoom = 'pan';
        // lưu lại min/max hiện tại để pan tính delta
        _panStartMinX = _lastVisibleMinX;
        _panStartMaxX = _lastVisibleMaxX;
        _panStartMinY = _lastVisibleMinY;
        _panStartMaxY = _lastVisibleMaxY;
        _panStartPos = event.localPosition;
      });
    }
  }

  // ===== Xử lý khi kéo chuột =====
  void _handleChartDrag(DragUpdateDetails details, BoxConstraints constraints) {
    const zoomSpeed = 0.01;

    setState(() {
      // === Zoom trục X ===
      if (modeZoom == 'x') {
        if (details.delta.dx > 0) {
          _zoomFactorX = (_zoomFactorX - zoomSpeed).clamp(0.05, 1.0);
        } else if (details.delta.dx < 0) {
          _zoomFactorX = (_zoomFactorX + zoomSpeed).clamp(0.05, 1.0);
        }
      }

      // === Zoom trục Y ===
      if (modeZoom == 'y') {
        if (details.delta.dy < 0) {
          _zoomFactorY = (_zoomFactorY - zoomSpeed).clamp(0.05, 1.0);
        } else if (details.delta.dy > 0) {
          _zoomFactorY = (_zoomFactorY + zoomSpeed).clamp(0.05, 1.0);
        }
      }

      // === Pan ===
      if (modeZoom == 'pan' && _panStartPos != null) {
        // Tính offset từ lúc bắt đầu chạm đến vị trí hiện tại
        final dx = (details.localPosition.dx - _panStartPos!.dx) / constraints.maxWidth;
        final dy = (details.localPosition.dy - _panStartPos!.dy) / constraints.maxHeight;

        final fullRangeX = _maxXBase;
        final fullRangeY = _maxYBase.abs() * 1.5;

        final visibleRangeX = fullRangeX * _zoomFactorX;
        final visibleRangeY = fullRangeY * _zoomFactorY;

        _lastVisibleMinX = (_panStartMinX! - dx * visibleRangeX)
            .clamp(0, fullRangeX - visibleRangeX);
        _lastVisibleMaxX = _lastVisibleMinX + visibleRangeX;

        _lastVisibleMinY = (_panStartMinY! + dy * visibleRangeY)
            .clamp(-fullRangeY, fullRangeY - visibleRangeY);
        _lastVisibleMaxY = _lastVisibleMinY + visibleRangeY;
      }
    });

  }

  Widget _buildChart() {
    return StreamBuilder<int>(
      stream: widget.streamPhantich,
      builder: (context, snapshot) {
        int maxLength = 0;

        for (final series in _lineSeriesList) {
          final data = series.dataSource;
          if (data != null && data.length > maxLength) {
            maxLength = data.length;
          }
        }
        _maxXBase = maxLength.toDouble() > _maxXBase
            ? maxLength.toDouble() - 1
            : _maxXBase;

        double fullRangeX = _maxXBase;
        double minZoomX = 2 / fullRangeX;
        double maxZoomX = 1.0;
        _zoomFactorX = _zoomFactorX.clamp(minZoomX, maxZoomX);

        _maxYBase = maxValueAbs > _maxYBase ? maxValueAbs : _maxYBase;
        double fullRangeY = _maxYBase.abs() * 1.5;

        // Nếu đang pan thì dùng _lastVisibleMin/Max
        double visibleMinX, visibleMaxX, visibleMinY, visibleMaxY;

        if (modeZoom == 'pan') {
          visibleMinX = _lastVisibleMinX;
          visibleMaxX = _lastVisibleMaxX;
          visibleMinY = _lastVisibleMinY;
          visibleMaxY = _lastVisibleMaxY;
        } else {
          // Zoom theo tâm click
          double visibleRangeX = fullRangeX * _zoomFactorX;
          double centerValueX = _zoomCenterX * fullRangeX;
          visibleMinX = centerValueX - visibleRangeX / 2;
          visibleMaxX = centerValueX + visibleRangeX / 2;

          double visibleRangeY = fullRangeY * _zoomFactorY;
          double centerValueY = -fullRangeY + _zoomCenterY * (2 * fullRangeY);
          visibleMinY = centerValueY - visibleRangeY / 2;
          visibleMaxY = centerValueY + visibleRangeY / 2;

          // Clamp trong giới hạn
          visibleMinX = visibleMinX.clamp(0, fullRangeX - visibleRangeX);
          visibleMaxX = visibleMinX + visibleRangeX;

          visibleMinY = visibleMinY.clamp(-fullRangeY, fullRangeY - visibleRangeY);
          visibleMaxY = visibleMinY + visibleRangeY;

          // Lưu lại để pan dùng
          _lastVisibleMinX = visibleMinX;
          _lastVisibleMaxX = visibleMaxX;
          _lastVisibleMinY = visibleMinY;
          _lastVisibleMaxY = visibleMaxY;
        }
        if (!_isManualZoomY) {
          // Auto expand Y nếu dữ liệu vượt ra ngoài
          if (maxValueAbs > visibleMaxY) {
            final extra = maxValueAbs * 0.2;
            visibleMaxY = maxValueAbs + extra;
            visibleMinY = -visibleMaxY;
          }

          if (-maxValueAbs < visibleMinY) {
            final extra = maxValueAbs * 0.2;
            visibleMinY = -maxValueAbs - extra;
            visibleMaxY = maxValueAbs + extra;
          }
        }
        int kieuphantich = 7;
        if (snapshot.connectionState == ConnectionState.active &&
            snapshot.hasData &&
            globals.isStartPress == false) {
          kieuphantich = snapshot.data!;
          previousKieuPhantich = kieuphantich;
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) => _handlePointerDown(event, constraints),
              child: RawGestureDetector(
                gestures: <Type, GestureRecognizerFactory>{
                  CustomPanGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                          CustomPanGestureRecognizer>(
                    () => CustomPanGestureRecognizer(),
                    (CustomPanGestureRecognizer instance) {
                      instance.onUpdate = (details) {
                        if (kieuphantich == 7) {
                          _handleChartDrag(details, constraints);
                        }
                      };
                    },
                  ),
                },
                child: SfCartesianChart(
                  key: _chartKey,
                  zoomPanBehavior: ZoomPanBehavior(
                    enablePanning: false,
                    enablePinching: false,
                    enableMouseWheelZooming: false,
                    enableDoubleTapZooming: false,
                    enableSelectionZooming: false,
                    zoomMode: ZoomMode.xy,
                  ),
                  primaryXAxis: CategoryAxis(
                    minimum: visibleMinX,
                    maximum: visibleMaxX,
                    plotBands: _plotBand,
                    labelPlacement: LabelPlacement.onTicks,
                    axisLabelFormatter: (AxisLabelRenderDetails details) {
                      num value = details.value;
                      // Ép về kiểu int và hiển thị
                      return ChartAxisLabel(
                          '${value * globals.tansolaymau / 1000}', TextStyle());
                    },
                    axisLine: AxisLine(
                      color: modeZoom == 'x' ? Colors.black : Colors.grey,
                      width: modeZoom == 'x' ? 3 : 1, // Dày hơn khi highlight
                    ),
                    labelStyle: TextStyle(
                      color: modeZoom == 'x' ? Colors.black : Colors.grey,
                    ),
                  ),
                  primaryYAxis: NumericAxis(
                    minimum: visibleMinY,
                    maximum: visibleMaxY,
                    axisLine: AxisLine(
                      color: modeZoom == 'y' ? Colors.black : Colors.grey,
                      width: modeZoom == 'y' ? 3 : 1,
                    ),
                    labelStyle: TextStyle(
                      color: modeZoom == 'y' ? Colors.black : Colors.grey,
                    ),
                  ),
                  onActualRangeChanged: (ActualRangeChangedArgs args) {
                    if (args.orientation == AxisOrientation.horizontal) {
                      minX = (args.visibleMin as num).toDouble();
                      maxX = (args.visibleMax as num).toDouble();
                      // print("Min X: $minX, Max X: $maxX");
                    }
                    if (args.orientation == AxisOrientation.vertical) {
                      minY = (args.visibleMin as num).toDouble();
                      maxY = (args.visibleMax as num).toDouble();
                    }
                  },
                  onChartTouchInteractionUp: (ChartTouchInteractionArgs args) {
                    // print('👆 Tap on chart at: ${args.position}');
                    if (kieuphantich == 7) return;
                    if (kieuphantich == 0) {
                      _handleChartTapOnePlotBand(args.position);
                    } else {
                      _handleChartTapTwoPlotBand(args.position, kieuphantich);
                    }
                  },
                  series: [..._lineSeriesList, ..._bestfitSeriesList],
                ),
              ),
            );
          },
        );
        // ko ở kiểu phân tích nào thì => chế độ zoom
      },
    );
  }
  void _resetZoomY() {
    setState(() {
      _zoomFactorY = 1.0;
      _zoomCenterY = 0.5;
      _isManualZoomY = false; // 👈 bật lại auto-scale
    });
  }
  void _handleChartTapOnePlotBand(Offset localPosition) {
    _bestfitSeriesList.clear();
    final chartBox = _chartKey.currentContext!.findRenderObject() as RenderBox;

    // Lấy chiều rộng biểu đồ, không bao gồm trục Y
    final chartWidth = chartBox.size.width;

    // Kiểm tra nếu điểm click nằm trong phạm vi của biểu đồ (không phải ngoài trục Y)
    if (localPosition.dx < 0 || localPosition.dx > chartWidth) {
      return; // Không xử lý nếu điểm click ngoài vùng biểu đồ
    }

    ChartData? nearestData;
    double minPixelDistance = double.infinity;

    // Tính toán vị trí X sau khi trừ cột Y
    double adjustedLocalX = localPosition.dx;
    // print('Click: $adjustedLocalX');
    // Tìm data gần nhất theo pixel X
    for (final entry in _sensorDataMap.entries) {
      final List<ChartData> dataList = entry.value;
      for (int i = 0; i < dataList.length; i++) {
        final data = dataList[i];

        // Đổi giá trị thời gian sang tọa độ pixel trên biểu đồ
        double dataPixelX = ((data.time - minX) / (maxX - minX)) * chartWidth;

        // Tính khoảng cách giữa vị trí click và tọa độ của dữ liệu
        double distance = (dataPixelX - adjustedLocalX).abs();

        // Cập nhật điểm gần nhất nếu khoảng cách nhỏ hơn
        if (distance < minPixelDistance) {
          minPixelDistance = distance;
          nearestData = data;
          // print('${data.time}: ${distance}');
        }
      }
    }

    if (nearestData == null) return;

    double nearestTime = nearestData.time;

    int nearestBandIndex = 0;

    // Vẽ lại PlotBand tại điểm gần nhất
    setState(() {
      _plotBand[nearestBandIndex] = PlotBand(
        isVisible: true,
        start: nearestTime - 0.007,
        end: nearestTime + 0.007,
        color: Colors.black,
        borderWidth: 0,
      );
    });

    // Tính lại các điểm cắt, nếu có
    _recalculateToado();
  }

  void _handleChartTapTwoPlotBand(Offset localPosition, int kieuphantich) {
    _bestfitSeriesList.clear();
    final chartBox = _chartKey.currentContext!.findRenderObject() as RenderBox;

    // Lấy chiều rộng biểu đồ, không bao gồm trục Y
    final chartWidth = chartBox.size.width;

    // Kiểm tra nếu điểm click nằm trong phạm vi của biểu đồ (không phải ngoài trục Y)
    if (localPosition.dx < 0 || localPosition.dx > chartWidth) {
      return; // Không xử lý nếu điểm click ngoài vùng biểu đồ
    }

    ChartData? nearestData;
    double minPixelDistance = double.infinity;

    // Tính toán vị trí X sau khi trừ cột Y
    double adjustedLocalX = localPosition.dx;
    // print('Click: $adjustedLocalX');
    // Tìm data gần nhất theo pixel X
    for (final entry in _sensorDataMap.entries) {
      final List<ChartData> dataList = entry.value;
      for (int i = 0; i < dataList.length; i++) {
        final data = dataList[i];

        // Đổi giá trị thời gian sang tọa độ pixel trên biểu đồ
        double dataPixelX = ((data.time - minX) / (maxX - minX)) * chartWidth;

        // Tính khoảng cách giữa vị trí click và tọa độ của dữ liệu
        double distance = (dataPixelX - adjustedLocalX).abs();

        // Cập nhật điểm gần nhất nếu khoảng cách nhỏ hơn
        if (distance < minPixelDistance) {
          minPixelDistance = distance;
          nearestData = data;
          // print('${data.time}: ${distance}');
        }
      }
    }

    if (nearestData == null) return;

    double nearestTime = nearestData.time;

    // Xác định plot band gần nhất để thay thế
    double leftDistance =
        (nearestTime - (_plotBand[0].start as num).toDouble()).abs();
    double rightDistance =
        (nearestTime - (_plotBand[1].start as num).toDouble()).abs();
    int nearestBandIndex = leftDistance < rightDistance ? 0 : 1;

    // Vẽ lại PlotBand tại điểm gần nhất
    setState(() {
      _plotBand[nearestBandIndex] = PlotBand(
        isVisible: true,
        start: nearestTime - 0.007,
        end: nearestTime + 0.007,
        color: Colors.black,
        borderWidth: 0,
      );
    });

    // Tính lại các điểm cắt, nếu có
    _recalculateIntersections(kieuphantich);
  }

  // void _handleChartTap(Offset localPosition) {
  //   final chartBox = _chartKey.currentContext!.findRenderObject() as RenderBox;
  //   final chartWidth = chartBox.size.width;
  //   final chartHeight = chartBox.size.height;
  //
  //   // Lấy tỉ lệ tương ứng trên trục X/Y
  //   final double xRatio = localPosition.dx / chartWidth;
  //   final double yRatio = localPosition.dy / chartHeight;
  //
  //   // Tính giá trị thực trên biểu đồ
  //   final double tappedX = minX + (maxX - minX) * xRatio;
  //   final double tappedY = maxY - (maxY - minY) * yRatio;
  //
  //   // Tìm điểm gần nhất trên tất cả các LineSeries
  //   double? nearestX;
  //   double nearestDistance = double.infinity;
  //   print('tapX: $tappedX');
  //
  //   for (final entry in _sensorDataMap.entries) {
  //     final List<ChartData> dataList = entry.value;
  //
  //     for (final data in dataList) {
  //       double dx = (data.time - tappedX).abs();
  //       double dy = (data.value - tappedY).abs();
  //       double distance = dx ;
  //
  //       if (distance < nearestDistance) {
  //         nearestDistance = distance;
  //         nearestX = data.time.toDouble();
  //       }
  //     }
  //   }
  //   print(nearestX);
  //
  //   if (nearestX == null) return;
  //
  //   // Tính chiều rộng band như cũ
  //   final double chartUnitWidth = maxX - minX;
  //   final double screenWidthInPixels = chartWidth;
  //   final double bandWidthInUnits = (2 / screenWidthInPixels) * chartUnitWidth;
  //
  //   // Tìm plotBand gần nhất và cập nhật lại vị trí
  //   double leftDistance = (nearestX - (_plotBand[0].start as double)).abs();
  //   double rightDistance = (nearestX - (_plotBand[1].start as double)).abs();
  //   int nearestBandIndex = leftDistance < rightDistance ? 0 : 1;
  //   print(nearestBandIndex);
  //   print(nearestX! - bandWidthInUnits / 2);
  //   print(nearestX + bandWidthInUnits / 2);
  //
  //   setState(() {
  //     _plotBand[nearestBandIndex] = PlotBand(
  //       isVisible: true,
  //       start: nearestX! - bandWidthInUnits / 2,
  //       end: nearestX + bandWidthInUnits / 2,
  //       color: Colors.black.withOpacity(0.5),
  //     );
  //   });
  //
  //   // Gọi lại logic xử lý giao điểm như cũ
  //   _recalculateIntersections();
  // }

  Color findFirstUnusedColor(i) {
    for (final color in globals.listMamau) {
      if (!globals.listColorCambien.contains(color)) {
        return color;
      }
    }
    return globals.listMamau[i - 1];
  }

  void _recalculateToado() {
    Map<String, Map<String, dynamic>> deviceCoordinates = {};
    final int bandIndex = (_plotBand[0].start as num).round();

    for (int index = 0; index < _lineSeriesList.length; index++) {
      final series = _lineSeriesList[index];
      final String seriesId = series.name!;
      final List<ChartData> dataPoints = _sensorDataMap[seriesId] ?? [];
      if (bandIndex < 0 || bandIndex >= dataPoints.length) {
        continue;
      }

      final double bandX = dataPoints[bandIndex].time.toDouble();
      final indexY = dataPoints.indexWhere((p) => p.time == bandX);
      final bandY = (indexY != -1) ? dataPoints[indexY].value : null;

      if (bandY != null) {
        deviceCoordinates[seriesId] = {
          'coordinates': [bandX, bandY]
        };
      }
    }

    streamControllerDiemcat.add(deviceCoordinates);
  }

  // void _recalculateIntersections(int kieuphantich) {
  //   Map<String, Map<String, dynamic>> deviceCoordinates = {};
  //
  //   for (int index = 0; index < _lineSeriesList.length; index++) {
  //     final series = _lineSeriesList[index];
  //     final String seriesId = series.name!;
  //     final List<ChartData> dataPoints = _sensorDataMap[seriesId] ?? [];
  //
  //     List<double> band0Coordinates = [];
  //     List<double> band1Coordinates = [];
  //
  //     for (int i = 0; i < 2; i++) {
  //       final int bandIndex = (_plotBand[i].start as num).round();
  //
  //       // ✅ Lấy giá trị time tương ứng với chỉ số category
  //       if (bandIndex < 0 || bandIndex >= dataPoints.length) continue;
  //
  //       final double bandX = dataPoints[bandIndex].time.toDouble();
  //
  //       for (int j = 0; j < dataPoints.length - 1; j++) {
  //         final x1 = dataPoints[j].time;
  //         final x2 = dataPoints[j + 1].time;
  //         final y1 = dataPoints[j].value;
  //         final y2 = dataPoints[j + 1].value;
  //
  //         if ((x1 <= bandX && bandX <= x2) || (x2 <= bandX && bandX <= x1)) {
  //           final double t = (bandX - x1) / (x2 - x1);
  //           final double y = y1 + t * (y2 - y1);
  //
  //           if (i == 0) {
  //             band0Coordinates = [bandX, y];
  //           } else {
  //             band1Coordinates = [bandX, y];
  //           }
  //
  //           break;
  //         }
  //       }
  //     }
  //
  //     deviceCoordinates[seriesId] = {
  //       'coordinates': [band0Coordinates, band1Coordinates],
  //       'deltaY': (band1Coordinates.isNotEmpty && band0Coordinates.isNotEmpty)
  //           ? (band1Coordinates[1] - band0Coordinates[1])
  //           : null,
  //     };
  //   }
  //
  //   streamControllerDiemcat.add(deviceCoordinates);
  // }
  void _recalculateIntersections(int kieuphantich) {
    Map<String, Map<String, dynamic>> deviceCoordinates = {};
    for (var series in _lineSeriesList) {
      final String seriesId = series.name!;
      final List<ChartData> dataPoints = _sensorDataMap[seriesId] ?? [];

      // Lấy chỉ số plotband
      final int band0Index = (_plotBand[0].start as num).round();
      final int band1Index = (_plotBand[1].start as num).round();

      if (band0Index < 0 ||
          band1Index < 0 ||
          band0Index >= dataPoints.length ||
          band1Index >= dataPoints.length) {
        continue;
      }

      final double band0X = dataPoints[band0Index].time.toDouble();
      final double band1X = dataPoints[band1Index].time.toDouble();
      final double startX = band0X < band1X ? band0X : band1X;
      final double endX = band0X > band1X ? band0X : band1X;

      if (kieuphantich == 1) {
        // --- Giữ nguyên cách tính cũ ---
        final band0Coordinates = _interpolatePointAtX(dataPoints, band0X);
        final band1Coordinates = _interpolatePointAtX(dataPoints, band1X);

        deviceCoordinates[seriesId] = {
          'coordinates': [band0Coordinates, band1Coordinates],
          'deltaY': (band0Coordinates != null && band1Coordinates != null)
              ? (band1Coordinates[1] - band0Coordinates[1])
              : null,
        };
      } else if (kieuphantich == 2) {
        // --- Lấy tất cả điểm trong khoảng ---
        final pointsInRange = dataPoints
            .where((p) => p.time >= startX && p.time <= endX)
            .map((p) => [p.time.toDouble(), p.value.toDouble()])
            .toList();

        if (pointsInRange.length >= 2) {
          final fit = _linearBestFit(pointsInRange);
          deviceCoordinates[seriesId] = {
            'coordinates': [startX, endX],
            'fit': fit, // {slope, intercept, r2}
          };
          final slope = fit['slope'] as double;
          final intercept = fit['intercept'] as double;

          final yStart = slope * startX + intercept;
          final yEnd = slope * endX + intercept;
          _bestfitSeriesList.add(
            LineSeries<ChartData, double>(
              name: '${seriesId}_bestfit',
              color: series.color,
              dashArray: [6, 3],
              dataSource: [
                ChartData(startX, yStart),
                ChartData(endX, yEnd),
              ],
              animationDuration: 0,
              xValueMapper: (ChartData data, _) => data.time,
              yValueMapper: (ChartData data, _) => data.value,
            ),
          );
          setState(() {}); // cập nhật chart
        }
      } else if (kieuphantich == 3) {
        // --- Min, Max, Trung bình ---
        final valuesInRange = dataPoints
            .where((p) => p.time >= startX && p.time <= endX)
            .map((p) => p.value)
            .toList();

        if (valuesInRange.isNotEmpty) {
          final minVal = valuesInRange.reduce((a, b) => a < b ? a : b);
          final maxVal = valuesInRange.reduce((a, b) => a > b ? a : b);
          final avgVal =
              valuesInRange.reduce((a, b) => a + b) / valuesInRange.length;

          deviceCoordinates[seriesId] = {
            'coordinates': [minVal, maxVal, avgVal],
          };
        }
      } else if (kieuphantich == 4) {
        final pointsInRange = dataPoints
            .where((p) => p.time >= startX && p.time <= endX)
            .toList();
        if (pointsInRange.length >= 2) {
          double sumSquares = 0.0;
          for (var p in pointsInRange) {
            sumSquares += p.value * p.value;
          }

          double rms = sqrt(sumSquares / pointsInRange.length);
          deviceCoordinates[seriesId] = {
            'coordinates': [rms],
          };
        }
      }
    }

    streamControllerDiemcat.add(deviceCoordinates);
  }

  /// Hàm nội suy giá trị y tại x bất kỳ
  List<double>? _interpolatePointAtX(List<ChartData> points, double targetX) {
    for (int i = 0; i < points.length - 1; i++) {
      final x1 = points[i].time.toDouble();
      final x2 = points[i + 1].time.toDouble();
      if ((x1 <= targetX && targetX <= x2) ||
          (x2 <= targetX && targetX <= x1)) {
        final y1 = points[i].value.toDouble();
        final y2 = points[i + 1].value.toDouble();
        final t = (targetX - x1) / (x2 - x1);
        final y = y1 + t * (y2 - y1);
        return [targetX, y];
      }
    }
    return null;
  }

  /// Hàm hồi quy tuyến tính đơn giản
  Map<String, double> _linearBestFit(List<List<double>> points) {
    final n = points.length;
    final sumX = points.fold(0.0, (sum, p) => sum + p[0]);
    final sumY = points.fold(0.0, (sum, p) => sum + p[1]);
    final sumXY = points.fold(0.0, (sum, p) => sum + p[0] * p[1]);
    final sumX2 = points.fold(0.0, (sum, p) => sum + p[0] * p[0]);

    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;

    // Tính R²
    final meanY = sumY / n;
    final ssTot =
        points.fold(0.0, (sum, p) => sum + (p[1] - meanY) * (p[1] - meanY));
    final ssRes = points.fold(
        0.0,
        (sum, p) =>
            sum +
            (p[1] - (slope * p[0] + intercept)) *
                (p[1] - (slope * p[0] + intercept)));
    final r2 = 1 - (ssRes / ssTot);

    return {
      'slope': slope,
      'intercept': intercept,
      'r2': r2,
    };
  }

  void addNewLineSeries(CambienHienthi cambien) {
    print("===> addNewLineSeries với id: ${cambien.id}");
    bool exists = _lineSeriesList.any((series) => series.name == cambien.id);
    if (exists) {
      setState(() {
        // Tìm màu của series cần xoá
        final matchedSeries =
            _lineSeriesList.where((series) => series.name == cambien.id);

        if (matchedSeries.isNotEmpty) {
          final removedSeries = matchedSeries.first;
          globals.listColorCambien.remove(removedSeries.color);
        }

        _lineSeriesList.removeWhere((series) => series.name == cambien.id);
        _chartSeriesController.remove(cambien.id);
        _sensorDataMap[cambien.id]?.clear();
        _listSodiem[cambien.id] = 0;
        sodothi = sodothi - 1;
      });
      return;
    }
    sodothi++;
    if (!_sensorDataMap.containsKey(cambien.id)) {
      _sensorDataMap[cambien.id] = [];
      _listSodiem[cambien.id] = 0;
    }
    final color = findFirstUnusedColor(sodothi);
    final newLineSeries = LineSeries<ChartData, double>(
      name: cambien.id,
      dataSource: _sensorDataMap[cambien.id],
      xValueMapper: (ChartData data, _) => data.time,
      yValueMapper: (ChartData data, _) => data.value,
      onRendererCreated: (ChartSeriesController controller) {
        _chartSeriesController[cambien.id] = controller;
      },
      width: 2,
      color: color,
      animationDuration: 0,
      markerSettings: MarkerSettings(
        height: 3,
        width: 3,
        isVisible: true,
        shape: DataMarkerType.circle,
        color: color,
        borderColor: color,
      ),
      // onPointTap: _moveNearestPlotBandFromPoint,
    );
    globals.listColorCambien.add(color);
    // Cập nhật lại biểu đồ bằng updateDataSource
    if (globals.historyViewMode.value == true) {
      if (globals.historySelected != null &&
          globals.historySelected['thietbi'] != null &&
          globals.historySelected['thietbi'].containsKey(cambien.id)) {
        final data = globals.historySelected['thietbi'][cambien.id]['data'];
        final dataList = _sensorDataMap[cambien.id]!;

        final oldLength = _listSodiem[cambien.id] ?? 0;
        final newPoints = <ChartData>[];

        for (int i = 0; i < data.length; i++) {
          final y = data[i];
          // final x = ((oldLength + i) * globals.tansolaymau / 1000).toDouble();
          final x = (oldLength + i).toDouble();
          // print('x: ${x}');
          // print('y: ${y}');
          newPoints.add(ChartData(x, y));

          if (y.abs() > maxValueAbs) {
            maxValueAbs = y.abs();
          }
        }
        dataList.addAll(newPoints);
        _listSodiem[cambien.id] = dataList.length;
        final controller = _chartSeriesController[cambien.id];
        if (controller != null && newPoints.isNotEmpty) {
          final addedIndexes =
              List.generate(newPoints.length, (index) => index);
          controller.updateDataSource(addedDataIndexes: addedIndexes);
        }
      }
    }
    setState(() {
      _lineSeriesList.add(newLineSeries);
    });
  }

// void _moveNearestPlotBandFromPoint(ChartPointDetails details) {
//   if(previousKieuPhantich == 7){
//     return;
//   }
//   final pointIndex = details.pointIndex;
//   final dataPoints = details.dataPoints;
//
//   if (pointIndex != null && dataPoints != null && pointIndex < dataPoints.length) {
//     final CartesianChartPoint point = dataPoints[pointIndex];
//     final double xValue = point.xValue?.toDouble() as double;
//
//     // Tính band width
//     final RenderBox box = _chartKey.currentContext!.findRenderObject() as RenderBox;
//     final double screenWidthInPixels = box.size.width;
//     final double chartWidthInUnits = maxX - minX;
//     final double bandWidthInUnits = (2 / screenWidthInPixels) * chartWidthInUnits;
//
//     setState(() {
//       // Xác định plot band gần nhất
//       double leftDistance = (xValue - (_plotBand[0].start as double)).abs();
//       double rightDistance = (xValue - (_plotBand[1].start as double)).abs();
//       int nearestIndex = leftDistance < rightDistance ? 0 : 1;
//
//       _plotBand[nearestIndex] = PlotBand(
//         isVisible: true,
//         start: xValue - bandWidthInUnits / 2,
//         end: xValue + bandWidthInUnits / 2,
//         color: Colors.black.withOpacity(0.5),
//       );
//     });
//   }
//   _recalculateIntersections();
// }

// Hàm tính toán điểm trên đồ thị gần vị trí kéo nhất
// ChartData _getNearestPoint(double xPosition) {
//   double minDistance = double.infinity;
//   ChartData nearestPoint = _chartData.first;
//
//   for (ChartData point in _chartData) {
//     double distance = (point.time - xPosition).abs();
//     if (distance < minDistance) {
//       minDistance = distance;
//       nearestPoint = point;
//     }
//   }
//
//   return nearestPoint;
// }
}

class ChartData {
  ChartData(this.time, this.value);

  final double time;
  final double value;
}

class CustomPanGestureRecognizer extends OneSequenceGestureRecognizer {
  GestureDragUpdateCallback? onUpdate;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent && onUpdate != null) {
      onUpdate!(DragUpdateDetails(
        globalPosition: event.position,
        localPosition: event.localPosition, // cần cái này để tính offset tổng
        delta: event.delta,
      ));
    }
  }

  @override
  String get debugDescription => 'customPan';

  @override
  void didStopTrackingLastPointer(int pointer) {}
}
