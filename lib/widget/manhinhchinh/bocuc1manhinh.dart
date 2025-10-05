import 'package:flutter/material.dart';
import 'package:testproject/Model/dulieucambien.dart';
import 'package:testproject/widget/kieuhienthi/bocucbase.dart';

class Bocuc1Manhinh extends StatelessWidget {
  const Bocuc1Manhinh({super.key, required this.stream});
  final Stream<DulieuCB> stream;
  @override
  Widget build(BuildContext context) {
    return BocucBase(stream: stream, wide: true,);
  }
}
