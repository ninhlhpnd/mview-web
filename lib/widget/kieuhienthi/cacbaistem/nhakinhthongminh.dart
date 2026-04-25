import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';

import '../../../Model/dulieucambien.dart';
import '../../../ultis/listcambien.dart' as globals;
import '../bocucbase.dart';
import 'bdk_helper.dart' as sendData;
import 'widgetdieukhien.dart';

class StemNhaKinh extends StatefulWidget {
  const StemNhaKinh({super.key, required this.stream, required this.tenbaihoc});
  final Stream<DulieuCB> stream;
  final String tenbaihoc;
  @override
  State<StemNhaKinh> createState() => _StemNhaKinhState();
}

class _StemNhaKinhState extends State<StemNhaKinh> {
  double red = 128, green = 128, blue = 128;

  String? redPort = "D3";
  String? greenPort = "D4";
  String? bluePort = "D5";

  bool _showDieuKhienLogic = false; // Biến trạng thái để chuyển đổi UI
  Map<String, double> _sensorValues = {}; // Khởi tạo map giá trị cảm biến
  StreamSubscription<DulieuCB>? _streamSubscription;

  bool _isAutoRandomColor = false;
  Timer? _randomColorTimer;

  void _toggleAutoRandomColor(bool value) {
    setState(() {
      _isAutoRandomColor = value;
    });
    if (_isAutoRandomColor) {
      _changeRandomColor();
      _randomColorTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        if (mounted) {
          _changeRandomColor();
        }
      });
    } else {
      _randomColorTimer?.cancel();
    }
  }

  void _changeRandomColor() {
    final random = math.Random();
    setState(() {
      red = random.nextInt(256).toDouble();
      green = random.nextInt(256).toDouble();
      blue = random.nextInt(256).toDouble();
    });
  }

  Timer? _timer;
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // ở đây bạn gửi dữ liệu đi
      int rPort = sendData.pinMap[redPort] ?? 0; // ✅ dùng pinMap từ bdk_helper
      int gPort = sendData.pinMap[greenPort] ?? 0;
      int bPort = sendData.pinMap[bluePort] ?? 0;
      int redVal = red.toInt();
      int greenVal = green.toInt();
      int blueVal = blue.toInt();
      int lenh = 3;
      int len = 7;
      List<int> frame = [
        0x02,
        len,
        lenh,
        rPort,
        redVal,
        gPort,
        greenVal,
        bPort,
        blueVal,
        0xFF
      ];
      sendData.writeDataToBDK(frame);
    });
  }

  @override
  void initState() {
    super.initState();
    _startTimer();

    _streamSubscription = widget.stream.listen((data) {
      if (mounted) {
        setState(() {
          if (data.tenCambien.isNotEmpty && data.giaTri.isNotEmpty) {
            _sensorValues[data.tenCambien] = data.giaTri.last;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _randomColorTimer?.cancel();
    _streamSubscription?.cancel();
    super.dispose();
  }

  void sendCommand(Map<String, List<int>> commands) {
    debugPrint("=== SEND COMMANDS DETAIL (NhaKinh) ===");

    for (var entry in commands.entries) {
      String cong = entry.key; // "D3"
      List<int> data = entry.value; // [lenh, value]

      int lenh = data[0];
      int value = data[1];
      int congVal = sendData.pinMap[cong] ?? 0;

      debugPrint("Port: $cong | PinVal: $congVal | Cmd: $lenh | Value: $value");

      int len = 3;
      List<int> frame = [0x02, len, lenh, congVal, value, 0xFF];

      sendData.writeDataToBDK(frame);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    // Kích thước vòng xoay dựa trên chiều ngắn hơn của màn hình để đảm bảo luôn hiển thị tốt
    double dialSize = (isLandscape ? size.height : size.width) / 3.5;
    dialSize = dialSize.clamp(60.0, 150.0);

    Widget controlPanel = Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _buildDial(
                    "R",
                    Colors.red,
                    red,
                    (v) { if (!_isAutoRandomColor) setState(() => red = v); },
                    redPort,
                    (v) => setState(() => redPort = v),
                    dialSize,
                  ),
                ),
                Expanded(
                  child: _buildDial(
                    "G",
                    Colors.green,
                    green,
                    (v) { if (!_isAutoRandomColor) setState(() => green = v); },
                    greenPort,
                    (v) => setState(() => greenPort = v),
                    dialSize,
                  ),
                ),
                Expanded(
                  child: _buildDial(
                    "B",
                    Colors.blue,
                    blue,
                    (v) { if (!_isAutoRandomColor) setState(() => blue = v); },
                    bluePort,
                    (v) => setState(() => bluePort = v),
                    dialSize,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: isLandscape ? dialSize * 0.4 : dialSize * 0.6,
                width: dialSize * 1.5,
                margin: const EdgeInsets.only(top: 10, bottom: 10),
                decoration: BoxDecoration(
                  color: Color.fromARGB(
                      255, red.toInt(), green.toInt(), blue.toInt()),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black26),
                ),
              ),
              const SizedBox(width: 20),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Màu ngẫu nhiên",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  Switch(
                    value: _isAutoRandomColor,
                    onChanged: _toggleAutoRandomColor,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    Widget mainContent = Center(
      child: BocucBase(
        stream: widget.stream,
        wide: true,
      ),
    );

    Widget rightPanel = Column(
      children: [
        // Nút chuyển đổi (Toggle)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: const Text("Chỉnh Màu RGB"),
                selected: !_showDieuKhienLogic,
                onSelected: (val) {
                  if (val) setState(() => _showDieuKhienLogic = false);
                },
              ),
              const SizedBox(width: 10),
              ChoiceChip(
                label: const Text("Lập Trình Theo Điều Kiện"),
                selected: _showDieuKhienLogic,
                onSelected: (val) {
                  if (val) setState(() => _showDieuKhienLogic = true);
                },
              ),
            ],
          ),
        ),
        // Nội dung tương ứng
        Expanded(
          child: _showDieuKhienLogic
              ? DieuKhienWidget(
                  valueGate: _sensorValues,
                  onDieuKhienChanged: (data) {
                    // Gọi hàm sendCommand đã tạo để gửi xuống BDK
                    sendCommand(data);
                  },
                )
              : controlPanel, // controlPanel chứa layout kéo Slider chỉnh màu cũ
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue, // màu nền cho tiêu đề
        toolbarHeight: 20, // thấp hơn mặc định
        title: Text(
          widget.tenbaihoc,
          style: const TextStyle(
            fontSize: 15, // nhỏ hơn
            fontWeight: FontWeight.w600,
            color: Colors.white, // chữ trắng nổi bật
          ),
        ),
        centerTitle: true,
      ),
      body: isLandscape
          ? Row(
              children: [
                Expanded(flex: 5, child: mainContent),
                Expanded(flex: 5, child: rightPanel),
              ],
            )
          : Column(
              children: [
                Expanded(flex: 4, child: mainContent),
                Expanded(flex: 5, child: rightPanel),
              ],
            ),
    );
  }

  Widget _buildDial(
      String label,
      Color color,
      double value,
      ValueChanged<double> onChange,
      String? selectedPort,
      ValueChanged<String?> onPortChange,
      double dialSize) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: dialSize,
          width: dialSize,
          child: SleekCircularSlider(
            min: 0,
            max: 255,
            initialValue: value,
            appearance: CircularSliderAppearance(
              customColors: CustomSliderColors(
                progressBarColor: color,
                trackColor: color.withOpacity(0.2),
                dotColor: color,
              ),
              size: dialSize,
              angleRange: 270,
              startAngle: 135,
              infoProperties: InfoProperties(
                modifier: (val) => val.toInt().toString(),
              ),
            ),
            onChange: onChange,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButton<String>(
          value: selectedPort,
          isDense: true,
          items: globals.dPins.map((p) {
            return DropdownMenuItem(value: p, child: Text(p));
          }).toList(),
          onChanged: onPortChange,
        ),
      ],
    );
  }
}
