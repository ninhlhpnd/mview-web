// manhinhdothi.dart
import 'dart:async';
import 'dart:ffi' hide Size;
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Size;
import 'dart:ui' show Size;

import 'package:mview/Model/cambienhienthi.dart';
import 'package:mview/Model/dulieucambien.dart';
import 'package:mview/ultis/listcambien.dart' as globals;
import 'package:mview/widget/kieuhienthi/manhinhsododothi.dart';

/// High-performance realtime chart using CustomPainter.
/// - Keeps same external API as your previous code:
///   LineChart(stream: ..., parent: ..., ...)
/// - Draws grid, ticks, labels
/// - Zoom X / Zoom Y / Pan modes (toggle by buttons)
/// - Markers, downsampling (min-max per pixel bin) for speed
/// - Sends add/remove events to SodoDothi via internal StreamController
class ManhinhDothi extends StatelessWidget {
  const ManhinhDothi({
    super.key,
    required this.stream,
    required this.streamPhantich,
    required this.streamCambien,
    required this.streamControllerDiemcat,
    required this.streamControllerXoaCambien,
    required this.listDeviceSelected,
  });

  final Stream<DulieuCB> stream;
  final Stream<int> streamPhantich;
  final Stream<CambienHienthi> streamCambien;
  final StreamController<Map<String, Map<String, dynamic>>>
      streamControllerDiemcat;
  final StreamController<bool> streamControllerXoaCambien;
  final List<dynamic> listDeviceSelected;

  @override
  Widget build(BuildContext context) {
    return LineChart(
      stream: stream,
      parent: this,
      streamPhantich: streamPhantich,
      streamControllerDiemcat: streamControllerDiemcat,
      streamControllerXoaCambien: streamControllerXoaCambien,
      listDeviceSelected: listDeviceSelected,
    );
  }
}

class LineChart extends StatefulWidget {
  const LineChart({
    super.key,
    required this.stream,
    required this.parent,
    required this.streamPhantich,
    required this.streamControllerDiemcat,
    required this.streamControllerXoaCambien,
    required this.listDeviceSelected,
  });

  final Stream<DulieuCB> stream;
  final ManhinhDothi parent;
  final Stream<int> streamPhantich;
  final StreamController<Map<String, Map<String, dynamic>>>
      streamControllerDiemcat;
  final StreamController<bool> streamControllerXoaCambien;
  final List<dynamic> listDeviceSelected;

  @override
  State<LineChart> createState() => _LineChartState();
}

class _LineChartState extends State<LineChart> {
  // sensorId -> list of y-values (time is index)
  final Map<String, List<double>> _sensorData = {};
  final Map<String, Color> _colors = {};
  final Map<String, dynamic> _meta = {}; // placeholder if needed
  late StreamSubscription<DulieuCB> _dataSubscription;
  late StreamSubscription<CambienHienthi> _cambienSubscription;
  late StreamSubscription<int> _phantichSubscription;
  // local stream to feed SodoDothi (so it receives add/remove events)
  final StreamController<CambienHienthi> _streamCambienLocal =
      StreamController<CambienHienthi>.broadcast();
  int _kieuPhantich = 7; // 7 = không phân tích
  List<double> _limitLines = []; // chứa vị trí X theo thời gian (giây)
  bool _chartReady = false;
  List<_BestFitLine> _bestFitLines = [];

  final List<String> _sensorSelectionOrder = [];
  final Map<String, CambienHienthi> _cambienInfo = {};
  double _yMinData = -1.0;
  double _yMaxData = 1.0;
  double? _centerY;

  // rendering / buffering
  static const int _maxPoints = 20000; // hard cap; but windowed by _windowSize
  static const int _windowSizeDefault =
      1000; // number of samples visible by default
  // int _windowSize = _windowSizeDefault;
  double _windowSize = 1000;

  // view transform in data coordinates
  double _centerIndex = 0; // center x index shown (in sample units)
  double _zoomX =
      1.0; // >1 zoomed in (less samples on screen), <1 zoomed out (more samples)
  double _zoomY = 1.0; // vertical scale multiplier
  Mode _mode = Mode.pan;

  final bool debugPrints = false;

  bool _autoFollow = true; // tự động cuộn theo dữ liệu mới
  void _updateYAxisRange() {
    if (_sensorSelectionOrder.isEmpty) {
      _yMinData = -1.0;
      _yMaxData = 1.0;
      return;
    }
    String newestId = _sensorSelectionOrder.last;
    CambienHienthi? newestCB = _cambienInfo[newestId];
    if (newestCB != null) {
      try {
        var matched = globals.cambiens.firstWhere(
            (c) => c.name.toLowerCase() == newestCB.name.toLowerCase());
        final newYMin = matched.daido![0].toDouble();
        final newYMax = matched.daido![1].toDouble();
        if (newYMin != _yMinData || newYMax != _yMaxData) {
          _yMinData = newYMin;
          _yMaxData = newYMax;
          _centerY = (_yMinData + _yMaxData) / 2;
        }
      } catch (e) {
        _yMinData = -1.0;
        _yMaxData = 1.0;
        _centerY = 0.0;
      }
    }
  }

  @override
  void initState() {
    super.initState();

    // listen for add/remove sensor events from parent (these are "toggle sensor" events)
    _cambienSubscription = widget.parent.streamCambien.listen((cambien) {
      // toggle: if exists -> remove, else add with new color
      if (_sensorData.containsKey(cambien.id)) {
        final removedColor = _colors.remove(cambien.id);
        _sensorData.remove(cambien.id);
        _cambienInfo.remove(cambien.id);
        _sensorSelectionOrder.remove(cambien.id);
        if (removedColor != null) globals.listColorCambien.remove(removedColor);

        // notify SodoDothi: color null means delete
        _streamCambienLocal.add(CambienHienthi(
          id: cambien.id,
          name: cambien.name,
          donvi: cambien.donvi,
          color: null,
        ));
      } else {
        final color = _findFirstUnusedColor();
        _sensorData[cambien.id] = [];
        if (globals.historyViewMode.value == true && globals.historySelected != null) {
          if (globals.historySelected['thietbi'] != null &&
              globals.historySelected['thietbi'].containsKey(cambien.id)) {
            List<dynamic> rawData = globals.historySelected['thietbi'][cambien.id]['data'];
            _sensorData[cambien.id]!.addAll(rawData.map((e) => (e as num).toDouble()).toList());
          }
        }

        _cambienInfo[cambien.id] = cambien;
        _colors[cambien.id] = color;
        _sensorSelectionOrder.remove(cambien.id);
        _sensorSelectionOrder.add(cambien.id);
        if (!globals.listColorCambien.contains(color)) {
          globals.listColorCambien.add(color);
        }

        // notify SodoDothi: include color
        _streamCambienLocal.add(CambienHienthi(
          id: cambien.id,
          name: cambien.name,
          donvi: cambien.donvi,
          color: color,
        ));
      }
      _updateYAxisRange();
      // keep center index sane
      _normalizeCenterAfterChange();
      if (debugPrints)
        print(
            'SENSOR TOGGLE: ${cambien.id} sensors=${_sensorData.keys.length}');
      if (mounted) setState(() {});
    });

    // Initialize with selected sensors
    for (var cambien in widget.listDeviceSelected) {
      if (cambien is CambienHienthi) {
        _sensorData[cambien.id] = [];
        _cambienInfo[cambien.id] = cambien;
        final color = cambien.color ?? _findFirstUnusedColor();
        _colors[cambien.id] = color;
        if (!_sensorSelectionOrder.contains(cambien.id)) {
          _sensorSelectionOrder.add(cambien.id);
        }
        if (!globals.listColorCambien.contains(color)) {
          globals.listColorCambien.add(color);
        }
      }
    }
    _updateYAxisRange();

    // listen data stream: only buffer values here
    _dataSubscription = widget.stream.listen((dulieu) {
      try {
        if (dulieu.datLai) {
          if (globals.historyViewMode.value == true) {
            _sensorData.forEach((key, list) {
              list.clear();
              if (globals.historySelected != null &&
                  globals.historySelected['thietbi'] != null &&
                  globals.historySelected['thietbi'].containsKey(key)) {
                List<dynamic> rawData = globals.historySelected['thietbi'][key]['data'];
                list.addAll(rawData.map((e) => (e as num).toDouble()).toList());
              }
            });
            _centerIndex = _getGlobalMaxIndex() / 2;
            _windowSize = max(100.0, _getGlobalMaxIndex());
            _updateYAxisRange();
            if (mounted) setState(() {});
          } else {
            // reset normally
            _sensorData.forEach((_, list) => list.clear());
            _centerIndex = 0;
            if (mounted) setState(() {});
          }
          return;
        }
        _onNewData(dulieu.id, dulieu.giaTri);
      } catch (e, st) {
        if (debugPrints) print('Error in dataSubscription: $e\n$st');
      }
    });
    _phantichSubscription = widget.streamPhantich.listen((kieu) {
      _kieuPhantich = kieu;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final box = context.findRenderObject() as RenderBox?;
        final width = box?.size.width ?? 1000;
        if (!_chartReady) return;
        _updateLimitLines(width);
      });
    });
    _centerIndex = 0;
  }

  @override
  void dispose() {
    _dataSubscription.cancel();
    _cambienSubscription.cancel();
    _streamCambienLocal.close();
    _phantichSubscription.cancel();
    // _repaintTimer?.cancel();
    super.dispose();
  }

// mỗi lần có dữ liệu mới
  void _onNewData(String id, List<double> values) {
    // Chỉ nhận dữ liệu từ các cảm biến đã được thêm vào
    if (!_sensorData.containsKey(id)) return;
    
    final cb = _cambienInfo[id];
    List<double> processedValues = values;
    if (cb != null && cb.heso != null && cb.heso!.isNotEmpty) {
      double a = cb.heso![0];
      double b = cb.heso!.length > 1 ? cb.heso![1] : 0.0;
      processedValues = values.map((v) => v * a + b).toList();
    }
    
    final list = _sensorData[id]!;
    list.addAll(processedValues);
    if (list.length > _maxPoints) {
      list.removeRange(0, list.length - _maxPoints);
    }

    // nếu đang auto-follow → trượt theo dữ liệu
    if (_autoFollow) {
      _centerIndex = _getGlobalMaxIndex() - _windowSize / 2;
      if (_centerIndex < 0) _centerIndex = 0;
    }
    if (mounted) setState(() {});
    

  }

  // ---------------- Gesture ------------------
  Offset? _lastFocal;
  double _lastScale = 1.0;

  void _onScaleStart(ScaleStartDetails d) {
    _lastFocal = d.focalPoint;
    _lastScale = 1.0;
    _autoFollow = false; // khi chạm, tắt auto scroll
  }

  void _onScaleUpdate(ScaleUpdateDetails d, Size size) {
    if (_lastFocal == null) return;
    
    if (_mode == Mode.pan) {
      // Pan ngang
      final dx = d.focalPoint.dx - _lastFocal!.dx;
      final samplesPerPixel = _windowSize / size.width;
      _centerIndex -= dx * samplesPerPixel;
      _centerIndex = _centerIndex.clamp(0.0, _getGlobalMaxIndex());

      // Pan doc
      final dy = d.focalPoint.dy - _lastFocal!.dy;
      double innerH = size.height - 40; // top: 10, bottom: 30
      if (innerH > 0) {
        double zspan = ((_yMaxData - _yMinData) / 2) * _zoomY;
        double dyVal = dy / innerH * (2 * zspan);
        _centerY = (_centerY ?? (_yMinData + _yMaxData) / 2) + dyVal;
      }

      _lastFocal = d.focalPoint;
    } else if (_mode == Mode.zoomX) {
      // Scale ngang lấy tâm focalPoint
      double innerW = size.width - 70; // padding: left 50, right 20
      double v = 0.5;
      if (innerW > 0) {
        v = (d.focalPoint.dx - 50) / innerW;
        v = v.clamp(0.0, 1.0);
      }
      double curCenterIdx = _centerIndex;
      double valAtFocal = curCenterIdx + (v - 0.5) * _windowSize;

      if (d.scale != 1.0) {
        final scaleChange = d.scale / _lastScale;
        // _windowSize tỷ lệ nghịch với scale: scale to -> window nhỏ (zoom in)
        _windowSize = (_windowSize / scaleChange).clamp(100.0, _maxPoints.toDouble());
        _lastScale = d.scale;
      } else {
        // Hỗ trợ drag chuột hoặc 1 ngón để zoom X
        final dx = d.focalPoint.dx - _lastFocal!.dx;
        // Kéo qua phải (dx > 0) -> zoom in (_windowSize giảm)
        // Hệ số 0.03 giúp lướt nhẹ hơn
        final zoomFactor = 1.0 + (dx * 0.03);
        _windowSize = (_windowSize / zoomFactor).clamp(100.0, _maxPoints.toDouble());
        _lastFocal = d.focalPoint;
      }

      _centerIndex = valAtFocal - (v - 0.5) * _windowSize;
      _centerIndex = _centerIndex.clamp(0.0, _getGlobalMaxIndex());
    } else if (_mode == Mode.zoomY) {
      // Scale dọc lấy tâm focalPoint
      double innerH = size.height - 40;
      double u = 0.0;
      if (innerH > 0) {
        u = 1 - 2 * (d.focalPoint.dy - 10) / innerH;
        u = u.clamp(-1.0, 1.0);
      }
      double curCenterY = _centerY ?? (_yMinData + _yMaxData) / 2;
      double zspan = ((_yMaxData - _yMinData) / 2) * _zoomY;
      double valAtFocal = curCenterY + u * zspan;

      if (d.scale != 1.0) {
        final scaleChange = d.scale / _lastScale;
        _zoomY = (_zoomY * scaleChange).clamp(0.01, 10.0);
        _lastScale = d.scale;
      } else {
        // Hỗ trợ drag chuột hoặc 1 ngón để zoom Y
        final dy = d.focalPoint.dy - _lastFocal!.dy;
        // Kéo lên trên (dy < 0) -> zoom in (_zoomY tăng)
        // Hệ số 0.03 giúp nhạy hơn
        final zoomFactor = 1.0 - (dy * 0.03);
        _zoomY = (_zoomY * zoomFactor).clamp(0.01, 10.0);
        _lastFocal = d.focalPoint;
      }

      double zspan_new = ((_yMaxData - _yMinData) / 2) * _zoomY;
      _centerY = valAtFocal - u * zspan_new;
    }

    setState(() {});
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _lastFocal = null;
    _lastScale = 1.0;
  }

// nút reset
  void _resetView() {
    setState(() {
      _autoFollow = true;
      _zoomY = 1.0;
      _windowSize = 1000;
      _centerIndex = _getGlobalMaxIndex() - _windowSize / 2;
      _centerY = (_yMinData + _yMaxData) / 2;
    });
  }

  // helper: find first unused color from globals list
  Color _findFirstUnusedColor() {
    for (final c in globals.listMamau) {
      if (!_colors.containsValue(c)) return c;
    }
    return globals.listMamau[_colors.length % globals.listMamau.length];
  }

  // return max index across sensors (last sample index)
  double _getGlobalMaxIndex() {
    double maxI = 0;
    for (final list in _sensorData.values) {
      if (list.isNotEmpty) {
        maxI = max(maxI, list.length - 1.0);
      }
    }
    return maxI;
  }

  void _normalizeCenterAfterChange() {
    final maxIdx = _getGlobalMaxIndex();
    if (_centerIndex > maxIdx) _centerIndex = maxIdx;
    if (_centerIndex < 0) _centerIndex = 0;
  }

  // UI controls: change mode
  void _setMode(Mode m) {
    setState(() {
      _mode = m;
    });
  }

  // Map: how many samples correspond to one pixel based on windowSize and widget width
  double _samplesPerPixel(double width) {
    if (width <= 0) return 1.0;
    final samplesOnScreen = max(10, _windowSize);
    return samplesOnScreen / width;
  }

  // Helper to compute visible index range
  Range _visibleRange(double width) {
    final samplesOnScreen = max(10, _windowSize);
    final half = samplesOnScreen / 2.0;
    final start = (_centerIndex - half).clamp(0.0, double.infinity);
    final end = (_centerIndex + half).clamp(0.0, double.infinity);

    // ensure within data bounds (simple)
    final globalMax = _getGlobalMaxIndex();
    double s = start;
    double e = end;
    if (e > globalMax) {
      final diff = e - globalMax;
      s = max(0.0, s - diff);
      e = globalMax;
    }
    return Range(s, e);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // control toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: () => _setMode(Mode.pan),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _mode == Mode.pan ? Colors.blue : Colors.grey[300],
                  ),
                  child: const Icon(Icons.open_with, color: Colors.white),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _setMode(Mode.zoomX),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _mode == Mode.zoomX ? Colors.blue : Colors.grey[300],
                  ),
                  child: const Icon(Icons.horizontal_rule, color: Colors.white),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _setMode(Mode.zoomY),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _mode == Mode.zoomY ? Colors.blue : Colors.grey[300],
                  ),
                  child: const Icon(Icons.vertical_align_center,
                      color: Colors.white),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _resetView,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                  ),
                  child: const Icon(Icons.refresh, color: Colors.black),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => setState(() => _autoFollow = !_autoFollow),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _autoFollow ? Colors.green : Colors.grey[300],
                  ),
                  child: Icon(Icons.play_arrow,
                      color: _autoFollow ? Colors.white : Colors.black),
                ),
                const SizedBox(width: 12),
                // optional debug info
                Text('sensors: ${_sensorData.length}',
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),

        // chart area with gestures
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            _chartReady = true;
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  setState(() {
                    _autoFollow = false; // Ngừng chạy theo data mới khi cuộn
                    final delta = event.scrollDelta.dy;
                    if (_mode == Mode.zoomX) {
                      // Cuộn chuột để zoom trục X lấy tâm ngón tay
                      double innerW = size.width - 70;
                      double v = 0.5;
                      if (innerW > 0) {
                        v = (event.localPosition.dx - 50) / innerW;
                        v = v.clamp(0.0, 1.0);
                      }
                      double curCenterIdx = _centerIndex;
                      double valAtFocal = curCenterIdx + (v - 0.5) * _windowSize;

                      // Hệ số 0.003 để cuộn chuột nhạy hơn bản 0.001
                      _windowSize = (_windowSize / (1 + delta * 0.003))
                          .clamp(100, _maxPoints.toDouble());
                          
                      _centerIndex = valAtFocal - (v - 0.5) * _windowSize;
                      _centerIndex = _centerIndex.clamp(0.0, _getGlobalMaxIndex());
                    } else if (_mode == Mode.zoomY) {
                      // Cuộn chuột để zoom trục Y
                      double innerH = size.height - 40;
                      if (innerH > 0) {
                        double u = 1 - 2 * (event.localPosition.dy - 10) / innerH;
                        u = u.clamp(-1.0, 1.0);
                        double curCenterY = _centerY ?? (_yMinData + _yMaxData) / 2;
                        double zspan = ((_yMaxData - _yMinData) / 2) * _zoomY;
                        double valAtFocal = curCenterY + u * zspan;

                        // Hệ số 0.003
                        _zoomY = (_zoomY / (1 + delta * 0.003)).clamp(0.01, 10.0);

                        double zspan_new = ((_yMaxData - _yMinData) / 2) * _zoomY;
                        _centerY = valAtFocal - u * zspan_new;
                      }
                    } else if (_mode == Mode.pan) {
                      // Pan ngang khi đang ở mode pan
                      final samplesPerPixel = _windowSize / size.width;
                      _centerIndex += delta * 10 * samplesPerPixel;
                      _centerIndex =
                          _centerIndex.clamp(0, _getGlobalMaxIndex().toDouble());
                    }
                  });
                }
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _onScaleStart,
                onScaleUpdate: (details) => _onScaleUpdate(details, size),
                onScaleEnd: _onScaleEnd,
                onTapUp: (details) {
                  if (_kieuPhantich == 7) return;
                  _onTapChart(details.localPosition, size);
                },
                child: CustomPaint(
                  size: size,
                  painter: _FastChartPainter(
                    data: _sensorData,
                    colors: _colors,
                    yMinData: _yMinData,
                    yMaxData: _yMaxData,
                    centerY: _centerY ?? (_yMinData + _yMaxData) / 2,
                    visibleRangeProvider: () => _visibleRange(size.width),
                    windowSizeProvider: () => _windowSize,
                    zoomY: _zoomY,
                    samplesPerPixel: _samplesPerPixel(size.width),
                    debugPrints: debugPrints,
                    limitLines: _limitLines,  // 👈 truyền vào đây
                    bestFitLines: _bestFitLines, // 👈 thêm dòng này
                  ),
                ),
              ),
            );
          }),
        ),


        // SodoDothi (list of sensors, receives from our local stream)
        SodoDothi(
          streamCambien: _streamCambienLocal.stream,
          listDeviceSelected: widget.listDeviceSelected,
        ),
      ],
    );
  }
  void _onTapChart(Offset localPos, Size size) {
    final innerW = size.width - _FastChartPainter.leftPadding - _FastChartPainter.rightPadding;
    final visible = _visibleRange(size.width);
    final startIndex = visible.start;
    final endIndex = visible.end;
    final samplesOnScreen = endIndex - startIndex;
    final samplePeriod = globals.tansolaymau / 1000.0;
    final timeStart = startIndex * samplePeriod;
    final timeEnd = endIndex * samplePeriod;
    final timeRange = timeEnd - timeStart;

    // chuyển pixel sang thời gian
    final frac = (localPos.dx - _FastChartPainter.leftPadding) / innerW;
    final timeClicked = timeStart + frac * timeRange;

    // 🔍 tìm điểm dữ liệu gần nhất trong tất cả cảm biến
    double? nearestTime;
    double minDist = double.infinity;
    for (final list in _sensorData.values) {
      for (int i = 0; i < list.length; i++) {
        final t = i * samplePeriod;
        final d = (t - timeClicked).abs();
        if (d < minDist) {
          minDist = d;
          nearestTime = t;
        }
      }
    }

    if (nearestTime == null) return;

    // 🔄 cập nhật line gần nhất
    if (_limitLines.isEmpty) return;
    int nearestIdx = 0;
    double minDelta = (nearestTime - _limitLines[0]).abs();
    for (int i = 1; i < _limitLines.length; i++) {
      final d = (nearestTime - _limitLines[i]).abs();
      if (d < minDelta) {
        nearestIdx = i;
        minDelta = d;
      }
    }

    setState(() {
      _limitLines[nearestIdx] = nearestTime!;
    });

    _calculateAnalysisPoints(); // gọi lại xử lý phân tích
  }

  void _calculateAnalysisPoints() {
    if (_limitLines.isEmpty || _kieuPhantich == null || _kieuPhantich == 7) {
      setState(() {
        _bestFitLines.clear(); // ❌ xoá hết đường best-fit
      });
      return;
    }
    final samplePeriod = globals.tansolaymau / 1000.0;
    Map<String, Map<String, dynamic>> result = {};
    List<_BestFitLine> newBestFits = [];

    for (final entry in _sensorData.entries) {
      final id = entry.key;
      final data = entry.value;
      if (data.isEmpty) continue;

      // chuyển index sang time
      final List<double> times =
      List.generate(data.length, (i) => i * samplePeriod);

      if (_kieuPhantich == 0 && _limitLines.isNotEmpty) {
        // lấy giá trị y tại line đầu tiên
        final t = _limitLines.first;
        final y = _interpolateY(times, data, t);
        result[id] = {'coordinates': [t, y]};
        print('📍 [Calc] Sensor=$id | t=$t s → y=$y');

      } else if (_kieuPhantich == 1 && _limitLines.length == 2) {
        final t0 = _limitLines[0];
        final t1 = _limitLines[1];
        final y0 = _interpolateY(times, data, t0);
        final y1 = _interpolateY(times, data, t1);

        result[id] = {
          'coordinates': [[t0, y0], [t1, y1]],
          'deltaY': (y1 - y0),
        };
      }else if (_kieuPhantich == 2 &&
          _limitLines.length == 2) {
        // --- Phân tích độ dốc ---
        final t0 = _limitLines[0];
        final t1 = _limitLines[1];

        // Lấy tất cả điểm trong khoảng
        final pointsInRange = <List<double>>[];
        for (int i = 0; i < times.length; i++) {
          final t = times[i];
          if (t >= t0 && t <= t1) {
            pointsInRange.add([t, data[i]]);
          }
        }

        if (pointsInRange.length >= 2) {
          final fit = _linearBestFit(pointsInRange); // {slope, intercept, r2}

          final slope = fit['slope'] ?? 0.0;
          final intercept = fit['intercept'] ?? 0.0;
          final yStart = slope * t0 + intercept;
          final yEnd = slope * t1 + intercept;

          result[id] = {
            'coordinates': [
              [t0, yStart],
              [t1, yEnd]
            ],
            'fit': fit,
          };
          newBestFits.add(_BestFitLine(id, t0, yStart, t1, yEnd));

          print('📍 [Phân tích 2] $id: slope=$slope, intercept=$intercept, r2=${fit['r2']}');
        }

      } else if (_kieuPhantich == 3 &&
          _limitLines.length == 2) {
        // --- Phân tích min, max, trung bình ---
        final t0 = _limitLines[0];
        final t1 = _limitLines[1];
        final valuesInRange = <double>[];

        for (int i = 0; i < times.length; i++) {
          final t = times[i];
          if (t >= t0 && t <= t1) {
            valuesInRange.add(data[i]);
          }
        }

        if (valuesInRange.isNotEmpty) {
          final minVal = valuesInRange.reduce(min);
          final maxVal = valuesInRange.reduce(max);
          final avgVal =
              valuesInRange.reduce((a, b) => a + b) / valuesInRange.length;

          result[id] = {
            'coordinates': [minVal, maxVal, avgVal],
          };
          print('📍 [Phân tích 3] $id: min=$minVal, max=$maxVal, avg=$avgVal');
        }

      } else if (_kieuPhantich == 4 &&
          _limitLines.length == 2) {
        // --- Phân tích RMS ---
        final t0 = _limitLines[0];
        final t1 = _limitLines[1];
        final pointsInRange = <double>[];

        for (int i = 0; i < times.length; i++) {
          final t = times[i];
          if (t >= t0 && t <= t1) {
            pointsInRange.add(data[i]);
          }
        }

        if (pointsInRange.length >= 2) {
          double sumSquares = 0.0;
          for (final y in pointsInRange) {
            sumSquares += y * y;
          }

          final rms = sqrt(sumSquares / pointsInRange.length);
          result[id] = {
            'coordinates': [rms],
          };
          print('📍 [Phân tích 4] $id: RMS=$rms');
        }
      }
    }
    // Cập nhật danh sách best-fit lines (nếu có)
    setState(() {
      _bestFitLines = newBestFits;
    });
    widget.streamControllerDiemcat.add(result);
  }
  Map<String, double> _linearBestFit(List<List<double>> points) {
    final n = points.length;
    if (n < 2) return {'slope': 0.0, 'intercept': 0.0, 'r2': 0.0};

    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0, sumY2 = 0;
    for (final p in points) {
      final x = p[0];
      final y = p[1];
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
      sumY2 += y * y;
    }

    final denominator = (n * sumX2 - sumX * sumX);
    if (denominator == 0) {
      return {'slope': 0.0, 'intercept': sumY / n, 'r2': 0.0};
    }

    final slope = (n * sumXY - sumX * sumY) / denominator;
    final intercept = (sumY - slope * sumX) / n;

    // Hệ số tương quan R²
    final ssTot = sumY2 - (sumY * sumY) / n;
    final ssRes = ssTot -
        slope * (sumXY - (sumX * sumY) / n);
    final r2 = ssTot == 0 ? 1.0 : 1 - (ssRes / ssTot);

    return {
      'slope': slope,
      'intercept': intercept,
      'r2': r2,
    };
  }

  double _interpolateY(List<double> times, List<double> values, double t) {
    for (int i = 0; i < times.length - 1; i++) {
      if (t >= times[i] && t <= times[i + 1]) {
        final ratio = (t - times[i]) / (times[i + 1] - times[i]);
        return values[i] + (values[i + 1] - values[i]) * ratio;
      }
    }
    return values.last;
  }
  void _updateLimitLines(double width) {
    final visible = _visibleRange(width);
    final startIndex = visible.start;
    final endIndex = visible.end;

    final samplePeriod = globals.tansolaymau / 1000.0; // giây/mẫu
    final startTime = startIndex * samplePeriod;
    final endTime = endIndex * samplePeriod;

    final mid = (startTime + endTime) / 2;
    final quarter = startTime + (endTime - startTime) / 4;
    final threeQuarter = startTime + 3 * (endTime - startTime) / 4;

    // print('🔹 [updateLimitLines] startTime=$startTime endTime=$endTime kieu=$_kieuPhantich');

    setState(() {
      if (_kieuPhantich == 0) {
        _limitLines = [mid];
        _bestFitLines.clear();
      } else if (_kieuPhantich >= 1 && _kieuPhantich <= 4) {
        _limitLines = [quarter, threeQuarter];
        if (_kieuPhantich != 2) {
          _bestFitLines.clear(); // 🧹 xoá khi tắt hoặc đổi kiểu khác
          // print('xoa bestfitline');
        }
      } else {
        _limitLines.clear();
        _bestFitLines.clear();
      }
      // print('🔸 [updateLimitLines] limitLines (s) = $_limitLines');
    });
  }
}

enum Mode { pan, zoomX, zoomY }

class Range {
  final double start;
  final double end;

  Range(this.start, this.end);
}

class _BestFitLine {
  final String id;
  final double x0, y0, x1, y1;
  _BestFitLine(this.id, this.x0, this.y0, this.x1, this.y1);
}
/// Painter optimized for large number of points:
/// - Decimation: if there are more source samples than horizontal pixels,
///   we compute min/max per pixel bin and render as vertical spans (fast).
/// - Otherwise draw direct polyline.
/// - Draw gridlines and axis labels.
class _FastChartPainter extends CustomPainter {
  final Map<String, List<double>> data;
  final Map<String, Color> colors;
  final double yMinData;
  final double yMaxData;
  final double centerY;
  final Range Function() visibleRangeProvider;
  final double Function() windowSizeProvider;
  final double zoomY;
  final double samplesPerPixel;
  final bool debugPrints;
  final List<double> limitLines;
  final List<_BestFitLine> bestFitLines;


  _FastChartPainter({
    required this.data,
    required this.colors,
    required this.yMinData,
    required this.yMaxData,
    required this.centerY,
    required this.visibleRangeProvider,
    required this.windowSizeProvider,
    required this.zoomY,
    required this.samplesPerPixel,
    this.debugPrints = false,
    required this.limitLines,
    required this.bestFitLines,
  });

  static const double leftPadding = 50;
  static const double bottomPadding = 30;
  static const double topPadding = 10;
  static const double rightPadding = 20;

  @override
  void paint(Canvas canvas, Size size) {
    // background
    final rect = Offset.zero & size;
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(rect, bgPaint);

    final innerW = size.width - leftPadding - rightPadding;
    final innerH = size.height - topPadding - bottomPadding;
    if (innerW <= 10 || innerH <= 10) return;

    // grid paints
    final majorGrid = Paint()
      ..color = Colors.grey.withOpacity(0.25)
      ..strokeWidth = 0.6;
    final minorGrid = Paint()
      ..color = Colors.grey.withOpacity(0.12)
      ..strokeWidth = 0.4;
    final axisPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0;

    // draw grid and labels: choose ticks count
    const int vTicks = 10;
    const int hTicks = 10;

    // Y axis ticks
    final cy = centerY;
    final zspan = ((yMaxData - yMinData) / 2) * zoomY;

    for (int i = 0; i <= vTicks; i++) {
      final y = topPadding + innerH * i / vTicks;
      final paint = (i % 1 == 0) ? majorGrid : minorGrid;
      canvas.drawLine(
          Offset(leftPadding, y), Offset(size.width - rightPadding, y), paint);
      // label: compute value from top to bottom
      final double t = 1.0 - (i / vTicks);
      final double val = cy + (t * 2 - 1) * zspan;
      final labelVal = val.toStringAsFixed(2);
      final tp = TextPainter(
          text: TextSpan(
              text: labelVal,
              style: TextStyle(color: Colors.black87, fontSize: 10)),
          textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(6, y - tp.height / 2));
    }

    // --- thời gian / tần số mẫu ---
    double samplePeriod = globals.tansolaymau / 1000.0; // seconds per sample
    if (samplePeriod <= 0) samplePeriod = 0.001;
    final sampleRate = 1.0 / samplePeriod; // Hz

// visible range (vẫn là chỉ số mẫu)
    final visible = visibleRangeProvider();
    final startIndex = visible.start;
    final endIndex = visible.end;
    final samplesOnScreen = endIndex - startIndex;

// chuyển index -> thời gian (giây)
    final timeStart = startIndex * samplePeriod; // s
    final timeEnd = endIndex * samplePeriod; // s
    final timeRange = timeEnd - timeStart;

    // --- Chia tick trục X theo tần số lấy mẫu thực ---
// chọn "stepTime" đẹp dựa theo sampleRate (Hz)
    double _niceTimeStep(double rate) {
      if (rate <= 1.0) return 1.0;    // 1Hz → tick mỗi 1s
      if (rate <= 2.0) return 0.5;    // 2Hz → 0.5s
      if (rate <= 5.0) return 0.2;
      if (rate <= 10.0) return 0.1;
      if (rate <= 20.0) return 0.05;
      if (rate <= 50.0) return 0.02;
      if (rate <= 100.0) return 0.01;
      return 0.005;
    }

    final nice = _niceTimeStep(sampleRate);
    final stepTime = max(nice, samplePeriod); // không nhỏ hơn 1 mẫu

// xác định phạm vi thời gian đang hiển thị
    final firstTick = (timeStart / stepTime).floor() * stepTime;
    final lastTick = (timeEnd / stepTime).ceil() * stepTime;

// số chữ số sau dấu phẩy
    int thapphan;
    if (stepTime < 0.001) {
      thapphan = 4;
    } else if (stepTime < 0.01) {
      thapphan = 3;
    } else if (stepTime < 0.1) {
      thapphan = 2;
    } else {
      thapphan = 1;
    }

// --- Vẽ tick và nhãn trục X gọn gàng ---
    final maxLabels = 10; // tối đa 10 nhãn hiển thị
    int tickIndex = 0;
    for (double t = firstTick; t <= lastTick + 1e-9; t += stepTime, tickIndex++) {
      if (t < timeStart - 1e-9 || t > timeEnd + 1e-9) continue;

      final frac = (t - timeStart) / (timeRange == 0 ? 1 : timeRange);
      final x = leftPadding + innerW * frac;

      // Vẽ lưới đứng
      canvas.drawLine(Offset(x, topPadding), Offset(x, topPadding + innerH), majorGrid);

      // Chỉ hiển thị 1 phần nhãn (tuỳ số tick)
      final totalTicks = ((lastTick - firstTick) / stepTime).ceil().clamp(1, 999);
      final showEvery = (totalTicks / maxLabels).ceil().clamp(1, 999);

      if (tickIndex % showEvery == 0 || tickIndex == totalTicks) {
        final label = t.toStringAsFixed(thapphan);
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(color: Colors.black87, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, Offset(x - tp.width / 2, topPadding + innerH + 4));
      }
    }


    canvas.drawLine(Offset(leftPadding, topPadding),
        Offset(leftPadding, topPadding + innerH), axisPaint);
    canvas.drawLine(Offset(leftPadding, topPadding + innerH),
        Offset(size.width - rightPadding, topPadding + innerH), axisPaint);

    // Xén vùng vẽ đồ thị để các điểm nằm ngoài mép bị ẩn đi thay vì dồn thành đường
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(
        leftPadding, topPadding, size.width - rightPadding, topPadding + innerH));

    // for each series draw decimated path
    final visibleStart = max(0, startIndex.floor());
    final visibleEnd = min(_maxDataLength(), endIndex.ceil());

    if (visibleStart >= visibleEnd) {
      // No data
      final tp = TextPainter(
          text: TextSpan(
              text: '',
              style: TextStyle(color: Colors.black54, fontSize: 14)),
          textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(leftPadding + 20, topPadding + 10));
      canvas.restore(); // Sửa lỗi thiếu restore khi return sớm
      return;
    }

    final double pixels = innerW;
    final int maxBins = pixels.ceil();

    // For each series:
    int seriesIdx = 0;
    for (final entry in data.entries) {
      final id = entry.key;
      final list = entry.value;
      if (list.isEmpty) continue;
      final color = colors[id] ?? Colors.blue;
      final paintLine = Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke;
      final paintFill = Paint()..color = color.withOpacity(0.15);

      // Decide whether to decimate: if samples > pixels*2 then decimate
      final visibleList = <double>[];
      final s = visibleStart;
      final e = visibleEnd;
      if (e - s <= 0) continue;
      final samples = e - s;
      final binSize = max(1, (samples / maxBins).ceil());

      if (binSize <= 1) {
        // direct polyline
        final path = Path();
        for (int i = s; i < e; i++) {
          final xi = i - startIndex; // position within visible window
          final x = leftPadding + (xi / samplesOnScreen) * innerW;
          final yVal = list[i.clamp(0, list.length - 1)];
          final y = mapY(
              yVal, innerH);
          if (i == s)
            path.moveTo(x, y);
          else
            path.lineTo(x, y);
        }
        canvas.drawPath(path, paintLine);

        // markers: show every Nth point to avoid too many circles
        final markerStep =
            (samples / 400).ceil().clamp(1, 50); // max ~400 markers
        final markerPaint = Paint()..color = color;
        for (int i = s; i < e; i += markerStep) {
          final xi = i - startIndex;
          final x = leftPadding + (xi / samplesOnScreen) * innerW;
          final yVal = list[i.clamp(0, list.length - 1)];
          final y =
              mapY(yVal, innerH);
          canvas.drawCircle(Offset(x, y), 2.0, markerPaint);
        }
      } else {
        // decimation using min/max per bin
        final path = Path();
        int binIndex = 0;
        for (int binStart = s; binStart < e; binStart += binSize, binIndex++) {
          final binEnd = min(binStart + binSize, e);
          double minV = double.infinity, maxV = -double.infinity;
          for (int j = binStart; j < binEnd; j++) {
            final val = list[j.clamp(0, list.length - 1)];
            if (val < minV) minV = val;
            if (val > maxV) maxV = val;
          }
          final xi = (binStart - startIndex) + binSize / 2.0;
          final x = leftPadding + (xi / samplesOnScreen) * innerW;
          final yMin =
              mapY(minV, innerH);
          final yMax =
              mapY(maxV, innerH);

          // draw vertical line representing min..max in that pixel bin
      }
    }

    // Kết thúc phần xén vùng vẽ đồ thị
    canvas.restore();

    // legend label (right side)
    final tp = TextPainter(
        text: TextSpan(
            text: id.split(',').length > 1
                ? id.split(',').sublist(1).join(',')
                : id,
            style: TextStyle(color: color, fontSize: 12)),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(
          canvas,
          Offset(size.width - rightPadding - tp.width - 6,
              topPadding + 12.0 * seriesIdx));
      seriesIdx++;
    }
    // small axis labels
    final xlabel = 'Thời gian';
    final ylabel = '';
    final tpX = TextPainter(
        text: TextSpan(
            text: xlabel,
            style: TextStyle(color: Colors.black87, fontSize: 12)),
        textDirection: TextDirection.ltr);
    tpX.layout();
    tpX.paint(
        canvas,
        Offset(leftPadding + innerW / 2 - tpX.width / 2,
            topPadding + innerH + 18));
    final tpY = TextPainter(
        text: TextSpan(
            text: ylabel,
            style: TextStyle(color: Colors.black87, fontSize: 12)),
        textDirection: TextDirection.ltr);
    tpY.layout();

    // rotate y label
    canvas.save();
    canvas.translate(12, topPadding + innerH / 2 + tpY.width / 2);
    canvas.rotate(-pi / 2);
    tpY.paint(canvas, Offset(0, 0));
    canvas.restore(); // ✅ phục hồi hệ trục trước khi vẽ limit line

    // --- Vẽ các limit line (đường thẳng song song trục Oy) ---
    if (limitLines.isNotEmpty) {
      final limitPaint = Paint()
        ..color = Colors.redAccent
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      // print('🟥 [Painter] Vẽ limitLines: $limitLines | timeStart=$timeStart timeEnd=$timeEnd');

      for (final t in limitLines) {
        final frac = (t - timeStart) / (timeEnd - timeStart);
        if (frac < 0 || frac > 1) {
          // print('⚠️ [Painter] Bỏ qua t=$t (ngoài vùng nhìn thấy)');
          continue;
        }

        final x = leftPadding + innerW * frac;
        canvas.drawLine(
          Offset(x, topPadding),
          Offset(x, topPadding + innerH),
          limitPaint,
        );
        // print('✅ [Painter] Đã vẽ line tại x=$x (t=$t)');
      }
    }
    // --- Vẽ các best-fit lines ---
    if (bestFitLines.isNotEmpty) {
      for (final bf in bestFitLines) {
        final color = colors[bf.id] ?? Colors.black;
        final frac0 = (bf.x0 - timeStart) / (timeEnd - timeStart);
        final frac1 = (bf.x1 - timeStart) / (timeEnd - timeStart);
        if (frac0 > 1 || frac1 < 0) continue;

        final x0 = leftPadding + innerW * frac0;
        final x1 = leftPadding + innerW * frac1;
        final y0 = mapY(bf.y0, innerH);
        final y1 = mapY(bf.y1, innerH);

        // Vẽ nét đứt bằng cách chia đoạn
        _drawDashedLine(
          canvas,
          Offset(x0, y0),
          Offset(x1, y1),
          color,
          dashWidth: 8,
          dashSpace: 4,
        );
      }
    }

  }
  void _drawDashedLine(
      Canvas canvas,
      Offset p1,
      Offset p2,
      Color color, {
        double dashWidth = 6,
        double dashSpace = 3,
        double strokeWidth = 1.8,
      }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final totalLength = (p2 - p1).distance;
    final direction = (p2 - p1) / totalLength;
    double distance = 0.0;

    while (distance < totalLength) {
      final start = p1 + direction * distance;
      distance += dashWidth;
      final end = p1 + direction * distance.clamp(0, totalLength);
      canvas.drawLine(start, end, paint);
      distance += dashSpace;
    }
  }

// Xoá clamp để cho điểm ra ngoài thì bị clipRect ẩn đi thay vì ép vào mép
  double mapY(double value, double innerH) {
    final cy = centerY;
    final zspan = ((yMaxData - yMinData) / 2) * zoomY;
    final u = (value - cy) / (zspan == 0 ? 1 : zspan);
    final y = topPadding + (1 - (u + 1) / 2) * innerH;
    return y;
  }

  int _maxDataLength() {
    int maxL = 0;
    for (final l in data.values) {
      if (l.length > maxL) maxL = l.length;
    }
    return maxL;
  }

  @override
  bool shouldRepaint(covariant _FastChartPainter oldDelegate) {
    // repaint when data reference changed or viewport changed
    return true;
  }
}
