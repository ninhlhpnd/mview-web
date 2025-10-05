import 'package:auto_size_text/auto_size_text.dart';


import 'package:flutter/material.dart';
import 'package:testproject/ultis/listcambien.dart' as globals;

class ConfigDialogContent extends StatefulWidget {
  const ConfigDialogContent({super.key});

  @override
  _ConfigDialogContentState createState() => _ConfigDialogContentState();
}



class _ConfigDialogContentState extends State<ConfigDialogContent> {
  TextEditingController soMauController = TextEditingController(text: globals.soLuongMau.toString());

  final Map<int, String> batdauOptions = {
    1: 'Khi ấn bắt đầu',
  };
  final Map<int, String> ketThucOptions = {
    1: 'Khi bấm stop',
    2: 'Theo khoảng thời gian',
    3: 'Theo số mẫu',
  };
  final Map<int, String> thoigianOptions = {
    50: '50ms',
    100: '100ms',
    200: '200ms',
    500: '500ms',
    1000: '1s',
    2000: '2s',
    5000: '5s',
    10000: '10s',
    60000: '1m',
    120000: '2m',
    300000: '5m',
  };
  Widget _buildSettingRow(MediaQueryData mediaQuery,
      {required String label, required Widget child}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: mediaQuery.size.width * 0.12,
          child: Text(
            label,
            style: TextStyle(
              fontSize: mediaQuery.size.width * 0.012,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
  Widget _buildDropdown<T>({
    required T value,
    required List items,
    required ValueChanged<T?> onChanged,
    double fontSize = 14,
  }) {
    return DropdownButton<T>(
      value: value,
      isDense: true,
      style: TextStyle(fontSize: fontSize),
      onChanged: onChanged,
      items: items.map<DropdownMenuItem<T>>((item) {
        if (item is MapEntry) {
          return DropdownMenuItem<T>(value: item.key, child: Text(item.value, style: TextStyle(fontSize: fontSize)));
        } else {
          return DropdownMenuItem<T>(value: item, child: Text(item.toString(), style: TextStyle(fontSize: fontSize)));
        }
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    var mediaQuery = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: mediaQuery.size.height * 0.6,
        width: mediaQuery.size.width * 0.35,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Material(
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tiêu đề (Cố định)
                Container(
                  width: double.infinity,
                  color: Color(globals.MyColors.mamau['xanhdatroi']!),
                  padding: EdgeInsets.symmetric(
                    vertical: mediaQuery.size.height * 0.008,
                    horizontal: mediaQuery.size.width * 0.012,
                  ),
                  child: Center(
                    child: AutoSizeText(
                      'Cài đặt',
                      style: TextStyle(
                        fontSize: mediaQuery.size.width * 0.01,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 1,
                      minFontSize: 10,
                    ),
                  ),
                ),

                // Nội dung scroll
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: mediaQuery.size.height * 0.0075,
                        horizontal: mediaQuery.size.width * 0.015,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tần số
                          _buildSettingRow(
                            mediaQuery,
                            label: 'Tần số',
                            child: DropdownButton<int>(
                              value: globals.tansolaymau == 1000 ? 1 : 1000 ~/ globals.tansolaymau,
                              items: [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000].map((hz) {
                                return DropdownMenuItem<int>(
                                  value: hz,
                                  child: Text('$hz Hz', style: TextStyle(color: Colors.black, fontSize: 12)),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  if (value != null) {
                                    globals.tansolaymau = value == 1 ? 1000 : 1000 ~/ value;
                                  }
                                });
                              },
                            ),
                          ),
                          SizedBox(height: mediaQuery.size.width * 0.0001),

                          // Bắt đầu
                          _buildSettingRow(
                            mediaQuery,
                            label: 'Bắt đầu',
                            child: DropdownButton<int>(
                              value: globals.selectedBatdau,
                              items: batdauOptions.entries.map((entry) {
                                return DropdownMenuItem<int>(
                                  value: entry.key,
                                  child: Text(entry.value, style: TextStyle(color: Colors.black, fontSize: 12)),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  globals.selectedBatdau = value!;
                                });
                              },
                            ),
                          ),
                          SizedBox(height: mediaQuery.size.width * 0.0001),

                          // Kết thúc
                          _buildSettingRow(
                            mediaQuery,
                            label: 'Kết thúc',
                            child: DropdownButton<int>(
                              value: globals.selectedKetThuc,
                              items: ketThucOptions.entries.map((entry) {
                                return DropdownMenuItem<int>(
                                  value: entry.key,
                                  child: Text(entry.value, style: TextStyle(color: Colors.black, fontSize: 12)),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  globals.selectedKetThuc = value!;
                                });
                              },
                            ),
                          ),
                          SizedBox(height: mediaQuery.size.width * 0.0001),

                          // Tùy chọn theo loại kết thúc
                          if (globals.selectedKetThuc == 3)
                            _buildSettingRow(
                              mediaQuery,
                              label: 'Số mẫu',
                              child: SizedBox(
                                width: 90,
                                child: TextField(
                                  controller: soMauController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(fontSize: 12, color: Colors.black),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  ),
                                ),
                              ),
                            )
                          else if (globals.selectedKetThuc == 2)
                            _buildSettingRow(
                              mediaQuery,
                              label: 'Thời gian',
                              child: DropdownButton<int>(
                                value: globals.selectedThoigianMs,
                                items: thoigianOptions.entries.map((entry) {
                                  return DropdownMenuItem<int>(
                                    value: entry.key,
                                    child: Text(entry.value, style: TextStyle(color: Colors.black, fontSize: 12)),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    globals.selectedThoigianMs = value!;
                                  });
                                },
                              ),
                            )
                          else
                            SizedBox.shrink(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: SizedBox(
          height: mediaQuery.size.height * 0.6,
          width: mediaQuery.size.width * 0.35,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Material(
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tiêu đề
                  Container(
                    width: double.infinity,
                    color: Color(globals.MyColors.mamau['xanhdatroi']!),
                    padding: EdgeInsets.symmetric(
                      vertical: mediaQuery.size.height * 0.008,
                      horizontal: mediaQuery.size.width * 0.012,
                    ),
                    child: Center(
                      child: AutoSizeText(
                        'Cài đặt',
                        style: TextStyle(
                          fontSize: mediaQuery.size.width * 0.01,
                          color: Colors.black, // 👈 màu đen
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                        maxLines: 1,
                        minFontSize: 10,
                      ),
                    ),
                  ),

                  // Nội dung
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: mediaQuery.size.height * 0.0075,
                      horizontal: mediaQuery.size.width * 0.015,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tần số
                        _buildSettingRow(
                          mediaQuery,
                          label: 'Tần số',
                          child: DropdownButton<int>(
                            value: globals.tansolaymau == 1000 ? 1 : 1000 ~/ globals.tansolaymau,
                            items: [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000].map((hz) {
                              return DropdownMenuItem<int>(
                                value: hz,
                                child: Text('$hz Hz', style: TextStyle(color: Colors.black, fontSize: 12)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                if (value != null) {
                                  globals.tansolaymau = value == 1 ? 1000 : 1000 ~/ value;
                                }
                              });
                            },
                          ),
                        ),
                        SizedBox(height: mediaQuery.size.width * 0.0001),

                        // Bắt đầu
                        _buildSettingRow(
                          mediaQuery,
                          label: 'Bắt đầu',
                          child: DropdownButton<int>(
                            value: globals.selectedBatdau,
                            items: batdauOptions.entries.map((entry) {
                              return DropdownMenuItem<int>(
                                value: entry.key,
                                child: Text(entry.value, style: TextStyle(color: Colors.black, fontSize: 12)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                globals.selectedBatdau = value!;
                              });
                            },
                          ),
                        ),
                        SizedBox(height: mediaQuery.size.width * 0.0001),

                        // Kết thúc
                        _buildSettingRow(
                          mediaQuery,
                          label: 'Kết thúc',
                          child: DropdownButton<int>(
                            value: globals.selectedKetThuc,
                            items: ketThucOptions.entries.map((entry) {
                              return DropdownMenuItem<int>(
                                value: entry.key,
                                child: Text(entry.value, style: TextStyle(color: Colors.black, fontSize: 12)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                globals.selectedKetThuc = value!;
                              });
                            },
                          ),
                        ),
                        SizedBox(height: mediaQuery.size.width * 0.0001),

                        // Tùy chọn theo loại kết thúc
                        if (globals.selectedKetThuc == 3)
                          _buildSettingRow(
                            mediaQuery,
                            label: 'Số mẫu',
                            child: SizedBox(
                              width: 90,
                              child: TextField(
                                controller: soMauController,
                                keyboardType: TextInputType.number,
                                style: TextStyle(fontSize: 12, color: Colors.black),
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                ),
                              ),
                            ),
                          )
                        else if (globals.selectedKetThuc == 2)
                          _buildSettingRow(
                            mediaQuery,
                            label: 'Thời gian',
                            child: DropdownButton<int>(
                              value: globals.selectedThoigianMs,
                              items: thoigianOptions.entries.map((entry) {
                                return DropdownMenuItem<int>(
                                  value: entry.key,
                                  child: Text(entry.value, style: TextStyle(color: Colors.black, fontSize: 12)),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  globals.selectedThoigianMs = value!;
                                });
                              },
                            ),
                          )
                        else
                          SizedBox.shrink(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    soMauController.addListener(() {
      final value = int.tryParse(soMauController.text);
      if (value != null) {
        setState(() {
          globals.soLuongMau = value;
        });
      }
    });
  }

  @override
  void dispose() {
    soMauController.dispose();
    super.dispose();
  }



}



