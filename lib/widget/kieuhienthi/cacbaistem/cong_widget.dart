import 'package:flutter/material.dart';
import 'package:testproject/ultis/listcambien.dart' as globals;

class CongWidget extends StatefulWidget {
  final String? selected;
  final String giaTri;
  final ValueChanged<String?> onChanged;
  final ValueChanged<String>? onLabelChanged;

  // Port mặc định
  static const List<String> defaultPorts = globals.sensors;

  const CongWidget({
    super.key,
    required this.selected,
    required this.giaTri,
    required this.onChanged,
    this.onLabelChanged,
  });

  @override
  State<CongWidget> createState() => _CongWidgetState();
}

class _CongWidgetState extends State<CongWidget> {
  final TextEditingController _labelController = TextEditingController();

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hàng trên cùng: chọn cổng + nhập tên chú thích
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: DropdownButton<String>(
                    value: widget.selected,
                    hint: const Text("Chọn cổng"),
                    items: CongWidget.defaultPorts
                        .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p),
                    ))
                        .toList(),
                    onChanged: widget.onChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _labelController,
                    decoration: InputDecoration(
                      hintText: "Nhập chú thích",
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: const Icon(Icons.edit, size: 18),
                    ),
                    onChanged: widget.onLabelChanged,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Giá trị cảm biến
            Center(
              child: Text(
                widget.giaTri,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
