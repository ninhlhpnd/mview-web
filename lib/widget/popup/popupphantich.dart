import 'package:flutter/material.dart';
import 'package:testproject/ultis/listcambien.dart' as globals;
import 'package:toggle_switch/toggle_switch.dart';

class PopupPhantich extends StatelessWidget {
  const PopupPhantich(
      {super.key, required this.onClose, required this.onPhantichSelected,required this.initialState});

  final VoidCallback onClose;
  final Function(int) onPhantichSelected;
  final int? initialState;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: Color(globals.MyColors.mamau['xam']!),
          // Replace with your custom drawable
          borderRadius: BorderRadius.circular(5),
          // If you want rounded corners
          border: Border.all(
              color: Color(globals.MyColors.mamau['xanhdatroi']!), width: 2),
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
            Container(
              width: double.infinity,
              color: Color(globals.MyColors.mamau['xanhdatroi']!),
              // Replace with your custom drawable
              child: const Text(
                'Phân Tích',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            Container(
                child: SwitchList(
              selectedIndex: initialState,
              parent: this,
            )),
          ],
        ),
      ),
    );
  }
}

class SwitchList extends StatefulWidget {
  const SwitchList({super.key, this.selectedIndex, required this.parent});

  final int? selectedIndex;
  final PopupPhantich parent;

  @override
  State<SwitchList> createState() => _SwitchListState();
}

class _SwitchListState extends State<SwitchList> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double parentWidth = constraints.maxWidth;
        return ToggleSwitch(
          isVertical: true,
          radiusStyle: true,
          cornerRadius: 5,
          doubleTapDisable: true,
          initialLabelIndex: widget.selectedIndex,
          activeBgColors: [
            [Color(globals.MyColors.mamau['xanhdatroi']!)],
            [Color(globals.MyColors.mamau['xanhdatroi']!)],
            [Color(globals.MyColors.mamau['xanhdatroi']!)],
            [Color(globals.MyColors.mamau['xanhdatroi']!)],
            [Color(globals.MyColors.mamau['xanhdatroi']!)],
          ],
          inactiveBgColor: Color(globals.MyColors.mamau['xam']!),
          labels: const [
            'Tọa độ',
            'Chênh lệch',
            'Độ dốc',
            'Trung bình',
            'RMS',
          ],
          fontSize: 16,
          dividerColor: Color(globals.MyColors.mamau['xanhdatroi']!),
          onToggle: (index) {
            index ??= 7;
            widget.parent.onPhantichSelected(index);
          },
          minWidth: parentWidth, // Đặt kích thước rộng cho ToggleSwitch

        );
      },
    );
  }
}
