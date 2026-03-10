import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:mview/ultis/listcambien.dart';

class ManhinhHome extends StatelessWidget {
  const ManhinhHome({super.key, required this.onClickManhinhHome});

  final Function(int) onClickManhinhHome;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
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
              height: 130,
            ),
            FunctionButton(
              nameButton: "Đọc dữ liệu theo điểm",
              iconButton: Icons.fiber_manual_record_outlined,
              function: () => onClickManhinhHome(5),
              width: isMobile ? size.width * 0.8 : 200,
              height: 130,
            ),
            FunctionButton(
              nameButton: "Dao động ký",
              iconButton: Icons.bolt_outlined,
              function: () => onClickManhinhHome(6),
              width: isMobile ? size.width * 0.8 : 200,
              height: 130,
            ),
          ],
        ),
      ),
    );
  }
}

class FunctionButton extends StatefulWidget {
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
  State<FunctionButton> createState() => _FunctionButtonState();
}

class _FunctionButtonState extends State<FunctionButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = Color(MyColors.mamau['xanhduongnhat']!);
    final iconColor = Color(MyColors.mamau['xanhnhat']!);

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedScale(
        scale: isHovered ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: ElevatedButton(
            onPressed: widget.function,
            style: ElevatedButton.styleFrom(
              backgroundColor: bgColor.withOpacity(isHovered ? 0.88 : 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: isHovered ? 8 : 4,
              padding: const EdgeInsets.all(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.iconButton,
                  size: 42,
                  color: iconColor,
                ),
                const SizedBox(height: 10),
                AutoSizeText(
                  widget.nameButton,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  minFontSize: 12,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

