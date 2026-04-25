import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mview/Model/cambien.dart';
import 'package:mview/Model/cambienhienthi.dart';
import 'package:mview/Model/dulieucambien.dart';
import 'package:mview/ultis/listcambien.dart';

class ManhinhSo extends StatelessWidget {
  const ManhinhSo({
    super.key,
    required this.stream,
    required this.streamAddSensor,
    required this. listDeviceSelected,
  });
  final Stream<DulieuCB> stream;
  final Stream<CambienHienthi> streamAddSensor;
  final List<dynamic> listDeviceSelected;

  @override
  Widget build(BuildContext context) {
    var mediaQuery = MediaQuery.of(context);
    return SizedBox(
      height: mediaQuery.size.height,
      child: Column(
        children: [
          Expanded(
            flex: 1,
            child: Container(
                padding: const EdgeInsets.only(top: 10),
                width: mediaQuery.size.width,
                child: TenCambien(
                  ten: 'Cảm Biến',
                  fontSize: 15,
                  streamCambien: streamAddSensor,
                  listDeviceSelected: listDeviceSelected,
                )),
          ),
          Expanded(
            flex: 4,
            child: SizedBox(
              width: mediaQuery.size.width,
              child: Center(
                child: GiatriCambien(
                    giatri: 0.0,
                    fontSize: mediaQuery.size.height / 6,
                    stream: stream,
                    streamAddSensor: streamAddSensor,
                    listDeviceSelected: listDeviceSelected),
              ),
            ),
          ),
          // Expanded(
          //   flex: 1,
          //   child: Container(
          //     alignment: Alignment.centerLeft,
          //     padding: const EdgeInsets.only(left: 10),
          //     width: mediaQuery.size.width,
          //     child: TextButton(
          //         onPressed: () {},
          //         style: ElevatedButton.styleFrom(
          //             backgroundColor:
          //                 Color(MyColors.mamau['xam']!),
          //             shape: RoundedRectangleBorder(
          //                 borderRadius: BorderRadius.circular(5.0))),
          //         child: Row(
          //           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          //           mainAxisSize: MainAxisSize.min,
          //           children: [
          //             Icon(
          //               Icons.exposure_zero_outlined,
          //               color: Color(MyColors.mamau['xanhnhat']!),
          //             ),
          //             const SizedBox(
          //               width: 5,
          //             ),
          //             const Text(
          //               'Tare',
          //               style: TextStyle(
          //                   fontSize: 20,
          //                   color: Colors
          //                       .black), // Đặt kích thước phông chữ lớn nhất mong muốn
          //             ),
          //           ],
          //         ),
          //       ),
          //     ),
          //
          // ),
        ],
      ),
    );
  }
}

class TenCambien extends StatefulWidget {
  const TenCambien({
    super.key,
    required this.ten,
    required this.fontSize,
    required this.streamCambien,
    required this.listDeviceSelected,
  });
  final String ten;
  final double fontSize;
  final Stream<CambienHienthi> streamCambien;
  final List<dynamic> listDeviceSelected;

  @override
  State<TenCambien> createState() => _TenCambienState();
}

class _TenCambienState extends State<TenCambien> {
  @override
  late String tenCB = "Cảm biến";
  late StreamSubscription<CambienHienthi> _tencbSubcription;
  Widget build(BuildContext context) {
    return Text(
      tenCB,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: widget.fontSize,
        color: Color(MyColors.mamau['xanhnhat']!),
      ),
    );
  }

  @override
  void initState() {
    if (widget.listDeviceSelected.isNotEmpty) {
      final cambien = widget.listDeviceSelected.first;
      if (cambien is CambienHienthi) {
        tenCB = cambien.name + " (${cambien.donvi})";
      }
    }
    _tencbSubcription = widget.streamCambien.listen((CambienHienthi cambien) {
      setState(() {
        tenCB = cambien.name + " (${cambien.donvi})";
      });
    });
  }
}

class GiatriCambien extends StatefulWidget {
  const GiatriCambien({
    super.key,
    required this.giatri,
    required this.fontSize,
    required this.stream,
    required this.streamAddSensor,
    required this.listDeviceSelected,
  });
  final double giatri;
  final double fontSize;
  final Stream<DulieuCB> stream;
  final Stream<CambienHienthi> streamAddSensor;
  final List<dynamic> listDeviceSelected;
  @override
  State<GiatriCambien> createState() => _GiatriCambienState();
}

class _GiatriCambienState extends State<GiatriCambien> {
  String strGiatri = "0.0";
  late String donvi = "";
  late List<double> heso = [1, 0];
  late int dophangiai = 2;
  late StreamSubscription<DulieuCB> _subscription;
  late StreamSubscription<CambienHienthi> _subscriptionCambien;
  late String tenCambien = "";

  @override
  Widget build(BuildContext context) {
    return Text(
      strGiatri,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: widget.fontSize,
        color: Colors.black,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.listDeviceSelected.isNotEmpty) {
      final cambien = widget.listDeviceSelected.first;
      if (cambien is CambienHienthi) {
        donvi = cambien.donvi ?? "";
        heso = cambien.heso ?? [1, 0];
        dophangiai = cambien.dophangiai ?? 2;
        tenCambien = cambien.name;
      }
    }
    _subscription = widget.stream.listen((DulieuCB number) {
      if (tenCambien == number.tenCambien) {
        setState(() {
          double value = heso[0] * number.giaTri[0] + heso[1];
          strGiatri = value.toStringAsFixed(dophangiai) + " $donvi";
        });
      }
    });
    _subscriptionCambien =
        widget.streamAddSensor.listen((CambienHienthi cambien) {
      setState(() {
        donvi = cambien.donvi!;
        heso = cambien.heso!;
        dophangiai = cambien.dophangiai!;
        tenCambien = cambien.name;
      });
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    _subscriptionCambien.cancel();
    super.dispose();
  }
}
