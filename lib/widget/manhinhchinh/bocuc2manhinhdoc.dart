import 'package:flutter/material.dart';
import 'package:testproject/Model/dulieucambien.dart';
import 'package:testproject/widget/kieuhienthi/bocucbase.dart';

class Bocuc2Manhinhdoc extends StatelessWidget {
  const Bocuc2Manhinhdoc({super.key, required this.stream});
  final Stream<DulieuCB> stream;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(flex: 49,child: BocucBase(stream: stream, wide: true,),),
        SizedBox(height: 1,child: Container(color: Colors.black,),),
        Expanded(flex: 49,child: BocucBase(stream: stream, wide: true,),),
      ],
    );
  }
}
