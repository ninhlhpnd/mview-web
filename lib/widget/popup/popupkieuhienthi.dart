import 'package:flutter/material.dart';
import 'package:testproject/ultis/listcambien.dart';

class Popupkieuhienthi extends StatelessWidget {
  final VoidCallback onClose;
  final Function(int) onClickKieuhienthi;

  const Popupkieuhienthi(
      {super.key, required this.onClose, required this.onClickKieuhienthi});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(MyColors.mamau['xam']!),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Color(MyColors.mamau['xanhdatroi']!), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tiêu đề
        Container(
          width: double.infinity,
          color: Color(MyColors.mamau['xanhdatroi']!),
          child: const Text(
            'Kiểu Hiển Thị',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        // Danh sách kiểu hiển thị
        ...[
          (Icons.show_chart_rounded, 'Đồ thị', 1),
          (Icons.onetwothree_outlined, 'Số', 2),
          (Icons.table_rows_outlined, 'Bảng số liệu', 3),
          (Icons.speed_outlined, 'Đồng hồ', 4),
        ].map((item) {
          return Column(
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height > 600 ? 50 : 42,
                child: _DongKieuhienthi(
                  iconData: item.$1,
                  kieuhienthi: item.$2,
                  function: () {
                    onClickKieuhienthi(item.$3);
                    onClose();
                  },
                ),
              ),
              Container(
                height: 1,
                color: Color(MyColors.mamau['xanhnhat']!),
              ),
            ],
          );
        }).toList(),
      ],
    )
    );

  }
}

class _DongKieuhienthi extends StatelessWidget {
  final IconData iconData;
  final String kieuhienthi;
  final VoidCallback function;

  const _DongKieuhienthi({
    required this.iconData,
    required this.kieuhienthi,
    required this.function,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: function,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(iconData, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  kieuhienthi,
                  style: const TextStyle(
                    fontSize: 18,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

