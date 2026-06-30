import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spectral_app/domain/averaging.dart';
import 'package:spectral_app/domain/spectrum.dart';

Spectrum _spec(List<double> x, List<double> y) => Spectrum(
  x: Float64List.fromList(x),
  y: Float64List.fromList(y),
);

void main() {
  group('averageSpectra', () {
    test('returns null for empty list', () {
      expect(averageSpectra(const []), isNull);
    });

    test('returns a deep copy for single spectrum', () {
      final s = _spec([1, 2, 3], [0.1, 0.2, 0.3]);
      final result = averageSpectra([s])!;
      expect(result.y, [0.1, 0.2, 0.3]);
      // Must not alias the input data.
      result.y[0] = 99;
      expect(s.y[0], 0.1);
    });

    test('mean averages element-wise', () {
      final a = _spec([1, 2, 3], [1.0, 2.0, 4.0]);
      final b = _spec([1, 2, 3], [3.0, 4.0, 6.0]);
      final result = averageSpectra([a, b])!;
      expect(result.y[0], 2.0);
      expect(result.y[1], 3.0);
      expect(result.y[2], 5.0);
    });

    test('median averages element-wise', () {
      final a = _spec([1, 2, 3], [1.0, 100.0, 5.0]);
      final b = _spec([1, 2, 3], [2.0, 3.0, 6.0]);
      final c = _spec([1, 2, 3], [3.0, 4.0, 7.0]);
      final result = averageSpectra(
        [a, b, c],
        method: AveragingMethod.median,
      )!;
      expect(result.y[0], 2.0);
      // 100 outlier rejected in favor of 4 (middle of 3,4,100).
      expect(result.y[1], 4.0);
      expect(result.y[2], 6.0);
    });

    test('median with even count averages the two middle values', () {
      final spectra = [
        _spec([1], [1.0]),
        _spec([1], [2.0]),
        _spec([1], [3.0]),
        _spec([1], [4.0]),
      ];
      final result = averageSpectra(
        spectra,
        method: AveragingMethod.median,
      )!;
      expect(result.y[0], 2.5);
    });

    test('truncates to shortest spectrum length', () {
      final a = _spec([1, 2, 3, 4], [1.0, 1.0, 1.0, 1.0]);
      final b = _spec([1, 2], [2.0, 2.0]);
      final result = averageSpectra([a, b])!;
      expect(result.length, 2);
      expect(result.y, [1.5, 1.5]);
    });

    test('trimmed mean drops the most-deviant scans before averaging', () {
      // 5 scans of a flat 10.0 signal; scan index 0 and 4 are gross outliers
      // (one way high, one way low). Trimmed mean should drop both and average
      // the three clean 10.0 scans.
      final spectra = [
        _spec([1, 2], [10.0, 1000.0]), // outlier high
        _spec([1, 2], [10.0, 10.0]),
        _spec([1, 2], [10.0, 10.0]),
        _spec([1, 2], [10.0, 10.0]),
        _spec([1, 2], [10.0, -1000.0]), // outlier low
      ];
      final result = averageSpectra(
        spectra,
        method: AveragingMethod.trimmedMean,
      )!;
      expect(result.y[0], closeTo(10.0, 1e-9));
      // The two ±1000 outliers are dropped; only clean 10.0 scans remain.
      expect(result.y[1], closeTo(10.0, 1e-9));
    });

    test('trim drop count is configurable', () {
      // 5 scans: index 0 way high, index 4 way low, rest clean 10.0.
      final spectra = [
        _spec([1], [1000.0]),
        _spec([1], [10.0]),
        _spec([1], [10.0]),
        _spec([1], [10.0]),
        _spec([1], [-1000.0]),
      ];
      // Drop only the single worst (the most-deviant of ±1000).
      final dropOne = averageSpectra(
        spectra,
        method: AveragingMethod.trimmedMean,
        trimDrop: 1,
      )!;
      // Four scans remain incl. one ±1000 outlier => average is pulled off 10.
      expect((dropOne.y[0] - 10.0).abs(), greaterThan(100.0));
      // Drop both outliers => clean 10.0.
      final dropTwo = averageSpectra(
        spectra,
        method: AveragingMethod.trimmedMean,
        trimDrop: 2,
      )!;
      expect(dropTwo.y[0], closeTo(10.0, 1e-9));
    });

    test('clampTrimDrop keeps at least 2 scans', () {
      expect(clampTrimDrop(1, 5), 0);
      expect(clampTrimDrop(2, 5), 0);
      expect(clampTrimDrop(3, 5), 1); // max drop for 3 is 1
      expect(clampTrimDrop(5, 2), 2);
      expect(clampTrimDrop(5, 99), 3); // capped at n-2
      expect(clampTrimDrop(5, -1), 0);
    });

    test('trimmed mean with too few scans falls back to plain mean', () {
      final a = _spec([1], [2.0]);
      final b = _spec([1], [4.0]);
      final result = averageSpectra(
        [a, b],
        method: AveragingMethod.trimmedMean,
      )!;
      expect(result.y[0], 3.0);
    });

    test('mean improves SNR - zero-mean noise cancels', () {
      // 10 noisy versions of a constant 1.0 signal with symmetric ±noise
      // around index 4.5 so the average noise is exactly zero.
      final noisy = List.generate(
        10,
        (i) => _spec(
          [1, 2, 3],
          [
            1.0 + 0.1 * (i - 4.5),
            1.0 - 0.05 * (i - 4.5),
            1.0 + 0.08 * (i - 4.5),
          ],
        ),
      );
      final result = averageSpectra(noisy)!;
      for (final v in result.y) {
        expect((v - 1.0).abs(), lessThan(1e-9));
      }
    });
  });

  group('AveragingMethodLabel', () {
    test('id round-trip', () {
      expect(
        AveragingMethodLabel.fromId(AveragingMethod.mean.id),
        AveragingMethod.mean,
      );
      expect(
        AveragingMethodLabel.fromId(AveragingMethod.median.id),
        AveragingMethod.median,
      );
      expect(
        AveragingMethodLabel.fromId(AveragingMethod.trimmedMean.id),
        AveragingMethod.trimmedMean,
      );
    });

    test('fromId defaults to mean on unknown', () {
      expect(AveragingMethodLabel.fromId('bogus'), AveragingMethod.mean);
      expect(AveragingMethodLabel.fromId(null), AveragingMethod.mean);
    });
  });
}
