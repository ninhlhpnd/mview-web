class DulieuCB{
  String id;
  String tenCambien;
  List<double> giaTri;
  bool datLai;
  bool xoaCambien;
  DulieuCB({
    required this.id,
    required this.tenCambien,
    required this.giaTri,
    required this.datLai,
    required this.xoaCambien
});

  @override
  String toString() {
    String formattedValue = giaTri.map((e) => e.toStringAsFixed(2)).join(', ');
    return ('id: $id, ten: $tenCambien, giatri: [$formattedValue] , length: ${giaTri.length}, datLai: $datLai, xoaCambien: $xoaCambien');
  }
}