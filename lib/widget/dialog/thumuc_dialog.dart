import 'package:flutter/material.dart';

import '../../ultis/listcambien.dart' as globals;

class ThumucDialog extends StatefulWidget {
  const ThumucDialog({super.key});

  @override
  State<ThumucDialog> createState() => _ThumucDialogState();
}

class _ThumucDialogState extends State<ThumucDialog> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController(); // thêm controller

  List<String> allItems = [];
  List<String> filteredItems = [];
  int? selectedIndex; // lưu dòng đang highlight

  @override
  void initState() {
    super.initState();
    for (int i=0;i<globals.lession.length;i++){
         allItems.add("Thí nghiệm ${i+1}: ${globals.lession[i]}");
    }
    filteredItems = List.from(allItems);

    _searchController.addListener(() {
      setState(() {
        filteredItems = allItems
            .where((item) =>
            item.toLowerCase().contains(_searchController.text.toLowerCase()))
            .toList();
        selectedIndex = null; // reset khi search

      });
    });
  }
  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose(); // nhớ dispose
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      height: 500,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tiêu đề
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Text(
              "Thư mục",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Thanh search
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: "Tìm bài thí nghiệm...",
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding:
                const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // List scroll
          Expanded(
            child: Scrollbar(
              controller: _scrollController, // gắn controller
              radius: const Radius.circular(12),
              thumbVisibility: true,
              child: ListView.separated(
                controller: _scrollController, // gắn controller
                padding: const EdgeInsets.all(8),
                itemCount: filteredItems.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  final isSelected = selectedIndex == index;

                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      // single click -> highlight hoặc preview
                      setState(() {
                        selectedIndex = index;
                      });

                    },
                    onDoubleTap: () {
                      // double click -> gửi dữ liệu về main
                      Navigator.of(context).pop(index);
                      // index hoặc có thể gửi item
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 0),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: isSelected ? Colors.blue[100] : Colors.grey[100],
                        boxShadow: [
                          if (isSelected)
                            const BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            )
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.science,
                              color: isSelected ? Colors.blue : Colors.grey[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.blue[900] : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
