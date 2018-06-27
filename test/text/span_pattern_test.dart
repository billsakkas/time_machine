// Portions of this work are Copyright 2018 The Time Machine Authors. All rights reserved.
// Portions of this work are Copyright 2018 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0, as found in the LICENSE.txt file.

import 'dart:async';
import 'dart:math' as math;
import 'dart:mirrors';

import 'package:time_machine/src/time_machine_internal.dart';
import 'package:time_machine/src/calendars/time_machine_calendars.dart';
import 'package:time_machine/src/text/globalization/time_machine_globalization.dart';
import 'package:time_machine/src/text/patterns/time_machine_patterns.dart';
import 'package:time_machine/src/text/time_machine_text.dart';
import 'package:time_machine/src/utility/time_machine_utilities.dart';

import 'package:test/test.dart';
import 'package:matcher/matcher.dart';
import 'package:time_machine/src/timezones/time_machine_timezones.dart';

import '../time_machine_testing.dart';
import 'pattern_test_base.dart';
import 'pattern_test_data.dart';
import 'test_cultures.dart';
import 'text_cursor_test_base_tests.dart';

Future main() async {
  await runTests();
}

@Test()
class SpanPatternTest extends PatternTestBase<Span> {
  /// Test data that can only be used to test formatting.
  @internal  final List<Data> FormatOnlyData = [
    // No sign, so we can't parse it.
    new Data.hm(-1, 0)
      ..Pattern = "HH:mm"
      ..text = "01:00",

    // Loss of nano precision
    new Data.dhmsn(1, 2, 3, 4, 123456789)
      ..Pattern = "D:hh:mm:ss.ffff"
      ..text = "1:02:03:04.1234",
    new Data.dhmsn(1, 2, 3, 4, 123456789)
      ..Pattern = "D:hh:mm:ss.FFFF"
      ..text = "1:02:03:04.1234",
  ];

  /// Test data that can only be used to test successful parsing.
  @internal  final List<Data> ParseOnlyData = [];

  /// Test data for invalid patterns
  @internal  final List<Data> InvalidPatternData = [
    new Data()
      ..Pattern = ""
      ..Message = TextErrorMessages.formatStringEmpty,
    new Data()
      ..Pattern = "HH:MM"
      ..Message = TextErrorMessages.multipleCapitalSpanFields,
    new Data()
      ..Pattern = "HH D"
      ..Message = TextErrorMessages.multipleCapitalSpanFields,
    new Data()
      ..Pattern = "MM mm"
      ..Message = TextErrorMessages.repeatedFieldInPattern
      ..Parameters.addAll(['m']),
    new Data()
      ..Pattern = "G"
      ..Message = TextErrorMessages.unknownStandardFormat
      ..Parameters.addAll(['G', 'Span'])
  ];

  /// Tests for parsing failures (of values)
  @internal  final List<Data> ParseFailureData = [
    new Data(Span.zero)
      ..Pattern = "H:mm"
      ..text = "1:60"
      ..Message = TextErrorMessages.fieldValueOutOfRange
      ..Parameters.addAll([60, 'm', 'Span']),
    // Total field values out of range
    new Data(Span.minValue)
      ..Pattern = "-D:hh:mm:ss.fffffffff"
      ..text = "16777217:00:00:00.000000000"
      ..
      Message = TextErrorMessages.fieldValueOutOfRange
      ..Parameters.addAll(["16777217", 'D', 'Span']),
    new Data(Span.minValue)
      ..Pattern = "-H:mm:ss.fffffffff"
      ..text = "402653185:00:00.000000000"
      ..
      Message = TextErrorMessages.fieldValueOutOfRange
      ..Parameters.addAll(["402653185", 'H', 'Span']),
    new Data(Span.minValue)
      ..Pattern = "-M:ss.fffffffff"
      ..text = "24159191041:00.000000000"
      ..
      Message = TextErrorMessages.fieldValueOutOfRange
      ..Parameters.addAll(["24159191041", 'M', 'Span']),
    new Data(Span.minValue)
      ..Pattern = "-S.fffffffff"
      ..text = "1449551462401.000000000"
      ..
      Message = TextErrorMessages.fieldValueOutOfRange
      ..Parameters.addAll(["1449551462401", 'S', 'Span']),

  /* note: In Dart we don't go out of range -- todo: evaluate -- should we?
    // Each field in range, but overall result out of range
    new Data(Span.minValue)
      ..Pattern = "-D:hh:mm:ss.fffffffff"
      ..Text = "-16777216:00:00:00.000000001"
      ..Message = TextErrorMessages.OverallValueOutOfRange
      ..Parameters.addAll(['Span']),
    new Data(Span.maxValue)
      ..Pattern = "-D:hh:mm:ss.fffffffff"
      ..Text = "16777216:00:00:00.000000000"
      ..Message = TextErrorMessages.OverallValueOutOfRange
      ..Parameters.addAll(['Span']),
    new Data(Span.minValue)
      ..Pattern = "-H:mm:ss.fffffffff"
      ..Text = "-402653184:00:00.000000001"
      ..Message = TextErrorMessages.OverallValueOutOfRange
      ..Parameters.addAll(['Span']),
    new Data(Span.minValue)
      ..Pattern = "-H:mm:ss.fffffffff"
      ..Text = "402653184:00:00.000000000"
      ..Message = TextErrorMessages.OverallValueOutOfRange
      ..Parameters.addAll(['Span']),
    new Data(Span.minValue)
      ..Pattern = "-M:ss.fffffffff"
      ..Text = "-24159191040:00.000000001"
      ..Message = TextErrorMessages.OverallValueOutOfRange
      ..Parameters.addAll(['Span']),
    new Data(Span.minValue)
      ..Pattern = "-M:ss.fffffffff"
      ..Text = "24159191040:00.000000000"
      ..Message = TextErrorMessages.OverallValueOutOfRange
      ..Parameters.addAll(['Span']),
    new Data(Span.minValue)
      ..Pattern = "-S.fffffffff"
      ..Text = "-1449551462400.000000001"
      ..Message = TextErrorMessages.OverallValueOutOfRange
      ..Parameters.addAll(['Span']),
    new Data(Span.minValue)
      ..Pattern = "-S.fffffffff"
      ..Text = "1449551462400.000000000"
      ..Message = TextErrorMessages.OverallValueOutOfRange
      ..Parameters.addAll(['Span']),*/
    new Data(Span.minValue)
      ..Pattern = "'x'S"
      ..text = "x"
      ..Message = TextErrorMessages.mismatchedNumber
      ..Parameters.addAll(["S"])
  ];

  /// Common test data for both formatting and parsing. A test should be placed here unless is truly
  /// cannot be run both ways. This ensures that as many round-trip type tests are performed as possible.
  @internal  final List<Data> FormatAndParseData = [
    new Data.hm(1, 2)
      ..Pattern = "+HH:mm"
      ..text = "+01:02",
    new Data.hm(-1, -2)
      ..Pattern = "+HH:mm"
      ..text = "-01:02",
    new Data.hm(1, 2)
      ..Pattern = "-HH:mm"
      ..text = "01:02",
    new Data.hm(-1, -2)
      ..Pattern = "-HH:mm"
      ..text = "-01:02",

    new Data.hm(26, 3)
      ..Pattern = "D:h:m"
      ..text = "1:2:3",
    new Data.hm(26, 3)
      ..Pattern = "DD:hh:mm"
      ..text = "01:02:03",
    new Data.hm(242, 3)
      ..Pattern = "D:hh:mm"
      ..text = "10:02:03",

    new Data.hm(2, 3)
      ..Pattern = "H:mm"
      ..text = "2:03",
    new Data.hm(2, 3)
      ..Pattern = "HH:mm"
      ..text = "02:03",
    new Data.hm(26, 3)
      ..Pattern = "HH:mm"
      ..text = "26:03",
    new Data.hm(260, 3)
      ..Pattern = "HH:mm"
      ..text = "260:03",

    new Data.hms(2, 3, 4)
      ..Pattern = "H:mm:ss"
      ..text = "2:03:04",

    new Data.dhmsn(1, 2, 3, 4, 123456789)
      ..Pattern = "D:hh:mm:ss.fffffffff"
      ..text = "1:02:03:04.123456789",
    new Data.dhmsn(1, 2, 3, 4, 123456000)
      ..Pattern = "D:hh:mm:ss.fffffffff"
      ..text = "1:02:03:04.123456000",
    new Data.dhmsn(1, 2, 3, 4, 123456789)
      ..Pattern = "D:hh:mm:ss.FFFFFFFFF"
      ..text = "1:02:03:04.123456789",
    new Data.dhmsn(1, 2, 3, 4, 123456000)
      ..Pattern = "D:hh:mm:ss.FFFFFFFFF"
      ..text = "1:02:03:04.123456",
    new Data.hms(1, 2, 3)
      ..Pattern = "M:ss"
      ..text = "62:03",
    new Data.hms(1, 2, 3)
      ..Pattern = "MMM:ss"
      ..text = "062:03",

    new Data.dhmsn(0, 0, 1, 2, 123400000)
      ..Pattern = "SS.FFFF"
      ..text = "62.1234",

    new Data.dhmsn(1, 2, 3, 4, 123456789)
      ..Pattern = "D:hh:mm:ss.FFFFFFFFF"
      ..text = "1.02.03.04.123456789"
      ..Culture = TestCultures.DotTimeSeparator,

    // Roundtrip pattern is invariant; redundantly specify the culture to validate that it doesn't make a difference.
    new Data.dhmsn(1, 2, 3, 4, 123456789)
      ..StandardPattern = SpanPattern.roundtrip
      ..Pattern = "o"
      ..text = "1:02:03:04.123456789"
      ..Culture = TestCultures.DotTimeSeparator,
    new Data.dhmsn(-1, -2, -3, -4, -123456789)
      ..StandardPattern = SpanPattern.roundtrip
      ..Pattern = "o"
      ..text = "-1:02:03:04.123456789"
      ..Culture = TestCultures.DotTimeSeparator,

  // Extremes...
  /* todo: our extremes are different (could be different based on platform?)
    new Data(Span.minValue)
      ..Pattern = "-D:hh:mm:ss.fffffffff"
      ..Text = "-16777216:00:00:00.000000000",
    new Data(Span.maxValue)
      ..Pattern = "-D:hh:mm:ss.fffffffff"
      ..Text = "16777215:23:59:59.999999999",
    new Data(Span.minValue)
      ..Pattern = "-H:mm:ss.fffffffff"
      ..Text = "-402653184:00:00.000000000",
    new Data(Span.maxValue)
      ..Pattern = "-H:mm:ss.fffffffff"
      ..Text = "402653183:59:59.999999999",
    new Data(Span.minValue)
      ..Pattern = "-M:ss.fffffffff"
      ..Text = "-24159191040:00.000000000",
    new Data(Span.maxValue)
    new Data(Span.maxValue)
      ..Pattern = "-M:ss.fffffffff"
      ..Text = "24159191039:59.999999999",
    new Data(Span.minValue)
      ..Pattern = "-S.fffffffff"
      ..Text = "-1449551462400.000000000",
    new Data(Span.maxValue)
      ..Pattern = "-S.fffffffff"
      ..Text = "1449551462399.999999999",*/
  ];

  @internal Iterable<Data> get ParseData => [ParseOnlyData, FormatAndParseData].expand((x) => x);
  @internal Iterable<Data> get FormatData => [FormatOnlyData, FormatAndParseData].expand((x) => x);

  @Test()
  void ParseNull() => AssertParseNull(SpanPattern.roundtrip);

  @Test()
  void WithCulture() {
    var pattern = SpanPattern.createWithInvariantCulture("H:mm").withCulture(TestCultures.DotTimeSeparator);
    var text = pattern.format(new Span(minutes: 90));
    expect("1.30", text);
  }

  @Test()
  void CreateWithCurrentCulture() {
    CultureInfo.currentCulture = TestCultures.DotTimeSeparator;
        // using (CultureSaver.SetCultures(TestCultures.DotTimeSeparator))
        {
      var pattern = SpanPattern.createWithCurrentCulture("H:mm");
      var text = pattern.format(new Span(minutes: 90));
      expect("1.30", text);
    }
  }
}

/// A container for test data for formatting and parsing [Duration] objects.
/*sealed*/ class Data extends PatternTestData<Span> {
// Ignored anyway...
/*protected*/ @override Span get DefaultTemplate => Span.zero;


  Data([Span value = Span.zero]) : super(value);

  Data.hm(int hours, int minutes) : this(new Span(hours: hours) + new Span(minutes: minutes));

  Data.hms(int hours, int minutes, int seconds)
      : this(new Span(hours: hours) + new Span(minutes: minutes) + new Span(seconds: seconds));

  Data.dhmsn(int days, int hours, int minutes, int seconds, int nanoseconds)
      : this(new Span(hours: days * 24 + hours) + new Span(minutes: minutes) + new Span(seconds: seconds) + new Span(nanoseconds: nanoseconds));

  @internal
  @override
  IPattern<Span> CreatePattern() => SpanPattern.createWithCulture(super.Pattern, Culture);
}

