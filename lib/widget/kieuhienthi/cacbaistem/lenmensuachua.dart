import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'package:mview/widget/kieuhienthi/cacbaistem/widgetdieukhien.dart';

import '../../../Model/dulieucambien.dart';
import '../../../ultis/listcambien.dart' as globals;
import '../bocucbase.dart';
import 'bdk_helper.dart' as sendData;

class StemSuaChua extends StatefulWidget {
  const StemSuaChua({super.key, required this.stream, required this.tenbaihoc});

  final Stream<DulieuCB> stream;
  final String tenbaihoc;
  @override
  State<StemSuaChua> createState() => _StemSuaChuaState();
}

class _StemSuaChuaState extends State<StemSuaChua> {
  Map<String, double> currentValues = {};
  late StreamSubscription<DulieuCB> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.stream.listen((dulieu) {
      if (dulieu.tenCambien.isNotEmpty && dulieu.giaTri.isNotEmpty) {
        setState(() {
          currentValues[dulieu.tenCambien] = dulieu.giaTri.last;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue, // màu nền cho tiêu đề
        toolbarHeight: 20, // thấp hơn mặc định
        title: Text(
          widget.tenbaihoc,
          style: TextStyle(
            fontSize: 15, // nhỏ hơn
            fontWeight: FontWeight.w600,
            color: Colors.white, // chữ trắng nổi bật
          ),
        ),
        centerTitle: true,
      ),
      body: Row(
        children: [
          Expanded(
            flex: 4,
            child: Center(
                child: BocucBase(
              stream: widget.stream,
              wide: true,
            )),
          ),
          Expanded(
            flex: 3,
            child: DieuKhienWidget(
              valueGate: currentValues,
              onDieuKhienChanged: (newValues) {
                sendCommand(newValues);
              },
            ),
          ),
        ],
      ),
    );
  }

  void sendCommand(Map<String, List<int>> commands) {
    print("=== SEND COMMANDS DETAIL ===");

    for (var entry in commands.entries) {
      String cong = entry.key; // "D3"
      List<int> data = entry.value; // [lenh, value]

      int lenh = data[0];
      int value = data[1];
      int congVal = sendData.pinMap[cong] ?? 0;

      print("Port: $cong | PinVal: $congVal | Cmd: $lenh | Value: $value");

      int len = 3;
      List<int> frame = [0x02, len, lenh, congVal, value, 0xFF];

      sendData.writeDataToBDK(frame);
    }
  }
}
