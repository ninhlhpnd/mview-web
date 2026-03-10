import 'package:flutter/material.dart';
import 'package:mview/Model/dulieucambien.dart';
import 'package:mview/widget/kieuhienthi/bocucbase.dart';

class Bocuc2Manhinhngang extends StatelessWidget {
  const Bocuc2Manhinhngang({super.key,required this.stream});
  final Stream<DulieuCB> stream;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 150,child: BocucBase(stream: stream, wide: false,),),
        SizedBox(width: 1,child: Container(color: Colors.black,),),
        Expanded(flex: 150,child: BocucBase(stream: stream, wide: false,),),
      ],
    );
  }
}
