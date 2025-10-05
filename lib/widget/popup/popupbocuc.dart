import 'package:flutter/material.dart';
import 'package:testproject/ultis/listcambien.dart';

class PopupBocuc extends StatelessWidget {
  final VoidCallback onClose;
  final Function(int) onBocucSelected;

  const PopupBocuc(
      {super.key, required this.onClose, required this.onBocucSelected});

  @override
  Widget build(BuildContext context) {
    double popupWidth = MediaQuery.of(context).size.width * 0.2; // 60% màn hình
    double popupHeight = popupWidth; // 35% màn hình

    double itemWidth = (popupWidth - 60) / 2; // trừ khoảng cách giữa các item
    double itemHeight = (popupHeight - 50 - 40) / 2; // trừ header + spacing

    return Center(
      child: Container(
        width: popupWidth,
        height: popupHeight,
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
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: Color(MyColors.mamau['xanhdatroi']!),
              child: const Text(
                'Bố Cục',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Grid Items
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildItem(1, itemWidth, itemHeight),
                    const SizedBox(width: 12),
                    _buildItem(2, itemWidth, itemHeight),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildItem(3, itemWidth, itemHeight),
                    const SizedBox(width: 12),
                    _buildItem(4, itemWidth, itemHeight),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

// Hàm helper để tạo item
  Widget _buildItem(int index, double width, double height) {
    return SizedBox(
      width: width,
      height: height,
      child: _BocucButtonFunction(
        function: () {
          onBocucSelected(index);
          onClose();
        },
        image: 'assets/bocuc/bocuc$index.png',
      ),
    );
  }



}

class _BocucButtonFunction extends StatelessWidget {
  final String image;
  final void Function()? function;

  const _BocucButtonFunction({
    required this.function,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: function,
        child: Container(
          width: 50,  // Kích thước chiều rộng cố định
          height: 50,  // Kích thước chiều cao cố định
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              image,
              fit: BoxFit.contain, // Giữ tỉ lệ ảnh
            ),
          ),
        ),
      ),
    );
  }
}

