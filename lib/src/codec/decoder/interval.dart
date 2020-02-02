Duration decodeIntervalText(String value) {
  final parts = value.split(' ');

  int months = 0;
  int microseconds = 0;

  for (int i = 0; i < parts.length - 1; i += 2) {
    switch (parts[i + 1]) {
      case 'year':
      case 'years':
        months = int.parse(parts[i]) * 12;
        break;
      case 'month':
      case 'months':
      case 'mon':
      case 'mons':
        months += int.parse(parts[i]);
        break;
      case 'day':
      case 'days':
        microseconds += int.parse(parts[i]) * Duration.microsecondsPerDay;
        break;
    }
  }

  if (months != 0) {
    bool neg = months.isNegative;
    months = months.abs();
    int ms = ((months ~/ 12) * 365.25 * Duration.microsecondsPerDay).floor();
    ms += (months % 12) * 30 * Duration.microsecondsPerDay;
    if (neg) ms = -ms;
    microseconds += ms;
  }

  if (parts.length % 2 == 1) {
    microseconds += _decodeTimePartText(parts.last);
  }

  return Duration(microseconds: microseconds);
}

int _decodeTimePartText(String text) {
  final parts = text.split('.');
  int microseconds = 0;

  if (parts.length == 2) {
    String part = parts.last;
    part = part + '0' * (6 - part.length);
    microseconds = int.parse(part);
  }

  final time = parts.first.split(':');

  int hours = int.parse(time[0]).abs();
  int minutes = int.parse(time[1]);
  int seconds = int.parse(time[2]);

  microseconds += seconds * Duration.microsecondsPerSecond;
  microseconds += minutes * Duration.microsecondsPerMinute;
  microseconds += hours * Duration.microsecondsPerHour;

  if (text.startsWith('-')) microseconds = -microseconds;

  return microseconds;
}

/*
func (dst *Interval) DecodeText(ci *ConnInfo, src []byte) error {
	if src == nil {
		*dst = Interval{Status: Null}
		return nil
	}

	var microseconds int64
	var days int32
	var months int32

	parts := strings.Split(string(src), " ")

	for i := 0; i < len(parts)-1; i += 2 {
		scalar, err := strconv.ParseInt(parts[i], 10, 64)
		if err != nil {
			return errors.Errorf("bad interval format")
		}

		switch parts[i+1] {
		case "year", "years":
			months += int32(scalar * 12)
		case "mon", "mons":
			months += int32(scalar)
		case "day", "days":
			days = int32(scalar)
		}
	}

	if len(parts)%2 == 1 {
		timeParts := strings.SplitN(parts[len(parts)-1], ":", 3)
		if len(timeParts) != 3 {
			return errors.Errorf("bad interval format")
		}

		var negative bool
		if timeParts[0][0] == '-' {
			negative = true
			timeParts[0] = timeParts[0][1:]
		}

		hours, err := strconv.ParseInt(timeParts[0], 10, 64)
		if err != nil {
			return errors.Errorf("bad interval hour format: %s", timeParts[0])
		}

		minutes, err := strconv.ParseInt(timeParts[1], 10, 64)
		if err != nil {
			return errors.Errorf("bad interval minute format: %s", timeParts[1])
		}

		secondParts := strings.SplitN(timeParts[2], ".", 2)

		seconds, err := strconv.ParseInt(secondParts[0], 10, 64)
		if err != nil {
			return errors.Errorf("bad interval second format: %s", secondParts[0])
		}

		var uSeconds int64
		if len(secondParts) == 2 {
			uSeconds, err = strconv.ParseInt(secondParts[1], 10, 64)
			if err != nil {
				return errors.Errorf("bad interval decimal format: %s", secondParts[1])
			}

			for i := 0; i < 6-len(secondParts[1]); i++ {
				uSeconds *= 10
			}
		}

		microseconds = hours * microsecondsPerHour
		microseconds += minutes * microsecondsPerMinute
		microseconds += seconds * microsecondsPerSecond
		microseconds += uSeconds

		if negative {
			microseconds = -microseconds
		}
	}

	*dst = Interval{Months: months, Days: days, Microseconds: microseconds, Status: Present}
	return nil
}
 */
