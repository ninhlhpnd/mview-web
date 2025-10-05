
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:testproject/Model/cambienhienthi.dart';
import 'package:testproject/Model/dulieucambien.dart';

class ManhinhDongho extends StatelessWidget {
  const ManhinhDongho({super.key, required this.streamDulieu, required this.streamCambien});
  final Stream<DulieuCB> streamDulieu;
  final Stream<CambienHienthi> streamCambien;
  @override
  Widget build(BuildContext context) {
    return SpeedometerScreen(streamCambien: streamCambien, streamDulieu: streamDulieu);
  }
}

class SpeedometerScreen extends StatefulWidget {
  /// Creates the instance of MyHomePage
  const SpeedometerScreen({super.key, this.minValue = 0, this.maxValue = 120, required this.streamDulieu, required this.streamCambien});
  final double maxValue;
  final double minValue;
  final Stream<DulieuCB> streamDulieu;
  final Stream<CambienHienthi> streamCambien;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<SpeedometerScreen> {
  late String tencambien = 'Cảm Biến';
  late StreamSubscription<CambienHienthi> _subscriptionCambien;
  late double minValue = widget.minValue;
  late double maxValue = widget.maxValue;
  late double giaTriCambien=0;
  late int doPhanGiai = 2;
  late String donvi="";
  @override
  void initState() {
    _subscriptionCambien = widget.streamCambien.listen((CambienHienthi cambien){
      setState(() {
        tencambien = cambien.name;
        minValue = (cambien.daido != null && cambien.daido!.isNotEmpty)
            ? cambien.daido![0]
            : widget.minValue;
        maxValue = (cambien.daido != null && cambien.daido!.isNotEmpty)
            ? cambien.daido![1]
            : widget.maxValue;
        doPhanGiai = cambien.dophangiai ?? 2;
        donvi = cambien.donvi ?? "";
      });
    });
  }

  @override
  void dispose() {
    _subscriptionCambien.cancel();
    super.dispose();
  }

  Widget _getRadialGauge() {
    return StreamBuilder(
        stream: widget.streamDulieu,
        builder: (context,snapshot){
          if (snapshot.connectionState == ConnectionState.active &&
              snapshot.hasData) {
            DulieuCB dulieu = snapshot.data!;
              if(dulieu.tenCambien == tencambien){
                WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() {
                  // Cập nhật trạng thái ở đây
                  giaTriCambien = dulieu.giaTri[dulieu.giaTri.length-1];
                });
              });

            }
          }
          return SfRadialGauge(
              title: GaugeTitle(
                  text: tencambien + (donvi == "" ? "" : " ($donvi)"),
                  textStyle:
                  const TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold)),
              axes: <RadialAxis>[
                RadialAxis(
                    minimum: minValue,
                    maximum: maxValue,
                    ranges: <GaugeRange>[
                      GaugeRange(
                          startValue: minValue,
                          endValue: maxValue / 3,
                          color: Colors.green,
                          startWidth: 10,
                          endWidth: 10),
                      GaugeRange(
                          startValue: maxValue / 3,
                          endValue: maxValue * 2 / 3,
                          color: Colors.orange,
                          startWidth: 10,
                          endWidth: 10),
                      GaugeRange(
                          startValue: maxValue * 2 / 3,
                          endValue: maxValue,
                          color: Colors.red,
                          startWidth: 10,
                          endWidth: 10)
                    ],
                    pointers: <GaugePointer>[
                      NeedlePointer(value: giaTriCambien)
                    ],
                    annotations: <GaugeAnnotation>[
                      GaugeAnnotation(
                          widget: Container(
                              child: Text(giaTriCambien.toStringAsFixed(doPhanGiai),
                                  style: const TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.bold))),
                          angle: 90,
                          positionFactor: 0.5)
                    ])
              ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      child: _getRadialGauge(),
    );
  }
}
