abstract class ToSql {
  String toSql();
}

String sqlify(dynamic value) {
  if (value == null) return 'null';
  if (value is ToSql) return value.toSql();

  switch (value.runtimeType) {
    case String:
      return r"'" + (value as String).replaceAll(r"'", r"''") + r"'";
    case int:
    case double:
      return value.toString();
    case DateTime:
      return timestampToSql(value);
    case Duration:
      return intervalToSql(value);
    default:
      throw Exception('${value.runtimeType} cannot be sqlified');
  }
}

String timestampToSql(DateTime datetime) {
  var string = datetime.toIso8601String();

  // ISO8601 UTC times already carry Z, but local times carry no timezone info
  // so this code will append it.
  if (!datetime.isUtc) {
    var offset = datetime.timeZoneOffset;
    bool isNegative = offset.isNegative;
    offset = offset.abs();

    var hour = offset.inHours.toString().padLeft(2, '0');
    var minute = (offset.inMinutes % 60).toString().padLeft(2, '0');

    hour = (isNegative ? '-' : '+') + hour;

    string = '$string$hour:$minute';
  }

  if (string.startsWith('-')) {
    // Postgresql uses a BC suffix for dates rather than the negative prefix returned by
    // dart's ISO8601 date string.
    string = string.substring(1) + ' BC';
  } else if (string.startsWith('-')) {
    // Postgresql doesn't allow leading + signs for 6 digit dates. Strip it out.
    string = string.substring(1);
  }

  return "'${string}'";
}

String intervalToSql(Duration value) => "INTERVAL '$value'";

String intervalToSqlVerbose(Duration value) {
  final sb = StringBuffer((value.isNegative ? '-' : '') + "INTERVAL '");

  {
    final days = value.inDays;
    if (days > 0) {
      sb.write('$days days ');
    }
  }

  sb.write('${(value.inHours % 24).toString().padLeft(2, '0')}:');
  sb.write('${(value.inMinutes % 60).toString().padLeft(2, '0')}:');
  sb.write('${(value.inSeconds % 60).toString().padLeft(2, '0')}');

  {
    var microseconds = (value.inMicroseconds % 1000000);
    if (microseconds != 0) {
      sb.write('.');
      if ((microseconds % 1000) != 0) {
        sb.write(microseconds.toString().padLeft(6, '0'));
      } else {
        var milliseconds = (value.inMilliseconds % 1000);
        sb.write(milliseconds.toString().padLeft(3, '0'));
      }
    }
  }

  sb.write("'");
  return sb.toString();
}
