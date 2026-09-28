import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pestaña activa de la navegación inferior (0=Inicio, 1=Casa, 2=Tareas).
/// En provider para que cualquier pantalla pueda saltar de pestaña.
final navIndexProvider = NotifierProvider<NavIndex, int>(NavIndex.new);

class NavIndex extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}
