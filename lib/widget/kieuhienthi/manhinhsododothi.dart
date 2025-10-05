import 'dart:async';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:testproject/Model/cambienhienthi.dart';
import 'package:testproject/ultis/listcambien.dart' as globals;

class SodoDothi extends StatelessWidget {
  const SodoDothi({super.key, required this.streamCambien});

  final Stream<CambienHienthi> streamCambien;

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: const EdgeInsets.only(top: 5),
        padding: EdgeInsets.only(left: 35),
        width: double.infinity,
        child: ListviewSodoDothi(
          streamCambien: streamCambien,
        ));
  }
}

class ListviewSodoDothi extends StatefulWidget {
  const ListviewSodoDothi({super.key, required this.streamCambien});

  final Stream<CambienHienthi> streamCambien;

  @override
  State<ListviewSodoDothi> createState() => _ListviewSodoDothiState();
}

class _ListviewSodoDothiState extends State<ListviewSodoDothi> {
  late List<CambienHienthi> listCambiendothi;
  late StreamSubscription<CambienHienthi> _subscriptionCambien;

  @override
  Widget build(BuildContext context) {
    if (listCambiendothi.isEmpty) {
      return const SizedBox.shrink(); // Không chiếm không gian
    }
    return SizedBox(
      height: 60, // Chiều cao bạn muốn khi có dữ liệu
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, position) {
          return GestureDetector(
            child: getRow(position),
          );
        },
        separatorBuilder: (context, index) => const VerticalDivider(
          color: Colors.grey,
          thickness: 1,
          width: 24,
        ),
        itemCount: listCambiendothi.length,
      ),
    );
  }

  @override
  void initState() {
    listCambiendothi = [];
    // f
    _subscriptionCambien =
        widget.streamCambien.listen((CambienHienthi cambien) {
      for (CambienHienthi cambienHienthi in listCambiendothi) {
        if (cambienHienthi.id == cambien.id &&
            cambienHienthi.name == cambien.name) {

          listCambiendothi.removeWhere((c) =>
          c.id == cambien.id && c.name == cambien.name);
          return;
        }
      }
      setState(() {
        listCambiendothi.add(cambien);
      });
    });


  }

  Widget getRow(int index) {
    final parts = listCambiendothi[index].id.split(',');
    final maCambien = parts.first;
    return DongSodoDothi(
        tenCambien: listCambiendothi[index].name + ' (${listCambiendothi[index].donvi})',
        maCambien: maCambien,
        mamau: globals.listColorCambien[index]);
  }

  @override
  void dispose() {
    _subscriptionCambien.cancel();
    super.dispose();
  }
}

class DongSodoDothi extends StatelessWidget {
  const DongSodoDothi(
      {super.key,
      required this.tenCambien,
      required this.maCambien,
      required this.mamau});

  final String tenCambien;
  final String maCambien;
  final Color mamau;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // View - Thanh màu xanh đậm
          Container(
            height: 5.0,
            color: mamau, // Thay mã màu xanh đậm tương ứng
          ),
          // TextView đầu tiên
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(2.0),
              child: AutoSizeText(
                tenCambien,
                minFontSize: 10,
                // Kích thước chữ tối thiểu
                maxFontSize: 20,
                // Kích thước chữ tối đa
                overflow: TextOverflow.ellipsis,
                // Thêm dấu "..." nếu không đủ chỗ
                textAlign: TextAlign.center,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.black,
                ),
              ),
            ),
          ),
          // TextView thứ hai
          Container(
            padding: const EdgeInsets.all(2.0),
            child: AutoSizeText(
              maCambien,
              minFontSize: 10,
              // Kích thước chữ tối thiểu
              maxFontSize: 20,
              // Kích thước chữ tối đa
              overflow: TextOverflow.ellipsis,
              // Thêm dấu "..." nếu không đủ chỗ
              textAlign: TextAlign.center,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
