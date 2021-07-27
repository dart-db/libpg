import 'dart:collection';
import 'package:libpg/src/codec/sqlify/sqlify.dart';
import 'package:libpg/libpg.dart' as libpg;

String substitute(String statement,
    {Map<String, dynamic> values = const {},
    String prefix = r'@',
    bool ignoreAbsent = false}) {
  if (values.isEmpty) return statement;

  final subs = SplayTreeSet<_Sub>();

  for (String key in values.keys) {
    final regex = RegExp('$prefix\\{$key\\}');
    final matches = regex.allMatches(statement);
    if (!ignoreAbsent && matches.isEmpty) {
      throw Exception('Substitution variable $key not found in query');
    }
    final String value = sqlify(values[key]);
    matches.forEach((m) => subs.add(_Sub(m.start, m.end, value)));
  }

  final sb = StringBuffer();
  int i = 0;
  for (final sub in subs) {
    sb.write(statement.substring(i, sub.start));
    sb.write(sub.value);
    i = sub.end;
  }

  if (i < statement.length) {
    sb.write(statement.substring(i));
  }

  return sb.toString();
}

class _Sub implements Comparable<_Sub> {
  final int start;

  final int end;

  final String value;

  _Sub(this.start, this.end, this.value);

  @override
  int compareTo(_Sub other) => start - other.start;
}

extension StringSqlSubstitute on String {
  String substitute(Map<String, dynamic> values) {
    final ret = libpg.substitute(replaceAll('\n', ''), values: values);
    return ret;
  }
}
