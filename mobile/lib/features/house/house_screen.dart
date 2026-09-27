import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../design_system/colors.dart';
import '../../design_system/theme.dart';
import 'house_controller.dart';
import 'room_detail_screen.dart';

const _roomTypeIcons = <String, IconData>{
  'bedroom': Icons.bed_outlined,
  'bathroom': Icons.bathtub_outlined,
  'kitchen': Icons.kitchen_outlined,
  'living': Icons.weekend_outlined,
  'dining': Icons.dining_outlined,
  'balcony': Icons.balcony_outlined,
  'patio': Icons.deck_outlined,
  'laundry': Icons.local_laundry_service_outlined,
  'other': Icons.square_outlined,
};

/// Pestaña Casa: habitaciones del hogar activo y sus objetos.
class HouseScreen extends ConsumerWidget {
  const HouseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rooms = ref.watch(roomsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi casa')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('addRoom'),
        onPressed: () => _showRoomForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Habitación'),
      ),
      body: rooms.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(apiErrorMessage(e))),
        data: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(roomsProvider),
          child: ListView(
            padding: const EdgeInsets.all(EquaSpace.lg),
            children: [
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: EquaSpace.xl,
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.meeting_room_outlined,
                          size: 48, color: EquaColors.primary),
                      const SizedBox(height: EquaSpace.md),
                      Text(
                        'Registra las habitaciones de tu casa',
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: EquaSpace.sm),
                      Text(
                        'Así sabremos qué hay que limpiar y cuánto toma cada espacio.',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                for (final room in list) ...[
                  _RoomCard(room: room),
                  const SizedBox(height: EquaSpace.md),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRoomForm(BuildContext context, WidgetRef ref,
      {Room? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RoomFormSheet(existing: existing),
    );
    if (saved == true && context.mounted) {
      ref.invalidate(roomsProvider);
    }
  }
}

class _RoomCard extends ConsumerWidget {
  const _RoomCard({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: EquaSpace.md,
          vertical: EquaSpace.xs,
        ),
        leading: CircleAvatar(
          backgroundColor: EquaColors.info.withValues(alpha: 0.25),
          child: Icon(
            _roomTypeIcons[room.type] ?? Icons.square_outlined,
            color: EquaColors.primaryDark,
          ),
        ),
        title: Text(room.name, style: theme.textTheme.titleMedium),
        subtitle: Text(
          [
            roomTypeLabels[room.type] ?? room.type,
            if (room.floor != null && room.floor!.isNotEmpty)
              'Piso ${room.floor}',
            if (room.objectCount > 0) '${room.objectCount} objetos',
          ].join(' · '),
        ),
        trailing: const Icon(Icons.chevron_right, color: EquaColors.inkSoft),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RoomDetailScreen(roomId: room.id),
          ),
        ),
      ),
    );
  }
}

/// Formulario para crear una habitación.
class _RoomFormSheet extends ConsumerStatefulWidget {
  const _RoomFormSheet({this.existing});

  final Room? existing;

  @override
  ConsumerState<_RoomFormSheet> createState() => _RoomFormSheetState();
}

class _RoomFormSheetState extends ConsumerState<_RoomFormSheet> {
  final _name = TextEditingController();
  final _floor = TextEditingController();
  String _type = 'bedroom';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _name.text = widget.existing!.name;
      _floor.text = widget.existing!.floor ?? '';
      _type = widget.existing!.type;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _floor.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final rooms = ref.read(roomsProvider.notifier);
      final floor = _floor.text.trim();
      if (widget.existing == null) {
        await rooms.addRoom(name, _type, floor.isEmpty ? null : floor);
      } else {
        await rooms.updateRoom(
          widget.existing!.id,
          name: name,
          floor: floor.isEmpty ? null : floor,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: EquaSpace.lg,
        right: EquaSpace.lg,
        top: EquaSpace.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + EquaSpace.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? 'Nueva habitación' : 'Editar habitación',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: EquaSpace.md),
          TextField(
            key: const Key('roomNameField'),
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Ej. Cocina, Cuarto de Ana',
            ),
          ),
          const SizedBox(height: EquaSpace.md),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: [
              for (final e in roomTypeLabels.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _type = v ?? 'other'),
          ),
          const SizedBox(height: EquaSpace.md),
          TextField(
            controller: _floor,
            decoration: const InputDecoration(
              labelText: 'Piso (opcional)',
              hintText: 'Ej. 1, Planta baja',
            ),
          ),
          const SizedBox(height: EquaSpace.lg),
          ElevatedButton(
            key: const Key('saveRoom'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Guardando…' : 'Guardar'),
          ),
        ],
      ),
    );
  }
}
