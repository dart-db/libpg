export 'extended_query_entry.dart';
export 'simple_query_entry.dart';
export 'close_prepared_entry.dart';
export 'parse_entry.dart';

abstract class QueueEntry {
  String get queryId;

  String get queryName;

  void addError(error, [StackTrace trace]);
}

enum ParseEntryState {
  unsent,
  sent,
  parsed,
  fieldDescriptionReceived,
  // TODO

  error,
  successful
}

class OIDs {
  static const bool = 16;
  static const bytea = 17;
  static const qChar = 18;
  static const name = 19;
  static const int8 = 20;
  static const int2 = 21;
  static const int4 = 23;
  static const text = 25;
  static const oid = 26;
  static const tid = 27;
  static const xid = 28;
  static const cid = 29;
  static const json = 114;
  static const point = 600;
  static const lseg = 601;
  static const path = 602;
  static const box = 603;
  static const polygon = 604;
  static const line = 628;
  static const cidr = 650;
  static const cidrArray = 651;
  static const float4 = 700;
  static const float8 = 701;
  static const circle = 718;
  static const unknown = 705;
  static const macaddr = 829;
  static const inet = 869;
  static const boolArray = 1000;
  static const int2Array = 1005;
  static const int4Array = 1007;
  static const textArray = 1009;
  static const byteaArray = 1001;
  static const BPCharArray = 1014;
  static const varcharArray = 1015;
  static const int8Array = 1016;
  static const float4Array = 1021;
  static const float8Array = 1022;
  static const ACLItem = 1033;
  static const ACLItemArray = 1034;
  static const inetArray = 1041;
  static const BPChar = 1042;
  static const varchar = 1043;
  static const date = 1082;
  static const time = 1083;
  static const timestamp = 1114;
  static const timestampArray = 1115;
  static const dateArray = 1182;
  static const timestamptz = 1184;
  static const timestamptzArray = 1185;
  static const interval = 1186;
  static const numericArray = 1231;
  static const bit = 1560;
  static const varbit = 1562;
  static const numeric = 1700;
  static const record = 2249;
  static const uuid = 2950;
  static const uuidArray = 2951;
  static const jsonb = 3802;
  static const daterange = 3912;
  static const int4range = 3904;
  static const numrange = 3906;
  static const tsrange = 3908;
  static const tstzrange = 3910;
  static const int8range = 3926;
}

abstract class FormatType {
  static const text = 0;

  static const binary = 1;
}
