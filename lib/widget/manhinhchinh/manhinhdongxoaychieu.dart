import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../Model/cambienhienthi.dart';
import '../../Model/dulieucambien.dart';
import '../../ultis/listcambien.dart' as globals;
import '../popup/popupchonsodo.dart';
import 'package:fftea/fftea.dart';

class Manhinhdongxoaychieu extends StatefulWidget {
  const Manhinhdongxoaychieu({super.key, required this.streamReadData});

  final Stream<DulieuCB> streamReadData;

  @override
  State<Manhinhdongxoaychieu> createState() => _ManhinhdongxoaychieuState();
}

class _ManhinhdongxoaychieuState extends State<Manhinhdongxoaychieu> {
  late StreamController<CambienHienthi> streamAddSensor =
      StreamController<CambienHienthi>();
  late StreamSubscription<DulieuCB> _subscription;

  List<dynamic> listDeviceSelected = [];
  CambienHienthi? cbienKenh1;
  CambienHienthi? cbienKenh2;
  List<ChartData> dataKenh1 = [];
  List<ChartData> dataKenh2 = [];
  int _kenhIndex = 0;
  double kenh1YMax = 5.0;
  double kenh2YMax = 5.0;
  List<double> bufferKenh1 = [];
  List<double> bufferKenh2 = [];
  bool kenh1Ready = false;
  bool kenh2Ready = false;
  Map<String, double> paraKenh1 = {
    'min': 0.0,
    'max': 0.0,
    'rms': 0.0,
    'freq': 0.0,
  };
  Map<String, double> paraKenh2 = {
    'min': 0.0,
    'max': 0.0,
    'rms': 0.0,
    'freq': 0.0,
  };
  final Map<String, List<double>> maxValues = {
    'Điện áp': [0.5, 24.0],
    'Dòng điện': [0.1, 2.0],
    'Âm thanh': [1.0, 10.0],
  };
  final int maxBufferAmthanh = 512; // Số mẫu tối đa cho âm thanh
  final int maxBufferKhac = 200; // Số mẫu tối đa cho các cảm biến khác
  final int numSamplesAmthanh = 256; // Số mẫu hiển thị trên đồ thị
  final int numSamplesKhac = 200; // Số mẫu hiển thị trên đồ thị
  final double sampleRateAmthanh=0.0001; // Tần số lấy mẫu cho âm thanh (10000Hz)
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 900;
        return Row(
          children: [
            _buildBieuDo(isMobile),
            _buildBangDieuKhien(isMobile, constraints.maxWidth),
          ],
        );
      },
    );
  }

  Widget _buildBieuDo(bool isMobile) {
    return Expanded(
      flex: isMobile ? 3 : 4,
      child: Container(
        color: Colors.black12,
        child: LineChart(
          parent: this,
          cbienKenh1: cbienKenh1,
          cbienKenh2: cbienKenh2,
          dataKenh1: dataKenh1,
          dataKenh2: dataKenh2,
          kenh1YMax: kenh1YMax,
          kenh2YMax: kenh2YMax,
        ),
      ),
    );
  }

  Widget _buildBangDieuKhien(bool isMobile, double maxWidth) {
    Widget bangDieuKhien = BangDieuKhien(
      parent: this,
      cbienKenh1: cbienKenh1,
      cbienKenh2: cbienKenh2,
      kenh1YMax: kenh1YMax,
      kenh2YMax: kenh2YMax,
      initialKenh1: paraKenh1,
      initialKenh2: paraKenh2,
      onValueChanged: (val) {
        setState(() {
          kenh1YMax = val['kenh1YMax'] ?? kenh1YMax;
          kenh2YMax = val['kenh2YMax'] ?? kenh2YMax;
        });
      },
    );

    if (isMobile) {
      // Trên điện thoại, cố định chiều rộng hoặc chia flex phù hợp để không bị nén quá mức
      double panelWidth = maxWidth * 0.45;
      if (panelWidth < 280) panelWidth = 280; // Đặt kích thước tối thiểu để không bị lỗi overflow
      return Container(
        width: panelWidth,
        child: bangDieuKhien,
      );
    } else {
      return Expanded(
        flex: 1,
        child: bangDieuKhien,
      );
    }
  }

  @override
  void initState() {

    _subscription= widget.streamReadData.listen((DulieuCB dulieu) {
      // print(dulieu.toString());
      // Không dùng chung setState cho cả 2 kênh để tránh ghi đè lẫn nhau

      // Kênh 1
      if (cbienKenh1 != null && dulieu.tenCambien == cbienKenh1!.name) {
        bufferKenh1.addAll(dulieu.giaTri);
        if (dulieu.tenCambien == "Âm thanh" && bufferKenh1.length >= maxBufferAmthanh) {
          final slice =
              bufferKenh1.sublist(0, numSamplesAmthanh); // chỉ lấy 400 mẫu để hiển thị

          final minValue = slice.reduce(min);
          final maxValue = slice.reduce(max);
          final rms = sqrt(
              slice.map((x) => x * x).reduce((a, b) => a + b) / slice.length);
          final freq = tinhTansoAmThanhFFT(slice, 1/sampleRateAmthanh); // 10000Hz

          setState(() {
            dataKenh1 = List.generate(
              numSamplesAmthanh,
              (i) => ChartData(i * sampleRateAmthanh, slice[i]),
            );
            paraKenh1['min'] = minValue;
            paraKenh1['max'] = maxValue;
            paraKenh1['rms'] = rms;
            paraKenh1['freq'] = freq;
          });

          bufferKenh1.clear(); // hoặc giữ lại phần dư nếu cần
        } else if (bufferKenh1.length >= maxBufferKhac) {
          final slice = bufferKenh1.sublist(0, numSamplesKhac);
          // bufferKenh1 = bufferKenh1.sublist(200); // giữ phần dư nếu có
          final minValue = slice.reduce(min);
          final maxValue = slice.reduce(max);
          final rms = sqrt(
              slice.map((x) => x * x).reduce((a, b) => a + b) / slice.length);
          final freq = tinhTanso(slice, globals.tansolaymau / 1000.0);
          setState(() {
            dataKenh1 = List.generate(
              numSamplesKhac,
              (i) => ChartData(i * globals.tansolaymau / 1000.0, slice[i]),
            );
            paraKenh1['min'] = minValue;
            paraKenh1['max'] = maxValue;
            paraKenh1['rms'] = rms;
            paraKenh1['freq'] = freq;
          });
          bufferKenh1.clear();
        }
      }

      // Kênh 2
      if (cbienKenh2 != null && dulieu.tenCambien == cbienKenh2!.name) {
        bufferKenh2.addAll(dulieu.giaTri);
        if (dulieu.tenCambien == "Âm thanh" && bufferKenh2.length >= maxBufferAmthanh) {
          final slice =
              bufferKenh2.sublist(0, numSamplesAmthanh); // chỉ lấy 400 mẫu để hiển thị

          final minValue = slice.reduce(min);
          final maxValue = slice.reduce(max);
          final rms = sqrt(
              slice.map((x) => x * x).reduce((a, b) => a + b) / slice.length);
          final freq = tinhTanso(slice, sampleRateAmthanh); // 10000Hz

          setState(() {
            dataKenh2 = List.generate(
              numSamplesAmthanh,
              (i) => ChartData(i * sampleRateAmthanh, slice[i]),
            );
            paraKenh2['min'] = minValue;
            paraKenh2['max'] = maxValue;
            paraKenh2['rms'] = rms;
            paraKenh2['freq'] = freq;
          });

          bufferKenh2.clear(); // hoặc giữ lại phần dư nếu cần
        } else if (bufferKenh2.length >= maxBufferKhac) {
          final slice = bufferKenh2.sublist(0, numSamplesKhac);
          // bufferKenh2 = bufferKenh2.sublist(200);
          final minValue = slice.reduce(min);
          final maxValue = slice.reduce(max);
          final rms = sqrt(
              slice.map((x) => x * x).reduce((a, b) => a + b) / slice.length);
          final freq = tinhTanso(slice, globals.tansolaymau / 1000.0);

          setState(() {
            dataKenh2 = List.generate(
              numSamplesKhac,
              (i) => ChartData(i * globals.tansolaymau / 1000.0, slice[i]),
            );
            paraKenh2['min'] = minValue;
            paraKenh2['max'] = maxValue;
            paraKenh2['rms'] = rms;
            paraKenh2['freq'] = freq;
          });
          bufferKenh2.clear();
        }
      }
    });
    streamAddSensor.stream.listen((CambienHienthi sensor) {
      setState(() {
        if (_kenhIndex == 1) {
          // cbienKenh1 = sensor;
          if (cbienKenh1 != null && cbienKenh1!.id == sensor.id) {
            cbienKenh1 = null; // Ấn lại thì xóa chọn
            dataKenh1.clear(); // Xóa dữ liệu đồ thị kênh 1 khi bỏ chọn
          } else {
            cbienKenh1 = sensor;
            dataKenh1.clear(); // Xóa dữ liệu cũ khi đổi cảm biến
          }
        } else if (_kenhIndex == 2) {
          // cbienKenh2 = sensor; // Chọn cảm biến cho kênh 2
          if (cbienKenh2 != null && cbienKenh2!.id == sensor.id) {
            cbienKenh2 = null;
            dataKenh2.clear();
          } else {
            cbienKenh2 = sensor;
            dataKenh2.clear();
          }
        }
        // print("Chọn cảm biến: ${sensor.name} cho kênh $_kenhIndex");
        // print("Cảm biến kênh 1: ${cbienKenh1?.name}, Cảm biến kênh 2: ${cbienKenh2?.name}");
      });
    });
  }

  @override
  void dispose() {
    streamAddSensor.close();
    _subscription.cancel();
    super.dispose();
  }

  double getYMax(String cbien) {
    return maxValues[cbien]?[1] ?? 20.0;
  }

  double getMin(String cbien) {
    return maxValues[cbien]?[0] ?? 20.0;
  }

  double tinhTanso(List<double> data, double tansoLayMau) {
    if (data.length < 2) return 0.0;

    // 1. Loại bỏ offset (DC bias)
    double offset = data.reduce((a, b) => a + b) / data.length;
    List<double> dataNoOffset = data.map((e) => e - offset).toList();

    // 2. Đếm số lần zero-crossing
    int zeroCrossings = 0;
    for (int i = 1; i < dataNoOffset.length; i++) {
      if ((dataNoOffset[i - 1] < 0 && dataNoOffset[i] >= 0) ||
          (dataNoOffset[i - 1] > 0 && dataNoOffset[i] <= 0)) {
        zeroCrossings++;
      }
    }

    // 3. Tính thời gian tổng và tần số
    double totalTime = data.length * tansoLayMau;

    // 4. Mỗi chu kỳ cắt trục 2 lần => số chu kỳ = zeroCrossings / 2
    double freq = (zeroCrossings / 2) / totalTime;

    return freq;
  }
  double tinhTansoAmThanhFFT(List<double> data, double sampleRate,{int fftSize = 8192}) {
    final int n = data.length;

    // Loại bỏ DC offset
    final mean = data.reduce((a, b) => a + b) / n;
    final List<double> centeredData = data.map((x) => x - mean).toList();

    // Zero-padding lên fftSize mẫu
    List<double> paddedData;
    if (centeredData.length < fftSize) {
      paddedData = List<double>.from(centeredData)
        ..addAll(List.filled(fftSize - centeredData.length, 0.0));
    } else {
      paddedData = centeredData.sublist(0, fftSize); // Nếu dài quá thì cắt bớt
    }

    // Tính FFT
    final fft = FFT(fftSize);
    final freq = fft.realFft(paddedData);

    // Chỉ lấy n/2 tần số đầu, bỏ phần dư thừa/phức hợp
    final magnitudes = freq.discardConjugates().magnitudes();

    // Tìm chỉ số biên độ lớn nhất (bỏ DC, index 0)
    int maxIndex = 1;
    double maxValue = magnitudes[1];
    for (int i = 2; i < magnitudes.length; i++) {
      if (magnitudes[i] > maxValue) {
        maxIndex = i;
        maxValue = magnitudes[i];
      }
    }

    // Tần số tương ứng với index đó
    final double frequency = fft.frequency(maxIndex, sampleRate);
    return frequency;
  }

}

class LineChart extends StatefulWidget {
  const LineChart({
    super.key,
    required this.parent,
    required this.cbienKenh1,
    required this.cbienKenh2,
    required this.dataKenh1,
    required this.dataKenh2,
    required this.kenh1YMax,
    required this.kenh2YMax,
  });

  final _ManhinhdongxoaychieuState parent;
  final CambienHienthi? cbienKenh1;
  final CambienHienthi? cbienKenh2;
  final List<ChartData> dataKenh1;
  final List<ChartData> dataKenh2;
  final double kenh1YMax;
  final double kenh2YMax;

  @override
  State<LineChart> createState() => _LineChartState();
}

class _LineChartState extends State<LineChart> {
  @override
  Widget build(BuildContext context) {
    return _buildChart();
  }

  Widget _buildChart() {
    final List<LineSeries<ChartData, double>> seriesList = [];

    // Kênh 1: màu đỏ, trục trái
    if (widget.cbienKenh1 != null) {
      seriesList.add(
        LineSeries<ChartData, double>(
          name: widget.cbienKenh1!.name,
          color: Colors.red,
          dataSource: widget.dataKenh1,
          xValueMapper: (ChartData data, _) => data.time,
          yValueMapper: (ChartData data, _) => data.value,
          yAxisName: 'Kenh1',
          animationDuration: 0, // <- Tắt animation
        ),
      );
    }

    // Kênh 2: màu xanh, trục phải
    if (widget.cbienKenh2 != null) {
      seriesList.add(
        LineSeries<ChartData, double>(
          name: widget.cbienKenh2!.name,
          color: Colors.blue,
          dataSource: widget.dataKenh2,
          xValueMapper: (ChartData data, _) => data.time,
          yValueMapper: (ChartData data, _) => data.value,
          yAxisName: 'Kenh2',
          animationDuration: 0, // <- Tắt animation
        ),
      );
    }
    double? xmax = 10.0;

    if (widget.dataKenh1.isNotEmpty || widget.dataKenh2.isNotEmpty) {
      if (widget.cbienKenh1?.name == "Âm thanh" || widget.cbienKenh2?.name == "Âm thanh") {
        xmax = widget.parent.numSamplesAmthanh * 0.0001; // Vì âm thanh lấy mẫu 10000Hz và có 512 mẫu
      } else {
        final double lastX1 = widget.dataKenh1.isNotEmpty ? widget.dataKenh1.last.time : 0;
        final double lastX2 = widget.dataKenh2.isNotEmpty ? widget.dataKenh2.last.time : 0;
        xmax = (lastX1 > lastX2 ? lastX1 : lastX2) + globals.tansolaymau / 1000.0;
      }
    }
    return Container(
      color: Colors.white, // Nền toàn bộ là trắng
      padding: const EdgeInsets.all(8),
      child: SfCartesianChart(
        legend: Legend(isVisible: true),
        backgroundColor: Colors.white,
        plotAreaBackgroundColor: Colors.white,
        plotAreaBorderColor: Colors.grey.shade300,
        plotAreaBorderWidth: 1,
        zoomPanBehavior: ZoomPanBehavior(
          enablePanning: true,
          enablePinching: true,
          enableMouseWheelZooming: true,
          enableDoubleTapZooming: false,
          enableSelectionZooming: false,
          zoomMode: ZoomMode.xy,
        ),
        primaryXAxis: NumericAxis(
          name: 'Time',
          minimum: 0,
          maximum: xmax,
          labelPosition: ChartDataLabelPosition.outside,
          axisLine: const AxisLine(width: 1),
          majorGridLines: MajorGridLines(
            width: 0.5,
            color: Colors.grey.shade300, // Grid mờ
            dashArray: [4, 4],
          ),
          axisLabelFormatter: (AxisLabelRenderDetails details) {
            final num value = details.value;
            return ChartAxisLabel(
              '${value.toStringAsFixed(2)}', // đơn vị giây
              const TextStyle(fontSize: 12),
            );
          },
        ),
        primaryYAxis: widget.cbienKenh1 != null
            ? NumericAxis(
                name: 'Kenh1',
                opposedPosition: false,
                minimum: -widget.kenh1YMax,
                maximum: widget.kenh1YMax,
                title: AxisTitle(text: widget.cbienKenh1!.name),
                axisLine: const AxisLine(width: 1),
              )
            : NumericAxis(
                opposedPosition: false,
                minimum: 0,
                maximum: 10,
                axisLine: const AxisLine(width: 1),
                title: AxisTitle(text: 'Không có cảm biến'),
              ),
        axes: [
          if (widget.cbienKenh2 != null)
            NumericAxis(
              name: 'Kenh2',
              opposedPosition: true,
              // trục phải
              minimum: -widget.kenh2YMax,
              maximum: widget.kenh2YMax,
              title: AxisTitle(text: widget.cbienKenh2!.name),
              axisLine: const AxisLine(width: 1),
            ),
        ],
        series: seriesList,
      ),
    );
  }
}

class BangDieuKhien extends StatefulWidget {
  const BangDieuKhien({
    super.key,
    required this.parent,
    required this.cbienKenh1,
    required this.cbienKenh2,
    required this.kenh1YMax,
    required this.kenh2YMax,
    required this.onValueChanged,
    required this.initialKenh1,
    required this.initialKenh2,
  });

  final _ManhinhdongxoaychieuState parent;
  final CambienHienthi? cbienKenh1;
  final CambienHienthi? cbienKenh2;
  final double kenh1YMax;
  final double kenh2YMax;
  final ValueChanged<Map<String, double>> onValueChanged;
  final Map<String, double> initialKenh1;
  final Map<String, double> initialKenh2;

  @override
  State<BangDieuKhien> createState() => _BangDieuKhienState();
}

class _BangDieuKhienState extends State<BangDieuKhien> {
  OverlayEntry? _overlayEntry;
  late double _currentKenh1YMax;
  late double _currentKenh2YMax;

  @override
  void initState() {
    super.initState();
    _currentKenh1YMax = widget.kenh1YMax;
    _currentKenh2YMax = widget.kenh2YMax;
  }

  void _showPopup(int kenhIndex) {
    widget.parent._kenhIndex = kenhIndex;
    if (_overlayEntry == null) {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
    }
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        bool isMobile = MediaQuery.of(context).size.width < 900;
        return GestureDetector(
          onTap: _hidePopup,
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isMobile
                        ? MediaQuery.of(context).size.width * 0.6
                        : MediaQuery.of(context).size.width * 0.3,
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
        );
      },
    );
  }

  void _hidePopup() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _onChoncambien(CambienHienthi a) {
    setState(() {
      if (widget.parent._kenhIndex == 1) {
        _currentKenh1YMax = widget.parent.getYMax(a.name);
      } else {
        _currentKenh2YMax = widget.parent.getYMax(a.name);
      }
    });
    widget.parent.streamAddSensor.add(a);
    widget.onValueChanged({
      'kenh1YMax': _currentKenh1YMax,
      'kenh2YMax': _currentKenh2YMax,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical, // Cuộn dọc để chống overflow theo chiều cao trên điện thoại
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal, // Hỗ trợ cuộn ngang nếu màn hình quá hẹp
          child: Container(
            width: 320, // 👈 đủ chứa 2 kênh mà không overflow
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thông số 2 kênh',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 16),
                _buildKenhThongso(
                  context,
                  kenh: 'Kênh 1',
                  cbienSelected: widget.cbienKenh1,
                  kenhColor: Colors.red,
                  min: widget.initialKenh1['min']?.toStringAsFixed(2) ?? '0.00',
                  max: widget.initialKenh1['max']?.toStringAsFixed(2) ?? '0.00',
                  rms: widget.initialKenh1['rms']?.toStringAsFixed(2) ?? '0.00',
                  freq: widget.initialKenh1['freq']?.toStringAsFixed(2) ?? '0.00',
                  yMaxValue: _currentKenh1YMax,
                  onYMaxChanged: (val) {
                    setState(() {
                      _currentKenh1YMax = val;
                    });
                    widget.onValueChanged({
                      'kenh1YMax': _currentKenh1YMax,
                      'kenh2YMax': _currentKenh2YMax,
                    });
                  },
                  onChonCambien: () => _showPopup(1),
                ),
                Divider(height: 32),
                _buildKenhThongso(
                  context,
                  kenh: 'Kênh 2',
                  cbienSelected: widget.cbienKenh2,
                  kenhColor: Colors.blue,
                  min: widget.initialKenh2['min']?.toStringAsFixed(2) ?? '0.00',
                  max: widget.initialKenh2['max']?.toStringAsFixed(2) ?? '0.00',
                  rms: widget.initialKenh2['rms']?.toStringAsFixed(2) ?? '0.00',
                  freq: widget.initialKenh2['freq']?.toStringAsFixed(2) ?? '0.00',
                  yMaxValue: _currentKenh2YMax,
                  onYMaxChanged: (val) {
                    setState(() {
                      _currentKenh2YMax = val;
                    });
                    widget.onValueChanged({
                      'kenh1YMax': _currentKenh1YMax,
                      'kenh2YMax': _currentKenh2YMax,
                    });
                  },
                  onChonCambien: () => _showPopup(2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKenhThongso(
    BuildContext context, {
    required String kenh,
    required Color kenhColor,
    required String min,
    required String max,
    required String rms,
    required String freq,
    required double yMaxValue,
    required ValueChanged<double> onYMaxChanged,
    required VoidCallback onChonCambien,
    required CambienHienthi? cbienSelected,
  }) {
    double maxSlider =
        10.0; // Giá trị tối đa của slider, có thể thay đổi tùy theo cảm biến
    double minSlider = 1.0;
    String tencbien = "Chọn cảm biến";
    String donvi = "V";
    if (cbienSelected != null) {
      tencbien = cbienSelected.name;
      maxSlider = widget.parent
          .getYMax(cbienSelected.name); // Lấy giá trị tối đa từ cảm biến
      minSlider = widget.parent.getMin(cbienSelected.name);
      donvi = cbienSelected.donvi![0]; // Lấy đơn vị từ cảm biến
    }
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: kenhColor, width: 4)),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 2),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    margin: EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: kenhColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Text(
                    kenh,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              Spacer(),
              ElevatedButton(
                onPressed: onChonCambien,
                child: Text(tencbien),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text('Min: $min'),
          Text('Max: $max'),
          Text('RMS: $rms'),
          Text('Tần số: $freq'),
          SizedBox(height: 12),
          Text(
              'Biên độ trục Y (Y max): ${yMaxValue.toStringAsFixed(1)} ${donvi}'),
          Slider(
            value: yMaxValue.clamp(0.0, maxSlider),
            onChanged: (newVal) => onYMaxChanged(newVal),
            min: minSlider,
            max: maxSlider,
            divisions: 10,
            label: '${yMaxValue.toStringAsFixed(1)} $donvi',
            activeColor: kenhColor,
          ),
        ],
      ),
    );
  }
}

class ChartData {
  ChartData(this.time, this.value);

  final double time;
  final double value;
}
