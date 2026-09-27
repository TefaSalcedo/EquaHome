import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../calendar/calendar_screen.dart';
import '../house/house_screen.dart';
import '../tasks/tasks_screen.dart';
import 'home_controller.dart';
import 'home_screen.dart';
import 'nav_provider.dart';

/// Contenedor con navegación inferior: Inicio, Casa, Tareas y Calendario.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(navIndexProvider);
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [
          HomeScreen(),
          HouseScreen(),
          TasksScreen(),
          CalendarScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          ref.read(navIndexProvider.notifier).select(i);
          // Al volver a Inicio refresca: el plan del día pudo materializar
          // tareas nuevas (plantillas creadas en Tareas, carry-over, etc.).
          if (i == 0) {
            ref.invalidate(todayTasksProvider);
            ref.invalidate(loadProvider);
          }
        },
        destinations: const [
          NavigationDestination(
            key: Key('navHome'),
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            key: Key('navHouse'),
            icon: Icon(Icons.meeting_room_outlined),
            selectedIcon: Icon(Icons.meeting_room),
            label: 'Casa',
          ),
          NavigationDestination(
            key: Key('navTasks'),
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Tareas',
          ),
          NavigationDestination(
            key: Key('navCalendar'),
            icon: Icon(Icons.calendar_view_week_outlined),
            selectedIcon: Icon(Icons.calendar_view_week),
            label: 'Calendario',
          ),
        ],
      ),
    );
  }
}
