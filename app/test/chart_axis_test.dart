import 'package:flutter_test/flutter_test.dart';
import 'package:wealth_tracker/core/utils/chart_axis.dart';
import 'package:wealth_tracker/core/utils/formatters.dart';

void main() {
  group('niceAxis', () {
    test('produces exactly 4 intervals with nice steps', () {
      final axis = niceAxis(0, 31000);
      expect(axis.min, 0);
      expect(axis.interval, 10000);
      expect(axis.max, 40000);
    });

    test('covers the value range', () {
      for (final max in [1.0, 950.0, 31000.0, 2825058.0, 9e7]) {
        final axis = niceAxis(0, max);
        expect(axis.max, greaterThanOrEqualTo(max));
        expect(((axis.max - axis.min) / axis.interval).round(), 4);
      }
    });
  });

  group('formatChartAxisValue with nice steps', () {
    /// The axis tick labels for a 0..max range.
    List<String> labelsFor(double max) {
      final axis = niceAxis(0, max);
      final labels = <String>[];
      for (var v = axis.min; v <= axis.max + 1e-9; v += axis.interval) {
        labels.add(formatChartAxisValue(v, step: axis.interval));
      }
      return labels;
    }

    test('labels are unique — no duplicated tick text', () {
      for (final max in [950.0, 31000.0, 2825058.0, 9e7, 12345.0]) {
        final labels = labelsFor(max);
        expect(labels.toSet().length, labels.length,
            reason: 'duplicate labels for range 0..$max: $labels');
      }
    });

    test('fractional steps use the SMALLEST uniform decimal count', () {
      // Step 2.5M needs only 1 decimal: "2.5M"… "10.0M", never "10.00M".
      expect(formatChartAxisValue(2500000, step: 2500000), '2.5M');
      expect(formatChartAxisValue(7500000, step: 2500000), '7.5M');
      expect(formatChartAxisValue(10000000, step: 2500000), '10.0M');
      // Whole-unit steps stay integer.
      expect(formatChartAxisValue(2000000, step: 1000000), '2M');
      expect(formatChartAxisValue(30000, step: 10000), '30K');
      // Mixed-unit axis: the K tick below 1M still formats in K.
      expect(formatChartAxisValue(500000, step: 250000), '500K');
      // A step needing hundredths gets 2 decimals.
      expect(formatChartAxisValue(1250000, step: 1250000), '1.25M');
    });
  });


  group('stripLeadingIban', () {
    test('strips a valid German IBAN prefix', () {
      expect(stripLeadingIban('DE89370400440532013000MAX MUSTERMANN'),
          'MAX MUSTERMANN');
    });

    test('keeps strings without an IBAN untouched', () {
      expect(stripLeadingIban('GOOGLE SWITZERLAND GMBH'),
          'GOOGLE SWITZERLAND GMBH');
      expect(stripLeadingIban('Praxis Dr. med. dent. Beispiel'),
          'Praxis Dr. med. dent. Beispiel');
    });

    test('rejects an invalid checksum even when the shape matches', () {
      // Same as the valid IBAN but with one digit flipped.
      const broken = 'DE89370400440532013001WERTGARANTIE';
      expect(stripLeadingIban(broken), broken);
    });

    test('pure-IBAN counterparty becomes empty', () {
      expect(stripLeadingIban('DE57120300001015708611'), '');
    });
  });
}
