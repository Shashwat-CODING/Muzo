import 'package:flutter_riverpod/flutter_riverpod.dart';

final navigationIndexProvider = StateProvider<int>((ref) => 0);
final libraryFilterProvider = StateProvider<String>((ref) => 'All');
