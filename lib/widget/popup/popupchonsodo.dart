import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:mview/Model/cambien.dart';
import 'package:mview/Model/cambienhienthi.dart';
import 'package:mview/Model/sodocambien.dart';
import 'package:mview/ultis/listcambien.dart' as globals;

class PopupChonsodo extends StatelessWidget {
  const PopupChonsodo(
      {super.key, required this.onClose, required this.sodocambienList, required this.onCambienSelected, required this.listDeviceSelected});

  final List<SodoCambien> sodocambienList;
  final VoidCallback onClose;
  final Function(CambienHienthi) onCambienSelected;
  final List<dynamic> listDeviceSelected;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(globals.MyColors.mamau['xam']!),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
            color: Color(globals.MyColors.mamau['xanhdatroi']!),
            width: 2
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            color: Color(globals.MyColors.mamau['xanhdatroi']!),
            child: const Text(
              'Chọn Số Đo',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          // Sử dụng Expanded hoặc SingleChildScrollView ở đây
          SingleChildScrollView(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.27, // 👈 Giới hạn chiều cao để cuộn được
              child: ListviewSodo(
                sodocambienList: sodocambienList,
                listDeviceSelected: listDeviceSelected,
                onClose: onClose,
                onCambienSelected: onCambienSelected,
              ),
            ),
          ),
        ],
      ),
    );


  }


}
class ListviewSodo extends StatefulWidget {
  const ListviewSodo({super.key, required this.sodocambienList, required this.onClose, required this.onCambienSelected, required this.listDeviceSelected});
  final List<SodoCambien> sodocambienList;
  final VoidCallback onClose;
  final Function(CambienHienthi) onCambienSelected;
  final List<dynamic> listDeviceSelected;
  @override
  State<ListviewSodo> createState() => _ListviewSodoState();
}

class _ListviewSodoState extends State<ListviewSodo> {
  late String chondonvi="";
  late List<double> hesoCambien = [1,0];
  late List<SodoCambien> filteredSodoCambienList;
  @override
  void initState() {
    super.initState();
    // Lọc danh sách vào filteredSodoCambienList
    filteredSodoCambienList = _filterUniqueDevices(widget.sodocambienList);
  }

  // Hàm lọc các phần tử trùng lặp dựa trên bluetoothDevice.name
  List<SodoCambien> _filterUniqueDevices(List<SodoCambien> sodocambienList) {
    Set<String> seenBluetoothDevices = Set();
    return sodocambienList.where((item) {
      // Kiểm tra xem bluetoothDevice.name đã được gặp chưa
      String key = "${item.bluetoothDevice.name}_${item.tenCambien}";

      if (seenBluetoothDevices.contains(key)) {
        return false; // Nếu đã gặp, loại bỏ phần tử này
      } else {
        seenBluetoothDevices.add(item.tenCambien); // Nếu chưa gặp, thêm vào Set
        return true; // Giữ lại phần tử
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return getListviewSodo();
  }


  ListView getListviewSodo() {
    if(globals.historyViewMode.value == true){
      return ListView.separated(
        shrinkWrap: true,
        scrollDirection: Axis.vertical,
        itemBuilder: (context, position) {
          return GestureDetector(
            onTap: () {
              widget.onClose();
              String id = globals.historySelected['thietbi'].keys.toList()[position];
              Cambien cambien = Cambien(id: id, name: 'Unknown');
              for (var cam in globals.cambiens) {
                if (id.contains(cam.id)) {
                  cambien = cam;
                }
              }
              String name = cambien?.name ?? '';
              if(chondonvi == ""){
                chondonvi = globals.historySelected['thietbi'][id]['donVi'] ?? '';
              }
              CambienHienthi cambienhienthi= CambienHienthi(id: id,  name: name, donvi: chondonvi);
              widget.onCambienSelected(cambienhienthi);
            },
            child: getRow(position),
          );
        },

        separatorBuilder: (context, index) {
          return const Divider(
            color: Colors.grey,
            thickness: 1,
            indent: 24,
            endIndent: 24,
          );
        },
        itemCount: globals.historySelected['thietbi'].keys.length,
        padding: EdgeInsets.zero,

      );
    }
    return ListView.separated(
      shrinkWrap: true,
      scrollDirection: Axis.vertical,
      itemBuilder: (context, position) {
        return GestureDetector(
          onTap: () {
            // Hàm được thực hiện khi chạm vào item
            widget.onClose();
            String name = filteredSodoCambienList[position].tenCambien;
            String id='${filteredSodoCambienList[position].bluetoothDevice.name},$name';
            List<double>? daido=filteredSodoCambienList[position].daido;
            int? dophangiai = filteredSodoCambienList[position].doPhangiai;
            List<List<double>>? heso = filteredSodoCambienList[position].heso;
            List<String>? strDonvi = filteredSodoCambienList[position].donvi;
            if(chondonvi == ""){
              chondonvi = filteredSodoCambienList[position].donvi![0];
              // hesoCambien = heso![0];
            }
            if(strDonvi!.length>0){
              for(int i=0;i<strDonvi.length;i++){
                if(chondonvi == strDonvi[i]){
                  hesoCambien= heso![i];
                }
              }
            }
            CambienHienthi cambien= CambienHienthi(id: id, name: name, donvi: chondonvi,
                daido: daido, dophangiai: dophangiai,heso: hesoCambien);
            widget.onCambienSelected(cambien);
          },
          child: getRow(position),
        );
      },

      separatorBuilder: (context, index) {
        return const Divider(
          color: Colors.grey,
          thickness: 1,
          indent: 24,
          endIndent: 24,
        );
      },
      itemCount: filteredSodoCambienList.length,
      padding: EdgeInsets.zero,

    );
  }
  void chonDonvi(String donvi){
      chondonvi = donvi;

  }
  Widget getRow(int index) {
    if(globals.historyViewMode.value){
      return _Chonsodo(parent: this, onClose: widget.onClose, onChondonvi: chonDonvi, listDeviceSelected: widget.listDeviceSelected, index: index);

    }
    return _Chonsodo(parent: this, sodoCambien: filteredSodoCambienList[index], onClose: widget.onClose, onChondonvi: chonDonvi, listDeviceSelected: widget.listDeviceSelected, index: index);
  }

}

class _Chonsodo extends StatefulWidget {
  const _Chonsodo({required this.parent, this.sodoCambien, required this.onClose, required this.onChondonvi, required this.listDeviceSelected, required this.index});

  final _ListviewSodoState parent;
  final SodoCambien? sodoCambien;
  final Function onClose;
  final Function(String) onChondonvi;
  final List<dynamic> listDeviceSelected;
  final int index;
  @override
  State<_Chonsodo> createState() => _ChonsodoState();
}

class _ChonsodoState extends State<_Chonsodo> {
  String strDonvi = '';
  OverlayEntry? menuEntry;
  final GlobalKey _buttonKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    String? image;
    String? tencambien;
    String? idcambien;
    List<String>? donvi;

    if(globals.historyViewMode.value){
      String id = globals.historySelected['thietbi'].keys.toList()[widget.index];
      Cambien cambien = Cambien(id: id, name: 'Unknown');
      for (var cam in globals.cambiens) {
        if (id.contains(cam.id)) {
          cambien = cam;
          break;
        }
      }
      image = cambien.icon ?? '';
      tencambien = cambien.name;
      idcambien = id;
      donvi = [globals.historySelected['thietbi'][id]['donVi'] ?? ''];
      strDonvi = globals.historySelected['thietbi'][id]['donVi'] ?? '';
    }else{
      image = widget.sodoCambien!.icon;
      tencambien = widget.sodoCambien!.tenCambien;
      idcambien = widget.sodoCambien!.bluetoothDevice.name;
      donvi = widget.sodoCambien!.donvi;
    }

    // Kiểm tra cảm biến đã chọn
    bool isSelected = widget.listDeviceSelected.any(
          (cambien) => cambien.id == '$idcambien,$tencambien',
    );

    return Center(
      child: Container(
        height: 60,
        padding: EdgeInsets.zero,
        color: Color(globals.MyColors.mamau['xam']!), // Màu nền mặc định
        child: Row(
          children: [
            // Hình ảnh
            Container(
              padding: const EdgeInsets.only(left: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Image.asset(
                  image!,
                  fit: BoxFit.cover,
                  width: 30,
                  height: 30,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Text: Tên cảm biến & ID + Icon dấu tích nếu được chọn
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      AutoSizeText(
                        tencambien,
                        maxLines: 1,
                        minFontSize: 10,
                        maxFontSize: 15,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  AutoSizeText(
                    idcambien!,
                    maxLines: 1,
                    minFontSize: 8,
                    maxFontSize: 12,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Spacer + Nút đơn vị
            const Spacer(),
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(
                isSelected ?  Icons.close : Icons.check,
                color: isSelected ?  Colors.red : Colors.green,
                size: 20,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.05,
                height: 40,
                child: ElevatedButton(
                  key: _buttonKey,
                  onPressed: () {
                    _ShowMenuDonvi(context, donvi);
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.center,
                  ),
                  child: Center(
                    child: AutoSizeText(
                      strDonvi,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      minFontSize: 8,
                      maxFontSize: 13,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  @override
  void initState() {
    if (widget.sodoCambien != null &&
        widget.sodoCambien!.donvi != null &&
        widget.sodoCambien!.donvi!.isNotEmpty) {
      strDonvi = widget.sodoCambien!.donvi![0];
    } else {
      strDonvi = ""; // hoặc giá trị mặc định phù hợp
    }
  }

  void _ShowMenuDonvi(BuildContext context, List<String>? donvi) {
    final RenderBox button =
        _buttonKey.currentContext?.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final Offset buttonPosition =
        button.localToGlobal(Offset.zero, ancestor: overlay);
    final Size buttonSize = button.size;

    // Tạo một OverlayEntry mới cho menu
    menuEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            GestureDetector(
              onTap: () {
                menuEntry?.remove();
              },
              child: Container(
                color: Colors.transparent,
              ),
            ),
            Positioned(
              left: buttonPosition.dx,
              top: buttonPosition.dy + buttonSize.height,
              child: Material(
                elevation: 8.0,
                child: Container(
                  color: Colors.white,
                  width: buttonSize.width,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: donvi!.map((String? value) {
                      return InkWell(
                        onTap: () {
                          setState(() {
                            strDonvi = value!;
                          });
                          menuEntry?.remove();
                          widget.onChondonvi(strDonvi);
                        },
                        child: Container(
                          alignment: Alignment.center, // 👈 Căn giữa nội dung
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: AutoSizeText(
                            value!,
                            style: const TextStyle(fontSize: 13),
                            maxLines: 1,
                            minFontSize: 8,
                            maxFontSize: 13,
                            textAlign: TextAlign.center, // 👈 Căn text giữa
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );


    // Thêm OverlayEntry vào overlay hiện tại
    Overlay.of(context).insert(menuEntry!);
  }
}
