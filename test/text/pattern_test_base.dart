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
import 'pattern_test_data.dart';
import 'text_cursor_test_base_tests.dart';

/// Base class for all the pattern tests (when we've migrated OffsetPattern off FormattingTestSupport).
/// Derived classes should have internal static fields with the names listed in the TestCaseSource
/// attributes here: InvalidPatternData, ParseFailureData, ParseData, FormatData. Any field
/// which is missing causes that test to be "not runnable" for that concrete subclass.
/// If a test isn't appropriate (e.g. there's no configurable pattern) just provide a property with
/// an array containing a null value - that will be ignored.
abstract class PatternTestBase<T>
{
  @Test()
  @TestCaseSource(#InvalidPatternData)
  void InvalidPatterns(PatternTestData<T> data)
  {
    data?.TestInvalidPattern();
  }

  @Test()
  @TestCaseSource(#ParseFailureData)
  void ParseFailures(PatternTestData<T> data)
  {
    data?.TestParseFailure();
  }

  @Test()
  @TestCaseSource(#ParseData)
  void Parse(PatternTestData<T> data)
  {
    data?.TestParse();
  }

  @Test()
  @TestCaseSource(#FormatData)
  void Format(PatternTestData<T> data)
  {
    data?.TestFormat();
  }

  // Testing this for every item is somewhat overkill, but not too slow.
  @Test()
  @TestCaseSource(#FormatData)
  void AppendFormat(PatternTestData<T> data)
  {
    data?.TestAppendFormat();
  }

  void AssertRoundTrip(T value, IPattern<T> pattern)
  {
    String text = pattern.format(value);
    var parseResult = pattern.parse(text);
    expect(value, parseResult.value);
  }

  void AssertParseNull(IPattern<T> pattern)
  {
    var result = pattern.parse(null);
    expect(result.success, isFalse);
    // Assert.IsInstanceOf<ArgumentNullException>(result.Exception);
    expect(result.error, new isInstanceOf<ArgumentError>());
  }
}


