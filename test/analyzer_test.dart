import 'package:flutter_test/flutter_test.dart';
import 'package:spectral_app/domain/analyzer.dart';

void main() {
  group('interpolate', () {
    test('returns ys.first for x <= xs.first', () {
      expect(interpolate([1, 2, 3], [10, 20, 30], 0), 10);
      expect(interpolate([1, 2, 3], [10, 20, 30], 1), 10);
    });

    test('returns ys.last for x >= xs.last', () {
      expect(interpolate([1, 2, 3], [10, 20, 30], 3), 30);
      expect(interpolate([1, 2, 3], [10, 20, 30], 100), 30);
    });

    test('linearly interpolates between two known points', () {
      expect(interpolate([0, 10], [0, 100], 5), 50);
      expect(interpolate([0, 10], [0, 100], 2.5), 25);
    });

    test('handles segments correctly across breakpoints', () {
      final xs = [0.0, 1.0, 3.0, 6.0];
      final ys = [0.0, 10.0, 30.0, 60.0];
      expect(interpolate(xs, ys, 0.5), 5.0);
      expect(interpolate(xs, ys, 2.0), 20.0);
      expect(interpolate(xs, ys, 4.5), 45.0);
    });

    test('empty inputs returns 0', () {
      expect(interpolate([], [], 5), 0);
    });
  });
}
