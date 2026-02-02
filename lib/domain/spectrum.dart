import 'dart:typed_data';

class Spectrum {
  Spectrum({required this.x, required this.y});

  final Float64List x;
  final Float64List y;

  int get length => x.length;
}
