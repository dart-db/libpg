class Column {
  final int index;

  final String name;

  final dynamic value;

  final int oid;

  final int typeLen;

  final int typeModifier;

  final int formatCode;

  Column(
      {this.index,
      this.name,
      this.value,
      this.oid,
      this.typeLen,
      this.typeModifier,
      this.formatCode});
}

class Row {
  final List<Column> _columns;

  final Map<String, Column> _columnsMap;

  final List<dynamic> _values;

  final Map<String, dynamic> _map;

  Row(this._columns, this._columnsMap, this._values, this._map);

  /*
  factory Row.from(this._columns) {
    _values = List<dynamic>(_columns.length);
    int i = 0;
    for(final c in _columns) {
      _columnsMap[c.name] = c;
      _values[i] = c.value;
      _map[c.name] = c.value;
      i++;
    }
  }
   */

  dynamic operator [](/* int | String */ index) {
    if (index is int) {
      if (index < 0) throw Exception('Index cannot be negative');
      if (index >= _columns.length) throw Exception('Index out of range');
      return _values[index];
    } else if (index is String) {
      if (!_map.containsKey(index)) throw Exception('Index does not exist');
      return _map[index];
    }

    throw Exception('Unknown index type');
  }

  void forEach(void Function(String name, dynamic value) function) =>
      asMap().forEach(function);

  List<dynamic> toList() => _values;

  Map<String, dynamic> asMap() => _map;

  List<Column> toColumns() => _columns;

  Map<String, Column> asColumns() => _columnsMap;

  String toString() => _values.join(', ');
}
