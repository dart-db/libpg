import 'dart:collection';

main() {
  final set = SplayTreeMap<DateTime, List<int>>();
  set[DateTime(1980, 1, 1).add(Duration(days: -1))] = [-1];
  set[DateTime(1980, 1, 1).add(Duration(days: -4))] = [-4];
  set[DateTime(1980, 1, 1).add(Duration(days: -2))] = [-2];
  set[DateTime(1980, 1, 1).add(Duration(days: -5))] = [-5];
  set[DateTime(1980, 1, 1).add(Duration(days: -3))] = [-3];
  for (int i = 0; i < 10000; i++) {
    set[DateTime(1980, 1, 1).add(Duration(days: i))] = [i];
  }
  set.forEach((k, v) => print('$k $v'));
  final search = DateTime(1989, 02, 21, 0);
  print(set[search]);
  // print(set.lookup(search)); // 87529
}
