class CambienHienthi {
  String id;
  String name;
  String? donvi;
  String? icon;
  List<double>? heso;
  List<int>? tanso;
  List<double>? daido;
  int? dophangiai;

  CambienHienthi(
      {required this.id,
      required this.name,
      this.donvi,
      this.icon,
      this.heso,
      this.tanso,
      this.daido,
      this.dophangiai});
  @override
  String toString() {
    return 'CambienHienthi(id: $id, name: $name)';
  }
}
