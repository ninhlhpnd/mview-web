import 'package:flutter/material.dart';
import 'package:testproject/Model/dulieucambien.dart';
import 'package:testproject/widget/kieuhienthi/bocucbase.dart';

class Bocuc3Manhinh extends StatelessWidget {
  const Bocuc3Manhinh({super.key, required this.stream});
  final Stream<DulieuCB> stream;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(flex: 1,child: Row(
          children: [
            Expanded(flex: 1,child: BocucBase(stream: stream, wide: false,),),
            SizedBox(width: 1,child: Container(color: Colors.black,),),
            Expanded(flex: 1,child: BocucBase(stream: stream, wide: false,),)
          ],
        ),),
        SizedBox(height: 1,child: Container(color: Colors.black,),),
        Expanded(flex: 1,child: BocucBase(stream:stream, wide: true,),)
      ],
    );
  }
}
