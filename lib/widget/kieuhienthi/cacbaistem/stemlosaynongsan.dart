import 'dart:async';
import 'package:flutter/material.dart';
import 'package:testproject/widget/kieuhienthi/cacbaistem/widgetdieukhien.dart';

import '../../../Model/dulieucambien.dart';
import 'bdk_helper.dart' as sendData;
import 'cong_widget.dart';


class StemLoSayNongSan extends StatefulWidget {
  final Stream<DulieuCB> stream;
  final void Function(List<String>) onPortsChanged;
  final String tenbaihoc;
  const StemLoSayNongSan({
    super.key,
    required this.stream,
    required this.onPortsChanged,
    required this.tenbaihoc,
  });

  @override
  State<StemLoSayNongSan> createState() => _StemLoSayNongSanState();
}

class _StemLoSayNongSanState extends State<StemLoSayNongSan> {
  String? selectedPort1;
  String? selectedPort2;
  Map<String, double> currentValues = {};
  late StreamSubscription<DulieuCB> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.stream.listen((dulieu) {
      if (dulieu.tenCambien != null && dulieu.giaTri.isNotEmpty) {
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

  void _notifyParent() {
    final ports = <String>[];
    if (selectedPort1 != null) ports.add(selectedPort1!);
    if (selectedPort2 != null) ports.add(selectedPort2!);
    widget.onPortsChanged(ports);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 20,
          color: Colors.blue,
          alignment: Alignment.center,
          child:  Text(
            widget.tenbaihoc,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    Expanded(
                      child: CongWidget(
                        selected: selectedPort1,
                        giaTri: selectedPort1 != null
                            ? (currentValues[selectedPort1] ?? 0)
                            .toStringAsFixed(2)
                            : "-",
                        onChanged: (val) {
                          setState(() {
                            selectedPort1 = val;
                            _notifyParent();
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: CongWidget(
                        selected: selectedPort2,
                        giaTri: selectedPort2 != null
                            ? (currentValues[selectedPort2] ?? 0)
                            .toStringAsFixed(2)
                            : "-",
                        onChanged: (val) {
                          setState(() {
                            selectedPort2 = val;
                            _notifyParent();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: DieuKhienWidget(
                  valueGate: currentValues,
                  onDieuKhienChanged: (command) {
                    onDieuKhienChanged(command);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void onDieuKhienChanged(Map<String, List<int>> newValues) {
    for (var entry in newValues.entries) {
      String cong = entry.key;       // ví dụ "D3"
      List<int> data = entry.value;  // ví dụ [1, 255]

      int lenh = data[0];
      int value = data[1];
      int congVal = sendData.pinMap[cong] ?? 0;   // ✅ dùng pinMap từ bdk_helper

      int len = 3;
      List<int> frame = [0x02, len, lenh, congVal, value, 0xFF];

      sendData.writeDataToBDK(frame); // ✅ gọi hàm helper
    }
  }
}
