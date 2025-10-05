import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';

import '../../../Model/dulieucambien.dart';
import '../../../ultis/listcambien.dart' as globals;
import '../bocucbase.dart';
import 'bdk_helper.dart' as sendData;

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
  Timer? _timer;
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // ở đây bạn gửi dữ liệu đi
      int rPort = sendData.pinMap[redPort] ?? 0;   // ✅ dùng pinMap từ bdk_helper
      int gPort = sendData.pinMap[greenPort] ?? 0;
      int bPort = sendData.pinMap[bluePort] ?? 0;
      int redVal = red.toInt();
      int greenVal = green.toInt();
      int blueVal = blue.toInt();
      int lenh = 3;
      int len = 7;
      List<int> frame = [0x02, len, lenh, rPort,redVal, gPort, greenVal, bPort, blueVal, 0xFF];
      sendData.writeDataToBDK(frame);

    });
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,   // màu nền cho tiêu đề
        toolbarHeight: 20,              // thấp hơn mặc định
        title:  Text(
          widget.tenbaihoc,
          style: TextStyle(
            fontSize: 15,               // nhỏ hơn
            fontWeight: FontWeight.w600,
            color: Colors.white,        // chữ trắng nổi bật
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Center(
              child:  BocucBase(stream: widget.stream, wide: true,)
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildDial("R", Colors.red, red, (v) => setState(() => red = v),
                            redPort, (v) => setState(() => redPort = v)),
                        _buildDial("G", Colors.green, green,
                                (v) => setState(() => green = v), greenPort,
                                (v) => setState(() => greenPort = v)),
                        _buildDial("B", Colors.blue, blue, (v) => setState(() => blue = v),
                            bluePort, (v) => setState(() => bluePort = v)),
                      ],
                    ),
                  ),
                  Container(
                    height: 50,
                    width: 100,
                    margin: const EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      color: Color.fromARGB(255, red.toInt(), green.toInt(), blue.toInt()),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black26),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDial(String label, Color color, double value,
      ValueChanged<double> onChange, String? selectedPort,
      ValueChanged<String?> onPortChange) {
    return Column(
      children: [
        Expanded(
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
              size: 100,
              angleRange: 270,
              startAngle: 135,
              infoProperties: InfoProperties(
                modifier: (val) => val.toInt().toString(),
              ),
            ),
            onChange: onChange,
          ),
        ),
        DropdownButton<String>(
          value: selectedPort,
          items: globals.dPins.map((p) {
            return DropdownMenuItem(value: p, child: Text(p));
          }).toList(),
          onChanged: onPortChange,
        ),
      ],
    );
  }
}
