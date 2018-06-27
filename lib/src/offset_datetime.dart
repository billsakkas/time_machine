// Portions of this work are Copyright 2018 The Time Machine Authors. All rights reserved.
// Portions of this work are Copyright 2018 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0, as found in the LICENSE.txt file.

import 'package:meta/meta.dart';
import 'package:quiver_hashcode/hashcode.dart';

import 'package:time_machine/src/time_machine_internal.dart';
import 'package:time_machine/src/text/globalization/time_machine_globalization.dart';
import 'package:time_machine/src/text/time_machine_text.dart';
import 'package:time_machine/src/utility/time_machine_utilities.dart';
import 'package:time_machine/src/calendars/time_machine_calendars.dart';

@internal
abstract class IOffsetDateTime {
  static OffsetDateTime fullTrust(YearMonthDayCalendar yearMonthDayCalendar, int nanosecondOfDay, Offset offset) =>
      new OffsetDateTime._fullTrust(yearMonthDayCalendar, nanosecondOfDay, offset);
  
  static OffsetDateTime lessTrust(YearMonthDayCalendar yearMonthDayCalendar, LocalTime time, Offset offset) =>
      new OffsetDateTime._lessTrust(yearMonthDayCalendar, time, offset);

  static OffsetDateTime fromInstant(Instant instant, Offset offset, [CalendarSystem calendar]) =>
      new OffsetDateTime._fromInstant(instant, offset, calendar);

  static YearMonthDay yearMonthDay(OffsetDateTime offsetDateTime) => offsetDateTime._yearMonthDay;
}

@immutable
class OffsetDateTime // : IEquatable<OffsetDateTime>, IFormattable, IXmlSerializable
    {
  // todo: We can't use this either
  // @private static const int NanosecondsBits = 47;

  // todo: we can't use this -- WE CAN NOT USE LONG SIZED MASKS IN JS
  //@private static const int NanosecondsMask = 0; // (1L << TimeConstants.nanosecondsBits) - 1;
  //@private static const int OffsetMask = ~NanosecondsMask;
  static const int _minBclOffsetMinutes = -14 * TimeConstants.minutesPerHour;
  static const int _maxBclOffsetMinutes = 14 * TimeConstants.minutesPerHour;

  // These are effectively the fields of a LocalDateTime and an Offset, but by keeping them directly here,
  // we reduce the levels of indirection and copying, which makes a surprising difference in speed, and
  // should allow us to optimize memory usage too. todo: this may not be the same in Dart
  final YearMonthDayCalendar _yearMonthDayCalendar;

  // Bottom NanosecondsBits bits are the nanosecond-of-day; top 17 bits are the offset (in seconds). This has a slight
  // execution-time cost (masking for each component) but the logical benefit of saving 4 bytes per
  // value actually ends up being 8 bytes per value on a 64-bit CLR due to alignment.
  // @private final int nanosecondsAndOffset;

  final int _nanosecondOfDay;
  final Offset _offset;

  OffsetDateTime._fullTrust(this._yearMonthDayCalendar, this._nanosecondOfDay, this._offset) // this.nanosecondsAndOffset)
  {
    calendar.validateYearMonthDay_(_yearMonthDay);
  }

  OffsetDateTime._lessTrust(this._yearMonthDayCalendar, LocalTime time, Offset offset)
      : _nanosecondOfDay = time.nanosecondOfDay, _offset = offset // nanosecondsAndOffset = _combineNanoOfDayAndOffset(time.NanosecondOfDay, offset)
  {
    calendar.validateYearMonthDay_(_yearMonthDay);
  }
  
  // todo: why is this internal?
  
  /// Optimized conversion from an Instant to an OffsetDateTime in the specified calendar.
  /// This is equivalent to `new OffsetDateTime(new LocalDateTime(instant.Plus(offset), calendar), offset)`
  /// but with less overhead.
  factory OffsetDateTime._fromInstant(Instant instant, Offset offset, [CalendarSystem calendar])
  {
    int days = instant.daysSinceEpoch;
    int nanoOfDay = instant.nanosecondOfDay + offset.nanoseconds;
    if (nanoOfDay >= TimeConstants.nanosecondsPerDay) {
      days++;
      nanoOfDay -= TimeConstants.nanosecondsPerDay;
    }
    else if (nanoOfDay < 0) {
      days--;
      nanoOfDay += TimeConstants.nanosecondsPerDay;
    }
    var yearMonthDayCalendar = calendar != null 
        ? calendar.getYearMonthDayCalendarFromDaysSinceEpoch(days)
        // todo: can we grab the correct calculator based on the default culture?
        : GregorianYearMonthDayCalculator.getGregorianYearMonthDayCalendarFromDaysSinceEpoch(days);
    // var nanosecondsAndOffset = _combineNanoOfDayAndOffset(nanoOfDay, offset);
    return new OffsetDateTime._fullTrust(yearMonthDayCalendar, nanoOfDay, offset); // nanosecondsAndOffset);
  }

  /// Constructs a new offset date/time with the given local date and time, and the given offset from UTC.
  ///
  /// [localDateTime]: Local date and time to represent
  /// [offset]: Offset from UTC
  OffsetDateTime(LocalDateTime localDateTime, Offset offset)
      : this._fullTrust(ILocalDate.yearMonthDayCalendar(localDateTime.date), localDateTime.nanosecondOfDay, offset);

  /// Gets the calendar system associated with this offset date and time.
  CalendarSystem get calendar => CalendarSystem.forOrdinal(_yearMonthDayCalendar.calendarOrdinal);

  /// Gets the year of this offset date and time.
  /// This returns the "absolute year", so, for the ISO calendar,
  /// a value of 0 means 1 BC, for example.
  int get year => _yearMonthDayCalendar.year;

  /// Gets the month of this offset date and time within the year.
  int get month => _yearMonthDayCalendar.month;

  /// Gets the day of this offset date and time within the month.
  int get day => _yearMonthDayCalendar.day;

  YearMonthDay get _yearMonthDay => _yearMonthDayCalendar.toYearMonthDay();

  /// Gets the week day of this offset date and time expressed as an [IsoDayOfWeek] value.
  IsoDayOfWeek get dayOfWeek => calendar.getDayOfWeek(_yearMonthDayCalendar.toYearMonthDay());

  /// Gets the year of this offset date and time within the era.
  int get yearOfEra => calendar.getYearOfEra(_yearMonthDayCalendar.year);

  /// Gets the era of this offset date and time.
  Era get era => calendar.getEra(_yearMonthDayCalendar.year);

  /// Gets the day of this offset date and time within the year.
  int get dayOfYear => calendar.getDayOfYear(_yearMonthDayCalendar.toYearMonthDay());

  /// Gets the hour of day of this offest date and time, in the range 0 to 23 inclusive.
  int get hour => nanosecondOfDay ~/ TimeConstants.nanosecondsPerHour;
  // Effectively nanoseconds / NanosecondsPerHour, but apparently rather more efficient.
  // Dart: doesn't work in JS
  // ((nanosecondOfDay >> 13) ~/ 439453125);

  /// Gets the hour of the half-day of this offest date and time, in the range 1 to 12 inclusive.
  int get clockHourOfHalfDay {
    int hohd = _hourOfHalfDay;
    return hohd == 0 ? 12 : hohd;
  }

  // TODO(feature): Consider exposing this.
  /// Gets the hour of the half-day of this offset date and time, in the range 0 to 11 inclusive.
  /*internal*/ int get _hourOfHalfDay => (hour % 12);

  /// Gets the minute of this offset date and time, in the range 0 to 59 inclusive.
  int get minute {
    // Effectively NanosecondOfDay / NanosecondsPerMinute, but apparently rather more efficient.
    int minuteOfDay = nanosecondOfDay ~/ TimeConstants.nanosecondsPerMinute; //((nanosecondOfDay >> 11) ~/ 29296875);
    return minuteOfDay % TimeConstants.minutesPerHour;
  }

  /// Gets the second of this offset date and time within the minute, in the range 0 to 59 inclusive.
  int get second {
    int secondOfDay = (nanosecondOfDay ~/ TimeConstants.nanosecondsPerSecond);
    return secondOfDay % TimeConstants.secondsPerMinute;
  }

  /// Gets the millisecond of this offset date and time within the second, in the range 0 to 999 inclusive.
  int get millisecond {
    int milliSecondOfDay = (nanosecondOfDay ~/ TimeConstants.nanosecondsPerMillisecond);
    return (milliSecondOfDay % TimeConstants.millisecondsPerSecond);
  }

  // TODO(optimization): Rewrite for performance?
  /// Gets the tick of this offset date and time within the second, in the range 0 to 9,999,999 inclusive.
  int get tickOfSecond => ((tickOfDay % TimeConstants.ticksPerSecond));

  /// Gets the tick of this offset date and time within the day, in the range 0 to 863,999,999,999 inclusive.
  int get tickOfDay => nanosecondOfDay ~/ TimeConstants.nanosecondsPerTick;

  /// Gets the nanosecond of this offset date and time within the second, in the range 0 to 999,999,999 inclusive.
  int get nanosecondOfSecond => ((nanosecondOfDay % TimeConstants.nanosecondsPerSecond));

  /// Gets the nanosecond of this offset date and time within the day, in the range 0 to 86,399,999,999,999 inclusive.
  int get nanosecondOfDay => _nanosecondOfDay; // nanosecondsAndOffset & NanosecondsMask;

  /// Returns the local date and time represented within this offset date and time.
  // todo: should this be a const? or cached -- or???
  LocalDateTime get localDateTime => new LocalDateTime(date, timeOfDay);

  /// Gets the local date represented by this offset date and time.
  ///
  /// The returned [LocalDate]
  /// will have the same calendar system and return the same values for each of the date-based calendar
  /// properties (Year, MonthOfYear and so on), but will not have any offset information.
  LocalDate get date => ILocalDate.trusted(_yearMonthDayCalendar);

  /// Gets the time portion of this offset date and time.
  ///
  /// The returned [LocalTime] will
  /// return the same values for each of the time-based properties (Hour, Minute and so on), but
  /// will not have any offset information.
  LocalTime get timeOfDay => ILocalTime.fromNanoseconds(nanosecondOfDay);

  /// Gets the offset from UTC.
  Offset get offset => _offset; // new Offset(nanosecondsAndOffset >> NanosecondsBits);

  /// Returns the number of nanoseconds in the offset, without going via an Offset.
  int get _offsetNanoseconds => _offset.nanoseconds; // (nanosecondsAndOffset >> NanosecondsBits) * TimeConstants.nanosecondsPerSecond;

  /// Converts this offset date and time to an instant in time by subtracting the offset from the local date and time.
  ///
  /// Returns: The instant represented by this offset date and time
  Instant toInstant() => IInstant.untrusted(_toElapsedTimeSinceEpoch());

  Span _toElapsedTimeSinceEpoch() {
    // Equivalent to LocalDateTime.ToLocalInstant().Minus(offset)
    int days = calendar.getDaysSinceEpoch(_yearMonthDayCalendar.toYearMonthDay());
    Span elapsedTime = new Span(days: days, nanoseconds: nanosecondOfDay - _offsetNanoseconds);
    // Duration elapsedTime = new Duration(days, NanosecondOfDay).MinusSmallNanoseconds(OffsetNanoseconds);
    return elapsedTime;
  }

  /// Returns this value as a [ZonedDateTime].
  ///
  /// This method returns a [ZonedDateTime] with the same local date and time as this value, using a
  /// fixed time zone with the same offset as the offset for this value.
  ///
  /// Note that because the resulting `ZonedDateTime` has a fixed time zone, it is generally not useful to
  /// use this result for arithmetic operations, as the zone will not adjust to account for daylight savings.
  ///
  /// Returns: A zoned date/time with the same local time and a fixed time zone using the offset from this value.
  ZonedDateTime get inFixedZone => IZonedDateTime.trusted(this, new DateTimeZone.forOffset(offset));

  /// Returns this value in ths specified time zone. This method does not expect
  /// the offset in the zone to be the same as for the current value; it simply converts
  /// this value into an [Instant] and finds the [ZonedDateTime]
  /// for that instant in the specified zone.
  ///
  /// [zone]: The time zone of the new value.
  /// Returns: The instant represented by this value, in the specified time zone.
  ZonedDateTime inZone(DateTimeZone zone) {
    Preconditions.checkNotNull(zone, 'zone');
    return toInstant().inZone(zone);
  }

  /// Creates a new [OffsetDateTime] representing the same physical date, time and offset, but in a different calendar.
  /// The returned OffsetDateTime is likely to have different date field values to this one.
  /// For example, January 1st 1970 in the Gregorian calendar was December 19th 1969 in the Julian calendar.
  ///
  /// [calendar]: The calendar system to convert this offset date and time to.
  /// Returns: The converted OffsetDateTime.
  OffsetDateTime withCalendar(CalendarSystem calendar) {
    LocalDate newDate = date.withCalendar(calendar);
    return new OffsetDateTime._fullTrust(ILocalDate.yearMonthDayCalendar(newDate), _nanosecondOfDay, _offset); // nanosecondsAndOffset);
  }

  /// Returns this offset date/time, with the given date adjuster applied to it, maintaining the existing time of day and offset.
  ///
  /// If the adjuster attempts to construct an
  /// invalid date (such as by trying to set a day-of-month of 30 in February), any exception thrown by
  /// that construction attempt will be propagated through this method.
  ///
  /// [adjuster]: The adjuster to apply.
  /// Returns: The adjusted offset date/time.
  OffsetDateTime withDate(LocalDate Function(LocalDate) adjuster) {
    LocalDate newDate = date.adjust(adjuster);
    return new OffsetDateTime._fullTrust(ILocalDate.yearMonthDayCalendar(newDate), _nanosecondOfDay, _offset); // nanosecondsAndOffset);
  }

  /// Returns this date/time, with the given time adjuster applied to it, maintaining the existing date and offset.
  ///
  /// If the adjuster attempts to construct an invalid time, any exception thrown by
  /// that construction attempt will be propagated through this method.
  ///
  /// [adjuster]: The adjuster to apply.
  /// Returns: The adjusted offset date/time.
  OffsetDateTime withTime(LocalTime Function(LocalTime) adjuster) {
    LocalTime newTime = timeOfDay.adjust(adjuster);
    return new OffsetDateTime._fullTrust(_yearMonthDayCalendar, newTime.nanosecondOfDay, _offset); //  (nanosecondsAndOffset & OffsetMask) | newTime.NanosecondOfDay);
  }

  /// Creates a new OffsetDateTime representing the instant in time in the same calendar,
  /// but with a different offset. The local date and time is adjusted accordingly.
  ///
  /// [offset]: The new offset to use.
  /// Returns: The converted OffsetDateTime.
  OffsetDateTime withOffset(Offset offset) {
    // Slight change to the normal operation, as it's *just* about plausible that we change day
    // twice in one direction or the other.
    int days = 0;
    int nanos =_nanosecondOfDay /*(nanosecondsAndOffset & NanosecondsMask)*/ + offset.nanoseconds - _offsetNanoseconds;
    if (nanos >= TimeConstants.nanosecondsPerDay) {
      days++;
      nanos -= TimeConstants.nanosecondsPerDay;
      if (nanos >= TimeConstants.nanosecondsPerDay) {
        days++;
        nanos -= TimeConstants.nanosecondsPerDay;
      }
    }
    else if (nanos < 0) {
      days--;
      nanos += TimeConstants.nanosecondsPerDay;
      if (nanos < 0) {
        days--;
        nanos += TimeConstants.nanosecondsPerDay;
      }
    }
    return new OffsetDateTime._fullTrust(
        days == 0 ? _yearMonthDayCalendar : ILocalDate.yearMonthDayCalendar(date
            .plusDays(days)), nanos, offset);
    // _combineNanoOfDayAndOffset(nanos, offset));
  }

  /// Constructs a new [OffsetDate] from the date and offset of this value,
  /// but omitting the time-of-day.
  ///
  /// Returns: A value representing the date and offset aspects of this value.
  OffsetDate toOffsetDate() => new OffsetDate(date, offset);

  /// Constructs a new [OffsetTime] from the time and offset of this value,
  /// but omitting the date.
  ///
  /// Returns: A value representing the time and offset aspects of this value.
  OffsetTime toOffsetTime() => new OffsetTime(timeOfDay, offset);

  /// Returns a hash code for this offset date and time.
  @override int get hashCode => hash2(LocalDateTime, offset);

  /// Compares two [OffsetDateTime] values for equality. This requires
  /// that the local date/time values be the same (in the same calendar) and the offsets.
  ///
  /// [other]: The value to compare this offset date/time with.
  /// Returns: True if the given value is another offset date/time equal to this one; false otherwise.
  bool equals(OffsetDateTime other) =>
      this._yearMonthDayCalendar == other._yearMonthDayCalendar && this._nanosecondOfDay == other._nanosecondOfDay && this._offset == other._offset; // this.nanosecondsAndOffset == other.nanosecondsAndOffset;

  /// Returns a [String] that represents this instance.
  ///
  /// The value of the current instance in the default format pattern ("G"), using the current thread's
  /// culture to obtain a format provider.
  // @override String toString() => TextShim.toStringOffsetDateTime(this); // OffsetDateTimePattern.Patterns.BclSupport.Format(this, null, CultureInfo.CurrentCulture);
  @override String toString([String patternText = null, /*IFormatProvider*/ dynamic formatProvider = null]) =>
      OffsetDateTimePatterns.bclSupport.format(this, patternText, formatProvider ?? CultureInfo.currentCulture);

  /// Adds a duration to an offset date and time.
  ///
  /// This is an alternative way of calling [op_Addition(OffsetDateTime, Duration)].
  ///
  /// [offsetDateTime]: The value to add the duration to.
  /// [duration]: The duration to add
  /// Returns: A new value with the time advanced by the given duration, in the same calendar system and with the same offset.
  static OffsetDateTime add(OffsetDateTime offsetDateTime, Span span) => offsetDateTime + span;

  /// Returns the result of adding a duration to this offset date and time.
  ///
  /// This is an alternative way of calling [op_Addition(OffsetDateTime, Duration)].
  ///
  /// [duration]: The duration to add
  /// Returns: A new [OffsetDateTime] representing the result of the addition.
  OffsetDateTime plus(Span span) => this + span;

  /// Returns the result of adding a increment of hours to this zoned date and time
  ///
  /// [hours]: The number of hours to add
  /// Returns: A new [OffsetDateTime] representing the result of the addition.
  OffsetDateTime plusHours(int hours) => this + new Span(hours: hours);

  /// Returns the result of adding an increment of minutes to this zoned date and time
  ///
  /// [minutes]: The number of minutes to add
  /// Returns: A new [OffsetDateTime] representing the result of the addition.
  OffsetDateTime plusMinutes(int minutes) => this + new Span(minutes: minutes);

  /// Returns the result of adding an increment of seconds to this zoned date and time
  ///
  /// [seconds]: The number of seconds to add
  /// Returns: A new [OffsetDateTime] representing the result of the addition.
  OffsetDateTime plusSeconds(int seconds) => this + new Span(seconds: seconds);

  /// Returns the result of adding an increment of milliseconds to this zoned date and time
  ///
  /// [milliseconds]: The number of milliseconds to add
  /// Returns: A new [OffsetDateTime] representing the result of the addition.
  OffsetDateTime plusMilliseconds(int milliseconds) => this + new Span(milliseconds: milliseconds);

  /// Returns the result of adding an increment of ticks to this zoned date and time
  ///
  /// [ticks]: The number of ticks to add
  /// Returns: A new [OffsetDateTime] representing the result of the addition.
  OffsetDateTime plusTicks(int ticks) => this + new Span(ticks: ticks);

  /// Returns the result of adding an increment of nanoseconds to this zoned date and time
  ///
  /// [nanoseconds]: The number of nanoseconds to add
  /// Returns: A new [OffsetDateTime] representing the result of the addition.
  OffsetDateTime plusNanoseconds(int nanoseconds) => this + new Span(nanoseconds: nanoseconds);

  /// Returns a new [OffsetDateTime] with the time advanced by the given duration.
  ///
  /// The returned value retains the calendar system and offset of the [_offsetDateTime].
  ///
  /// [offsetDateTime]: The [OffsetDateTime] to add the duration to.
  /// [duration]: The duration to add.
  /// Returns: A new value with the time advanced by the given duration, in the same calendar system and with the same offset.
  OffsetDateTime operator +(Span span) =>
      new OffsetDateTime._fromInstant(toInstant() + span, offset);

  /// Subtracts a duration from an offset date and time.
  ///
  /// This is an alternative way of calling [op_Subtraction(OffsetDateTime, Duration)].
  ///
  /// [offsetDateTime]: The value to subtract the duration from.
  /// [duration]: The duration to subtract.
  /// Returns: A new value with the time "rewound" by the given duration, in the same calendar system and with the same offset.
  static OffsetDateTime subtract(OffsetDateTime offsetDateTime, Span span) => offsetDateTime - span;

  /// Returns the result of subtracting a duration from this offset date and time, for a fluent alternative to
  /// [op_Subtraction(OffsetDateTime, Duration)]
  ///
  /// [span]: The duration to subtract
  /// Returns: A new [OffsetDateTime] representing the result of the subtraction.
  OffsetDateTime minusSpan(Span span) => new OffsetDateTime._fromInstant(toInstant() - span, offset); // new Instant.trusted(ToElapsedTimeSinceEpoch()

  /// Returns a new [OffsetDateTime] with the duration subtracted.
  ///
  /// The returned value retains the calendar system and offset of the [_offsetDateTime].
  ///
  /// [offsetDateTime]: The value to subtract the duration from.
  /// [duration]: The duration to subtract.
  /// Returns: A new value with the time "rewound" by the given duration, in the same calendar system and with the same offset.
  /// Subtracts one [OffsetDateTime] from another, resulting in the elapsed time between
  /// the two values.
  ///
  /// This is equivalent to `end.ToInstant() - start.ToInstant()`; in particular:
  /// * The two values can use different calendar systems
  /// * The two values can have different UTC offsets
  ///
  /// [end]: The offset date and time value to subtract from; if this is later than [start]
  /// then the result will be positive.
  /// [start]: The offset date and time to subtract from [end].
  /// Returns: The elapsed duration from [start] to [end].
  dynamic operator -(dynamic value) =>
  // todo: dynamic dispatch... still complaining... change API to prevent dynamic dispatch?
  value is Span ? minusSpan(value) : value is OffsetDateTime ? minusOffsetDateTime(value) : throw new TypeError();

// static Duration operator -(OffsetDateTime end, OffsetDateTime start) => end.ToInstant() - start.ToInstant();

  /// Subtracts one offset date and time from another, returning an elapsed duration.
  ///
  /// This is an alternative way of calling [op_Subtraction(OffsetDateTime, OffsetDateTime)].
  ///
  /// [end]: The offset date and time value to subtract from; if this is later than [start]
  /// then the result will be positive.
  /// [start]: The offset date and time to subtract from [end].
  /// Returns: The elapsed duration from [start] to [end].
  static Span subtractOffsetDateTimes(OffsetDateTime end, OffsetDateTime start) => end.minusOffsetDateTime(start);

  /// Returns the result of subtracting another offset date and time from this one, resulting in the elapsed duration
  /// between the two instants represented in the values.
  ///
  /// This is an alternative way of calling [op_Subtraction(OffsetDateTime, OffsetDateTime)].
  ///
  /// [other]: The offset date and time to subtract from this one.
  /// Returns: The elapsed duration from [other] to this value.
  Span minusOffsetDateTime(OffsetDateTime other) => toInstant() - other.toInstant();


  /// Implements the operator == (equality).
  ///
  /// [left]: The left hand side of the operator.
  /// [right]: The right hand side of the operator.
  /// Returns: `true` if values are equal to each other, otherwise `false`.
  bool operator ==(dynamic right) => right is OffsetDateTime && equals(right);
}

// todo: very unsure about what to do with these

/// Implementation for [Comparer.Local]
class _OffsetDateTime_LocalComparer extends OffsetDateTimeComparer {
  static final OffsetDateTimeComparer _instance = new _OffsetDateTime_LocalComparer._();

  _OffsetDateTime_LocalComparer._() : super._();

  /// <inheritdoc />
  @override int compare(OffsetDateTime x, OffsetDateTime y) {
    Preconditions.checkArgument(x.calendar == y.calendar, 'y',
        "Only values with the same calendar system can be compared");
    int dateComparison = x.calendar.compare(IOffsetDateTime.yearMonthDay(x), IOffsetDateTime.yearMonthDay(y));
    if (dateComparison != 0) {
      return dateComparison;
    }
    return x.nanosecondOfDay.compareTo(y.nanosecondOfDay);
  }

  /// <inheritdoc />
  @override bool equals(OffsetDateTime x, OffsetDateTime y) =>
      x._yearMonthDayCalendar == y._yearMonthDayCalendar && x.nanosecondOfDay == y.nanosecondOfDay;

  /// <inheritdoc />
  @override int getHashCode(OffsetDateTime obj) => hash2(obj._yearMonthDayCalendar, obj.nanosecondOfDay);
}


/// Base class for [OffsetDateTime] comparers.
///
/// Use the static properties of this class to obtain instances. This type is exposed so that the
/// same value can be used for both equality and ordering comparisons.
@immutable
abstract class OffsetDateTimeComparer // implements Comparable<OffsetDateTime> // : IComparer<OffsetDateTime>, IEqualityComparer<OffsetDateTime>
    {
  // TODO(feature): Should we have a comparer which is calendar-sensitive (so will fail if the calendars are different)
  // but still uses the offset?

  /// Gets a comparer which compares [OffsetDateTime] values by their local date/time, without reference to
  /// the offset. Comparisons between two values of different calendar systems will fail with [ArgumentException].
  ///
  /// For example, this comparer considers 2013-03-04T20:21:00+0100 to be later than 2013-03-04T19:21:00-0700 even though
  /// the second value represents a later instant in time.
  /// This property will return a reference to the same instance every time it is called.
  static OffsetDateTimeComparer get local => OffsetDateTimeComparer.local;

  /// Returns a comparer which compares [OffsetDateTime] values by the instant values obtained by applying the offset to
  /// the local date/time, ignoring the calendar system.
  ///
  /// For example, this comparer considers 2013-03-04T20:21:00+0100 to be earlier than 2013-03-04T19:21:00-0700 even though
  /// the second value has a local time which is earlier.
  /// This property will return a reference to the same instance every time it is called.
  ///
  /// <value>A comparer which compares values by the instant values obtained by applying the offset to
  /// the local date/time, ignoring the calendar system.</value>
  static OffsetDateTimeComparer get instant => OffsetDateTimeComparer.instant;

  /// internal constructor to prevent external classes from deriving from this.
  /// (That means we can add more abstract members in the future.)
  OffsetDateTimeComparer._() {
  }

  /// Compares two [OffsetDateTime] values and returns a value indicating whether one is less than, equal to, or greater than the other.
  ///
  /// [x]: The first value to compare.
  /// [y]: The second value to compare.
  /// A signed integer that indicates the relative values of [x] and [y], as shown in the following table.
  ///   <list type = "table">
  ///     <listheader>
  ///       <term>Value</term>
  ///       <description>Meaning</description>
  ///     </listheader>
  ///     <item>
  ///       <term>Less than zero</term>
  ///       <description>[x] is less than [y].</description>
  ///     </item>
  ///     <item>
  ///       <term>Zero</term>
  ///       <description>[x] is equals to [y].</description>
  ///     </item>
  ///     <item>
  ///       <term>Greater than zero</term>
  ///       <description>[x] is greater than [y].</description>
  ///     </item>
  ///   </list>
  int compare(OffsetDateTime x, OffsetDateTime y);

  /// Determines whether the specified `OffsetDateTime` values are equal.
  ///
  /// [x]: The first `OffsetDateTime` to compare.
  /// [y]: The second `OffsetDateTime` to compare.
  /// Returns: `true` if the specified objects are equal; otherwise, `false`.
  bool equals(OffsetDateTime x, OffsetDateTime y);

  /// Returns a hash code for the specified `OffsetDateTime`.
  ///
  /// [obj]: The `OffsetDateTime` for which a hash code is to be returned.
  /// Returns: A hash code for the specified value.
  int getHashCode(OffsetDateTime obj);
}

/// Implementation for [Comparer.Instant].
class _OffsetDateTime_InstantComparer extends OffsetDateTimeComparer {
  static final OffsetDateTimeComparer _instance = new _OffsetDateTime_InstantComparer._();

  _OffsetDateTime_InstantComparer._() : super._();

  /// <inheritdoc />
  @override int compare(OffsetDateTime x, OffsetDateTime y) =>
  // TODO(optimization): Optimize cases which are more than 2 days apart, by avoiding the arithmetic?
  x._toElapsedTimeSinceEpoch().compareTo(y._toElapsedTimeSinceEpoch());

  /// <inheritdoc />
  @override bool equals(OffsetDateTime x, OffsetDateTime y) =>
      x._toElapsedTimeSinceEpoch() == y._toElapsedTimeSinceEpoch();

  /// <inheritdoc />
  @override int getHashCode(OffsetDateTime obj) =>
      obj
          ._toElapsedTimeSinceEpoch()
          .hashCode;
}
