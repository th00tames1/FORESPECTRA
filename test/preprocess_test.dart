import 'dart:typed_data';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spectral_app/domain/preprocess.dart';
import 'package:spectral_app/domain/spectrum.dart';

Spectrum _spec(List<double> x, List<double> y) => Spectrum(
  x: Float64List.fromList(x),
  y: Float64List.fromList(y),
);

void main() {
  group('smoothMovingAverage', () {
    test('flattens noise in a constant signal', () {
      final input = _spec(
        [1, 2, 3, 4, 5],
        [1.0, 1.1, 0.9, 1.05, 0.95],
      );
      final out = smoothMovingAverage(input, 5);
      for (final v in out.y) {
        expect((v - 1.0).abs(), lessThan(0.1));
      }
    });

    test('preserves length', () {
      final input = _spec([1, 2, 3], [1, 2, 3]);
      expect(smoothMovingAverage(input, 3).length, 3);
    });
  });

  group('standardNormalVariate', () {
    test('mean ~ 0, std ~ 1 after SNV', () {
      final input = _spec(
        [1, 2, 3, 4, 5],
        [5.0, 10.0, 15.0, 20.0, 25.0],
      );
      final out = standardNormalVariate(input);
      final mean = out.y.reduce((a, b) => a + b) / out.length;
      expect(mean.abs(), lessThan(1e-9));
      var v = 0.0;
      for (final y in out.y) {
        v += (y - mean) * (y - mean);
      }
      final std = sqrt(v / out.length);
      expect((std - 1.0).abs(), lessThan(1e-9));
    });

    test('zero-variance input maps to zeros', () {
      final input = _spec([1, 2, 3], [4.0, 4.0, 4.0]);
      final out = standardNormalVariate(input);
      for (final y in out.y) {
        expect(y, 0.0);
      }
    });
  });

  group('baselineCorrect', () {
    test('subtracts a straight-line baseline', () {
      // y = 2x + 3 is itself the baseline. Result should be zero.
      final input = _spec([0, 1, 2, 3], [3, 5, 7, 9]);
      final out = baselineCorrect(input);
      for (final y in out.y) {
        expect(y.abs(), lessThan(1e-9));
      }
    });

    test('preserves a bump on top of a slope', () {
      // baseline = 0→2 (slope 0.5 over x 0→4), bump at middle.
      final input = _spec([0, 1, 2, 3, 4], [0.0, 0.5, 2.0, 1.5, 2.0]);
      final out = baselineCorrect(input);
      expect(out.y.first.abs(), lessThan(1e-9));
      expect(out.y.last.abs(), lessThan(1e-9));
      expect(out.y[2], greaterThan(0.5));
    });
  });

  group('derivative', () {
    test('first derivative of a linear ramp is constant', () {
      final input = _spec([0, 1, 2, 3, 4], [0, 1, 2, 3, 4]);
      final out = derivative(input, order: 1);
      for (final y in out.y) {
        expect((y - 1.0).abs(), lessThan(1e-9));
      }
    });

    test('second derivative of a parabola is constant', () {
      final input = _spec(
        [0, 1, 2, 3, 4, 5, 6],
        [0, 1, 4, 9, 16, 25, 36],
      );
      final out = derivative(input, order: 2);
      // Interior points should approximate 2 (d²/dx² x²).
      for (var i = 2; i < out.length - 2; i++) {
        expect((out.y[i] - 2.0).abs(), lessThan(0.5));
      }
    });
  });

  group('savitzkyGolay', () {
    test('identity-like for low-order polynomial input', () {
      final input = _spec(
        List.generate(11, (i) => i.toDouble()),
        List.generate(11, (i) => i.toDouble()),
      );
      final out = savitzkyGolay(
        input,
        windowLength: 5,
        polyorder: 2,
        derivativeOrder: 0,
      );
      // Linear data should pass through almost unchanged.
      for (var i = 2; i < input.length - 2; i++) {
        expect((out.y[i] - input.y[i]).abs(), lessThan(1e-9));
      }
    });

    test('first derivative of x is ~1', () {
      final input = _spec(
        List.generate(11, (i) => i.toDouble()),
        List.generate(11, (i) => i.toDouble()),
      );
      final out = savitzkyGolay(
        input,
        windowLength: 5,
        polyorder: 2,
        derivativeOrder: 1,
      );
      for (var i = 2; i < input.length - 2; i++) {
        expect((out.y[i] - 1.0).abs(), lessThan(1e-9));
      }
    });

    test('coerces even window to odd', () {
      final input = _spec(
        List.generate(15, (i) => i.toDouble()),
        List.generate(15, (i) => i.toDouble()),
      );
      // window=6 should be bumped to 7; should not throw.
      expect(
        () => savitzkyGolay(input, windowLength: 6, polyorder: 2),
        returnsNormally,
      );
    });

    test('reproduces a degree-2 polynomial exactly at the edges (interp mode)',
        () {
      // A quadratic lies in the polyorder-2 fit space, so scipy mode='interp'
      // reproduces it EXACTLY everywhere - including the first/last `half`
      // channels. Reflect padding does not, so this pins the boundary fix.
      double poly(int i) => 0.5 * i * i - 2.0 * i + 3.0;
      final x = List.generate(21, (i) => i.toDouble());
      final y = List.generate(21, (i) => poly(i));
      final out = savitzkyGolay(
        _spec(x, y),
        windowLength: 11,
        polyorder: 2,
        derivativeOrder: 0,
      );
      for (var i = 0; i < out.length; i++) {
        expect((out.y[i] - poly(i)).abs(), lessThan(1e-6),
            reason: 'edge/interior smoothing diverged at index $i');
      }
    });

    test('first derivative of a quadratic is exact at the edges (interp mode)',
        () {
      // d/di (0.5 i^2 - 2 i + 3) = i - 2, with unit sample spacing.
      double dpoly(int i) => i - 2.0;
      final x = List.generate(21, (i) => i.toDouble());
      final y = List.generate(21, (i) => 0.5 * i * i - 2.0 * i + 3.0);
      final out = savitzkyGolay(
        _spec(x, y),
        windowLength: 11,
        polyorder: 2,
        derivativeOrder: 1,
      );
      for (var i = 0; i < out.length; i++) {
        expect((out.y[i] - dpoly(i)).abs(), lessThan(1e-6),
            reason: 'edge/interior derivative diverged at index $i');
      }
    });
  });

  group('applyPreprocessing', () {
    test('applies steps in order', () {
      final input = _spec(
        [0, 1, 2, 3, 4],
        [10.0, 12.0, 14.0, 16.0, 18.0],
      );
      final out = applyPreprocessing(input, [
        {'type': 'baseline'},
        {'type': 'snv'},
      ]);
      // After baseline removal of perfect linear ramp -> zeros.
      // After SNV on zero-variance -> still zeros.
      for (final y in out.y) {
        expect(y, 0.0);
      }
    });
  });
}
