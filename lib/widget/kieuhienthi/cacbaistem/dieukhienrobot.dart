import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mview/Model/dulieucambien.dart';
import 'package:mview/ultis/listcambien.dart' as globals;
import 'package:mview/widget/kieuhienthi/bocucbase.dart';
import 'package:mview/widget/kieuhienthi/cacbaistem/bdk_helper.dart' as sendData;

class StemDieuKhienRobot extends StatefulWidget {
  const StemDieuKhienRobot({super.key, required this.stream, required this.tenbaihoc});

  final Stream<DulieuCB> stream;
  final String tenbaihoc;

  @override
  State<StemDieuKhienRobot> createState() => _StemDieuKhienRobotState();
}

class _StemDieuKhienRobotState extends State<StemDieuKhienRobot> {
  bool isLightOn = false;
  bool isHornOn = false;
  
  double speed = 150; // Tốc độ (0-255)
  
  // Dữ liệu cảm biến nhận được
  String nhietdo = "--";
  String doam = "--";
  String dosang = "--";
  String khoangcach = "--";

  // Trạng thái các nút di chuyển
  String currentMove = ""; 
  StreamSubscription<DulieuCB>? _streamSubscription;

  @override
  void initState() {
    super.initState();
    _streamSubscription = widget.stream.listen((dulieu) {
      if (dulieu.tenCambien == "CAR_DATA" && dulieu.rawData != null) {
        _parseCarData(dulieu.rawData!.trim());
      }
    });
  }

  String lastRawData = "";

  void _parseCarData(String data) {
    if (data.isEmpty) return;
    debugPrint("📥 Raw Car Data: $data");
    setState(() {
      lastRawData = data;
    });
    // Dữ liệu có dạng: Nhiệt độ|Độ ẩm|Độ sáng|Khoảng cách
    List<String> parts = data.split('|');
    if (parts.length >= 4) {
      setState(() {
        nhietdo = parts[0];
        doam = parts[1];
        dosang = parts[2];
        khoangcach = parts[3];
      });
    }
  }

  void _sendCommand(String cmd) {
    String fullCmd = "$cmd\n";
    sendData.writeStringData(fullCmd);
    debugPrint("Car Command: $fullCmd");
  }

  void _startMoving(String direction) {
    if (currentMove == direction) return;
    currentMove = direction;
    
    int intSpeed = speed.toInt();
    if (direction == "UP") _sendCommand("tien=$intSpeed");
    if (direction == "DOWN") _sendCommand("lui=$intSpeed");
    if (direction == "LEFT") _sendCommand("trai=$intSpeed");
    if (direction == "RIGHT") _sendCommand("phai=$intSpeed");
    
    setState(() {});
  }

  void _stopMoving() {
    if (currentMove != "") {
      _sendCommand("dung="); 
      // Gửi lần 2 sau 50ms để đảm bảo robot nhận được (theo code mẫu)
      Future.delayed(const Duration(milliseconds: 50), () {
        _sendCommand("dung=");
      });
      currentMove = "";
    }
    setState(() {});
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        toolbarHeight: 35,
        title: Text(
          widget.tenbaihoc,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Nếu chiều rộng màn hình nhỏ hơn 700 (điện thoại portrait)
          if (constraints.maxWidth < 700) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildSensorPanel(isFullWidth: true),
                  _buildControlPanel(isFullWidth: true),
                ],
              ),
            );
          } else {
            // Cho máy tính bảng hoặc màn hình ngang
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: SingleChildScrollView(child: _buildSensorPanel(isFullWidth: false))),
                Expanded(flex: 6, child: SingleChildScrollView(child: _buildControlPanel(isFullWidth: false))),
              ],
            );
          }
        },
      ),
    );
  }

  // Panel hiển thị cảm biến
  Widget _buildSensorPanel({required bool isFullWidth}) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("DỮ LIỆU CẢM BIẾN", 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueAccent)),
          const SizedBox(height: 15),
          _buildSensorItem(Icons.thermostat, "Nhiệt độ", nhietdo, "°C"),
          _buildSensorItem(Icons.water_drop, "Độ ẩm", doam, "%"),
          _buildSensorItem(Icons.light_mode, "Độ sáng", dosang, "lux"),
          _buildSensorItem(Icons.settings_input_antenna, "Khoảng cách", khoangcach, "cm"),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "Raw: $lastRawData",
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _sendCommand("start_notify"),
            icon: const Icon(Icons.refresh),
            label: const Text("Đọc Dữ Liệu"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent, 
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
            ),
          ),
        ],
      ),
    );
  }

  // Panel điều khiển robot
  Widget _buildControlPanel({required bool isFullWidth}) {
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thanh tốc độ
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const Icon(Icons.speed, color: Colors.blueAccent),
                  const SizedBox(width: 10),
                  Text("Tốc độ: ${(speed * 100 / 255).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Slider(
                      value: speed,
                      min: 0,
                      max: 255,
                      activeColor: Colors.blueAccent,
                      onChanged: (val) => setState(() => speed = val),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // D-Pad
          _buildDPad(),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 20),
          // Nhóm nút chức năng
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _buildActionButton(
                icon: Icons.lightbulb,
                label: isLightOn ? "Tắt Đèn" : "Bật Đèn",
                isActive: isLightOn,
                onPressed: () {
                  setState(() => isLightOn = !isLightOn);
                  _sendCommand(isLightOn ? "ledon=" : "ledoff=");
                },
              ),
              _buildActionButton(
                icon: Icons.volume_up,
                label: isHornOn ? "Tắt Còi" : "Bật Còi",
                isActive: isHornOn,
                onPressed: () {
                  setState(() => isHornOn = !isHornOn);
                  _sendCommand(isHornOn ? "coion=" : "coioff=");
                },
              ),
              _buildActionButton(
                icon: Icons.pan_tool,
                label: "Kẹp",
                onPressed: () => _sendCommand("kep="),
              ),
              _buildActionButton(
                icon: Icons.front_loader,
                label: "Nhả",
                onPressed: () => _sendCommand("nha="),
              ),
              _buildActionButton(
                icon: Icons.arrow_upward,
                label: "Nâng",
                onPressed: () => _sendCommand("nang="),
              ),
              _buildActionButton(
                icon: Icons.arrow_downward,
                label: "Hạ",
                onPressed: () => _sendCommand("ha="),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSensorItem(IconData icon, String label, String value, String unit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text("$value $unit", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDPad() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: _buildMoveButton(Icons.keyboard_arrow_up, "UP"),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildMoveButton(Icons.keyboard_arrow_down, "DOWN"),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: _buildMoveButton(Icons.keyboard_arrow_left, "LEFT"),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _buildMoveButton(Icons.keyboard_arrow_right, "RIGHT"),
          ),
          Center(
            child: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons. videogame_asset, color: Colors.grey, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoveButton(IconData icon, String direction) {
    bool isPressed = currentMove == direction;
    return GestureDetector(
      onTapDown: (_) => _startMoving(direction),
      onTapUp: (_) => _stopMoving(),
      onTapCancel: () => _stopMoving(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 65,
        height: 65,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          gradient: isPressed 
            ? const LinearGradient(colors: [Colors.blue, Colors.blueAccent])
            : LinearGradient(colors: [Colors.white, Colors.grey[50]!]),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: isPressed ? Colors.blue.withOpacity(0.3) : Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 35,
          color: isPressed ? Colors.white : Colors.blueAccent,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 110,
      height: 45,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: isActive ? Colors.white : Colors.blueAccent, size: 16),
        label: Text(label, style: TextStyle(
          color: isActive ? Colors.white : Colors.black87,
          fontSize: 11,
          fontWeight: FontWeight.bold
        )),
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? Colors.redAccent : Colors.white,
          foregroundColor: Colors.blueAccent,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
      ),
    );
  }
}
