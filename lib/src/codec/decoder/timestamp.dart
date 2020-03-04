import 'package:libpg/src/types/oids.dart';

DateTime decodeTimestampText(int oid, String value) {
  if (value == 'infinity' || value == '-infinity') {
    throw Exception('infinite timestamps are not supported');
  }

  var formattedValue = value;

  // Postgresql uses a BC suffix rather than a negative prefix as in ISO8601.
  if (value.endsWith(' BC')) {
    formattedValue = '-' + value.substring(0, value.length - 3);
  }

  if (oid == OIDs.timestamp) {
    formattedValue += 'Z';
  } else if (oid == OIDs.timestamptz) {
    // PG will return the timestamp in the connection's timezone. The resulting DateTime.parse will handle accordingly.
  } else if (oid == OIDs.date) {
    formattedValue = formattedValue + 'T00:00:00Z';
  }

  return DateTime.parse(formattedValue);
}
