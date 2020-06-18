class CannotDecode implements Exception {
  const CannotDecode();
}

class StringReader {
  String _string;

  StringReader({String string}) : _string = string ?? '';

  String get string => _string;

  set string(String value) => _string = value;

  bool get isEmpty => _string.isEmpty;

  bool get isNotEmpty => _string.isNotEmpty;

  String substring(int startIndex, [int endIndex]) {
    _string = string.substring(startIndex, endIndex);
    return _string;
  }

  bool startsWith(Pattern pattern, [int index = 0]) {
    return _string.startsWith(pattern, index);
  }

  bool substringIfStartsWith(String pattern) {
    if (!_string.startsWith(pattern)) {
      return false;
    }
    _string.substring(pattern.length);
    return true;
  }
}

dynamic parse(dynamic _input) {
  if (_input is! StringReader) _input = StringReader(string: _input);
  final StringReader input = _input;
  if (input.startsWith('null')) {
    return null;
  } else if (input.startsWith('{')) {
    return _parseArray(input);
  } else if (input.startsWith('(')) {
    return _parseRecord(input);
  } else if (input.startsWith('"')) {
    return _parseString(input);
  }

  {
    final ret = _parseFloat(input);
    if (ret != null) return ret;
  }

  {
    final ret = _parseInt(input);
    if (ret != null) return ret;
  }

  {
    final ret = _parseUnquotedString(input);
    if (ret != null) return ret;
  }

  throw CannotDecode();
}

List<dynamic> _parseArray(dynamic _input) {
  if (_input is! StringReader) _input = StringReader(string: _input);
  final StringReader input = _input;
  input.substring(1);
  final ret = [];

  while (true) {
    if (input.substringIfStartsWith('}')) {
      input.substring(1);
      break;
    }

    if (input.substringIfStartsWith(',')) {
      ret.add(null);
      continue;
    }
    ret.add(parse(input));
    if (input.substringIfStartsWith(',')) {
      input.substring(1);
    }
  }
  return ret;
}

Map<String, dynamic> _parseRecord(dynamic _input) {
  if (_input is! StringReader) _input = StringReader(string: _input);
  final StringReader input = _input;
  input.substring(1);
  final ret = <String, dynamic>{};
  int i = -1;
  while (true) {
    i++;
    if (input.substringIfStartsWith(')')) {
      input.substring(1);
      break;
    }

    if (input.substringIfStartsWith(',')) {
      ret['f$i'] = null;
      continue;
    }
    ret['f$i'] = parse(input);
    if (input.substringIfStartsWith(',')) {
      input.substring(1);
    }
  }
  return ret;
}

String _parseString(dynamic _input) {
  if (_input is! StringReader) _input = StringReader(string: _input);
  final StringReader input = _input;

  final regExp = RegExp(r'^"((\\"|""|[^"])*)"');
  final match = regExp.firstMatch(input.string);

  if (match == null) throw Exception();
  final ret = match.group(1);
  input.substring(ret.length + 2);
  return ret.replaceAll('""', '"');
}

int _parseInt(dynamic _input) {
  if (_input is! StringReader) _input = StringReader(string: _input);
  final StringReader input = _input;

  final regExp = RegExp('^([+-]?[0-9]+)');
  final match = regExp.firstMatch(input.string);

  if (match == null) return null;
  final ret = match.group(1);
  input.substring(ret.length);
  return int.parse(ret);
}

double _parseFloat(dynamic _input) {
  if (_input is! StringReader) _input = StringReader(string: _input);
  final StringReader input = _input;

  final regExp = RegExp('^([+-][0-9]+(.(0-9)*))');
  // TODO exponential form
  final match = regExp.firstMatch(input.string);

  if (match == null) return null;
  final ret = match.group(1);
  input.substring(ret.length);
  return double.parse(ret);
}

String _parseUnquotedString(dynamic _input) {
  if (_input is! StringReader) _input = StringReader(string: _input);
  final StringReader input = _input;

  final regExp = RegExp(r'^([^,\}\)]+)');
  final match = regExp.firstMatch(input.string);

  if (match == null) return null;
  final ret = match.group(1);
  input.substring(ret.length);

  return ret;
}
