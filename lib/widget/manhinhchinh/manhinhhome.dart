import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:testproject/ultis/listcambien.dart';

class ManhinhHome extends StatelessWidget {
  const ManhinhHome({super.key, required this.onClickManhinhHome});

  final Function(int) onClickManhinhHome;

  @override
  Widget build(BuildContext context) {
    var mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;

    // Tính toán số nút mỗi hàng tùy theo kích thước màn hình
    final isMobile = size.width < 600;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 32,
          runSpacing: 32,
          children: [
            FunctionButton(
              nameButton: "Đọc dữ liệu tự động",
              iconButton: Icons.auto_mode_outlined,
              function: () => onClickManhinhHome(1),
              width: isMobile ? size.width * 0.8 : 200,
              height: 120,
            ),
            FunctionButton(
              nameButton: 'Dao động ký',
              iconButton: Icons.bolt_outlined,
              function: () => onClickManhinhHome(6),
              width: isMobile ? size.width * 0.8 : 200,
              height: 120,
            ),
          ],
        ),
      ),
    );
      // Row(
      // crossAxisAlignment: CrossAxisAlignment.center,
      // mainAxisAlignment: MainAxisAlignment.spaceAround,
      // children: [
      //   SizedBox(
      //     height: mediaQuery.size.height / 3,
      //     child: FunctionButton(
      //       nameButton: "Đọc dữ liệu tự động",
      //       iconButton: Icons.auto_mode_outlined,
      //       function: () {
      //         onClickManhinhHome(1);
      //       },
      //     ),
      //   ),
        // SizedBox(
        //   height: mediaQuery.size.height / 3,
        //   child: FunctionButton(
        //     nameButton: "Đọc dữ liệu theo điểm",
        //     iconButton: Icons.fiber_manual_record,
        //     function: () {
        //       onClickManhinhHome(5);
        //     },
        //   ),
        // ),
        // SizedBox(
        //   height: mediaQuery.size.height / 3,
        //   child: FunctionButton(
        //     nameButton: 'Oscilloscope',
        //     iconButton: Icons.bolt_outlined,
        //     function: () {
        //       onClickManhinhHome(6);
        //     },
        //   ),
        // ),
        // SizedBox(
        //   height: mediaQuery.size.height / 3,
        //   child: FunctionButton(
        //     nameButton: "Sóng âm",
        //     iconButton: Icons.surround_sound_outlined,
        //     function: () {
        //       onClickManhinhHome(7);
        //     },
        //   ),
        // ),
      // ],
    // );
  }
}

class FunctionButton extends StatelessWidget {
  const FunctionButton({
    super.key,
    required this.nameButton,
    required this.iconButton,
    required this.function,
    this.width = 200,
    this.height = 120,
  });

  final String nameButton;
  final IconData iconButton;
  final VoidCallback function;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: function,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(MyColors.mamau['xanhduongnhat']!),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          padding: const EdgeInsets.all(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              iconButton,
              size: 36,
              color: Color(MyColors.mamau['xanhnhat']!),
            ),
            const SizedBox(height: 8),
            AutoSizeText(
              nameButton,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              maxLines: 2,
              minFontSize: 12,
            ),
          ],
        ),
      ),
    );
  }
}
