library testproject.globals;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:testproject/Model/sodocambien.dart';

import '../Model/cambien.dart';
import '../Model/cambienhienthi.dart';
List<Cambien> cambiens = [
  (Cambien(
    id: 'Temp',
    name: 'Nhiệt độ',
    icon: 'assets/icons/temp.jpg',
    donvi: ['°C', '°F', '°K'],
    daido: [-20, 130],
    dophangiai: 2,
    heso: [
      [1, 0],
      [1.8, 32],
      [1, 273]
    ],
  )),
  (Cambien(
    id: 'Humid',
    name: 'Độ ẩm',
    icon: 'assets/icons/humid.jpg',
    donvi: ['%'],
    daido: [0, 100],
    dophangiai: 1,
    heso: [
      [1, 0]
    ],
  )),
  (Cambien(
    id: 'Pressure',
    name: 'Áp suất',
    icon: 'assets/icons/pressure.jpg',
    donvi: ["kPa", "bar", "mmHg"],
    daido: [0, 300],
    dophangiai: 2,
    heso: [
      [1, 0],
      [0.01, 0],
      [7.5, 0]
    ],
  )),
  (Cambien(
    id: 'Oxygen',
    name: 'Nồng độ Oxy',
    icon: 'assets/icons/oxygen.jpg',
    donvi: ['%'],
    daido: [0, 30],
    dophangiai: 1,
    heso: [
      [1, 0]
    ],
  )),
  (Cambien(
    id: 'CO2',
    name: 'Nồng độ CO2',
    icon: 'assets/icons/co2.jpg',
    donvi: ["ppm", "ppt"],
    daido: [0, 50000],
    dophangiai: 0,
    heso: [
      [1, 0],
      [0.001, 0]
    ],
  )),
  (Cambien(
    id: 'SoundI',
    name: 'Cường độ âm thanh',
    icon: 'assets/icons/soundi.jpg',
    donvi: ['dB'],
    daido: [0, 130],
    dophangiai: 1,
    heso: [
      [1, 0]
    ],
  )),
  (Cambien(
    id: 'PH',
    name: 'pH',
    icon: 'assets/icons/ph.jpg',
    donvi: [''],
    daido: [0, 14],
    dophangiai: 2,
    heso: [
      [1, 0]
    ],
  )),
  (Cambien(
    id: 'Salinity',
    name: 'Nồng độ muối',
    icon: 'assets/icons/salinity.jpg',
    donvi: ['ppt'],
    daido: [0, 50],
    dophangiai: 2,
    heso: [
      [1, 0]
    ],
  )),
  (Cambien(
    id: 'DissolveOxy',
    name: 'Nồng độ oxy trong nước',
    icon: 'assets/icons/dissolved.jpg',
    donvi: ['mg/l'],
    daido: [0, 20],
    dophangiai: 2,
    heso: [
      [1, 0]
    ],
  )),
  (Cambien(
    id: 'Force',
    name: 'Lực',
    icon: 'assets/icons/force.jpg',
    donvi: ['N', 'mN'],
    daido: [-50, 50],
    dophangiai: 2,
    heso: [
      [1, 0],
      [0.001, 0]
    ],
  )),
  (Cambien(
    id: 'Current',
    name: 'Dòng điện',
    icon: 'assets/icons/current.jpg',
    donvi: ['A', 'mA'],
    daido: [-2, 2],
    dophangiai: 3,
    heso: [
      [1, 0],
      [1000, 0]
    ],
  )),
  (Cambien(
    id: 'Voltage',
    name: 'Điện áp',
    icon: 'assets/icons/voltage.jpg',
    donvi: ['V', 'mV'],
    daido: [-24, 24],
    dophangiai: 2,
    heso: [
      [1, 0],
      [1000, 0]
    ],
  )),
  (Cambien(
    id: 'SoundF',
    name: 'Âm thanh',
    icon: 'assets/icons/soundf.jpg',
    donvi: ['Hz'],
    daido: [20, 20000],
    dophangiai: 1,
    heso: [
      [1, 0]
    ],
  )),
  (Cambien(
    id: 'Distance',
    name: 'Vị trí',
    icon: 'assets/icons/distance.jpg',
    donvi: ['cm', 'mm', 'm'],
    daido: [0, 400],
    dophangiai: 2,
    heso: [
      [1, 0],
      [10, 0],
      [0.01, 0]
    ],
  )),
  (Cambien(
    id: 'Conductivity',
    name: 'Độ dẫn',
    icon: 'assets/icons/conductivity.jpg',
    donvi: ['uS', 'mS'],
    daido: [0, 20000],
    dophangiai: 1,
    heso: [
      [1, 0],
      [0.001, 0]
    ],
  )),
  (Cambien(id: 'V&A', name: "Cảm biến dòng áp", icon: 'assets/icons/dongap.jpg')),
  (Cambien(id: 'Mlab', name: "Bộ điều khiển đa kênh", icon: 'assets/icons/bdkdakenh.jpg')),

];
final Map<String, List<int>> cambienMapping = {
  "V&A": [10, 11],
  "H&T": [1, 0],
  "P&T": [2, 0],
  // thêm tùy loại
};
class MyColors {
  static const Map<String, int> mamau = {
    'xanhnhat': 0xff002a68,
    'xam': 0xffdddddd,
    'xanhduongnhat': 0xff91BFE3,
    'doStop': 0xffEF3232,
    'xanhdam': 0xff2460A8,
    'bac': 0xffCCC7C7,
    'xanh': 0xff0033ff,
    'xanhdatroi': 0xFF1FB6FC
  };
}

List<SodoCambien> SodoCambienList = [];
List<SodoCambien> SodoCambienListHistory = [];
List<String> serviceUuid = ['4a5c0000-0000-0000-0000-5c1e741f1c00', '00004321-0000-1000-8000-00805f9b34fb','4321'];
List characteristicUuid = ['4a5c0000-0003-0000-0000-5c1e741f1c00', '00004320-0000-1000-8000-00805f9b34fb','4320'];
int tansolaymau = 1000;
const List<String> dPins = ['D3', 'D4', 'D5', 'D6'];
const List<String> sensors = ['A1', 'A2', 'S1', 'S2', 'S3'];
List<String> lession=[
  'Nhà kính thông minh',
  'Lò sấy nông sản',
  'Lên men sữa chua'
];

List<String> scanFilter = [
  'Temp',
  'Humid',
  'Pressure',
  'Oxygen',
  'CO2',
  'SoundI',
  'PH',
  'Salinity',
  'DissolveOxy',
  'Force',
  'Current',
  'Voltage',
  'SoundF',
  'Distance',
  'Conductivity',
  'V&A',
  'Mlab'
];
int selectedBatdau = 1;
int selectedKetThuc = 1;
int selectedThoigianMs = 1000;
int soLuongMau = 100;
int soLuongCount = 0;
bool isStartPress = false;
ValueNotifier<bool> requestOff = ValueNotifier<bool>(false);
late List<Color> listMamau = [
  Colors.blue,
  Colors.red,
  Colors.black,
  Colors.green,
  Colors.purple,
  Colors.amber,
  Colors.brown,
  Colors.cyanAccent,
  Colors.lime
];
ValueNotifier<bool> historyViewMode = ValueNotifier<bool>(false);
Map historySelected = {};
ValueNotifier<bool> clearData = ValueNotifier<bool>(false);
late List<Color> listColorCambien = [
  ];
