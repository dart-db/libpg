abstract class IdGenerator {
  String get prefix;

  String get get;

  factory IdGenerator({String prefix = ''}) => _IdGenerator(prefix: prefix);
}

class _IdGenerator implements IdGenerator {
  final String prefix;

  final _subIds = <int>[0];

  _IdGenerator({this.prefix});

  String get get {
    _updateSubIds();

    return (prefix != null ? '$prefix-' : '') +
        _subIds.map((i) => i.toString()).join('-');
  }

  void _updateSubIds() {
    if (_subIds.last < _subIdMax) {
      _subIds.last++;
    } else {
      _subIds.add(1);
    }
  }

  static const _subIdMax = 1000000;
}

class TimedIdGenerator implements IdGenerator {
  final String prefix;

  var _subIds = <int>[];

  var _time = DateTime.now();

  TimedIdGenerator({this.prefix});

  String get get {
    final newTime = DateTime.now();

    if (newTime.microsecondsSinceEpoch != _time.microsecondsSinceEpoch) {
      _time = newTime;
      if (_subIds.isNotEmpty) _subIds = <int>[];
      return (prefix != null ? '$prefix-' : '') +
          '${newTime.microsecondsSinceEpoch}';
    }

    _updateSubIds();

    return (prefix != null ? '$prefix-' : '') +
        '${_time.microsecondsSinceEpoch}-' +
        _subIds.map((i) => i.toString()).join('-');
  }

  void _updateSubIds() {
    if (_subIds.isEmpty) {
      _subIds.add(1);
      return;
    }

    if (_subIds.last < _subIdMax) {
      _subIds.last++;
    } else {
      _subIds.add(1);
    }
  }

  static const _subIdMax = 1000000;
}
