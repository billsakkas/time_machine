// https://github.com/nodatime/nodatime/blob/master/src/NodaTime.Test/TimeZones/AlgiersTest.cs
// 8d5399d  on Feb 26, 2016

import 'dart:async';
import 'dart:math' as math;

import 'package:time_machine/time_machine.dart';
import 'package:time_machine/time_machine_calendars.dart';
import 'package:time_machine/time_machine_utilities.dart';

import 'package:test/test.dart';
import 'package:matcher/matcher.dart';
import 'package:time_machine/time_machine_timezones.dart';

import '../time_machine_testing.dart';

/// <summary>
/// Algiers had DST until May 1st 1981, after which time it didn't have any - so
/// we use that to test a time zone whose transitions run out. (When Algiers
/// decided to stop using DST, it changed its standard offset to be what had previously
/// been its DST offset, i.e. +1.)
/// </summary>
Future main() async {
  Algiers = await (await DateTimeZoneProviders.Tzdb)["Africa/Algiers"];

  await runTests();
}

DateTimeZone Algiers;

@Test()
void GetPeriod_BeforeLast()
{
  Instant april1981 = new Instant.fromUtc(1981, 4, 1, 0, 0);
  var actual = Algiers.GetZoneInterval(april1981);
  var expected = new ZoneInterval("WET", new Instant.fromUnixTimeTicks(3418020000000000), new Instant.fromUnixTimeTicks(3575232000000000), Offset.zero, Offset.zero);
  expect(expected, actual);
}

@Test()
void GetPeriod_AfterLastTransition()
{
  var may1981 = DateTimeZone.Utc.AtStrictly(new LocalDateTime.fromYMDHMS(1981, 5, 1, 0, 0, 1)).ToInstant();
  var actual = Algiers.GetZoneInterval(may1981);
  var expected = new ZoneInterval("CET", new Instant.fromUnixTimeTicks(3575232000000000), null, new Offset.fromSeconds(TimeConstants.secondsPerHour), Offset.zero);
  expect(expected, actual);
}
