// Portions of this work are Copyright 2018 The Time Machine Authors. All rights reserved.
// Portions of this work are Copyright 2018 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0, as found in the LICENSE.txt file.

import 'dart:async';
import 'dart:math' as math;

import 'package:time_machine/src/time_machine_internal.dart';
import 'package:time_machine/src/calendars/time_machine_calendars.dart';
import 'package:time_machine/src/utility/time_machine_utilities.dart';

import 'package:test/test.dart';
import 'package:matcher/matcher.dart';
import 'package:time_machine/src/timezones/time_machine_timezones.dart';

import '../time_machine_testing.dart';

Future main() async {
  await runTests();
}

@Test()
void LeapYears()
{
  var calendar = CalendarSystem.gregorian;
  expect(calendar.isLeapYear(1900), isFalse);
  expect(calendar.isLeapYear(1901), isFalse);
  expect(calendar.isLeapYear(1904), isTrue);
  expect(calendar.isLeapYear(1996), isTrue);
  expect(calendar.isLeapYear(2000), isTrue);
  expect(calendar.isLeapYear(2100), isFalse);
  expect(calendar.isLeapYear(2400), isTrue);
}

@Test()
void EraProperty()
{
  CalendarSystem calendar = CalendarSystem.gregorian;
  LocalDateTime startOfEra = new LocalDateTime.at(1, 1, 1, 0, 0, seconds: 0, calendar: calendar);
  expect(Era.common, startOfEra.era);
  expect(Era.beforeCommon, startOfEra.plusTicks(-1).era);
}

@Test()
void AddMonths_BoundaryCondition()
{
  var start = new LocalDate(2017, 8, 20);
  var end = start.plusMonths(-19);
  var expected = new LocalDate(2016, 1, 20);
  expect(expected, end);
}

