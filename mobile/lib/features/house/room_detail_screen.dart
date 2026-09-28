import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../design_system/colors.dart';
import '../../design_system/theme.dart';
import 'house_controller.dart';

/// Detalle de una habitación: objetos registrados (manuales ahora;
/// los detectados por IA llegan en fases siguientes y se marcan con
/// "revisar" hasta confirmarlos).
class RoomDetailScreen extends ConsumerWidget {
  const RoomDetailScreen({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final detail = ref.watch(roomDetailProvider(roomId));

    return Scaffold(
      appBar: AppBar(
        title: detail.when(
          data: (r) => Text(r.name),
          loading: () => const Text('Habitación'),
          error: (_, _) => const Text('Habitación'),
        ),
        actions: [
          IconButton(
            tooltip: 'Eliminar habitación',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteRoom(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('addObject'),
        onPressed: () => _showObjectForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Objeto'),
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(apiErrorMessage(e))),
        data: (room) => ListView(
          padding: const EdgeInsets.all(EquaSpace.lg),
          children: [
            Text(
              [
                roomTypeLabels[room.type] ?? room.type,
                if (room.floor != null && room.floor!.isNotEmpty)
                  'Piso ${room.floor}',
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: EquaSpace.md),
            Text('Objetos', style: theme.textTheme.titleMedium),
            const SizedBox(height: EquaSpace.sm),
            if (room.objects.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: EquaSpace.xl),
                child: Text(
                  'Aún no hay objetos. Agrégalos a mano o déjalos para la foto '
                  'de la habitación (fase de IA).',
                  style: theme.textTheme.bodySmall,
                ),
              )
            else
              for (final obj in room.objects) ...[
                _ObjectTile(roomId: roomId, object: obj),
                const SizedBox(height: EquaSpace.sm),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _deleteRoom(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar habitación'),
        content: const Text(
          'Se eliminarán también sus objetos. Las tareas asociadas '
          'a esta habitación quedarán sin espacio asignado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await ref.read(roomsProvider.notifier).deleteRoom(roomId);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  Future<void> _showObjectForm(BuildContext context, WidgetRef ref) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ObjectFormSheet(roomId: roomId),
    );
    if (saved == true) {
      ref.invalidate(roomDetailProvider(roomId));
      ref.invalidate(roomsProvider);
    }
  }
}

class _ObjectTile extends ConsumerWidget {
  const _ObjectTile({required this.roomId, required this.object});

  final String roomId;
  final RoomObject object;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pending = object.source == 'ai' && !object.confirmed;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: EquaColors.secondary.withValues(alpha: 0.3),
          child: const Icon(Icons.chair_outlined, color: EquaColors.ink),
        ),
        title: Text(object.name),
        subtitle: pending ? const Text('Detectado por IA — por confirmar') : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Quitar uno',
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: object.quantity <= 1
                  ? () => _delete(context, ref)
                  : () => _update(ref, quantity: object.quantity - 1),
            ),
            Text('${object.quantity}', style: theme.textTheme.titleMedium),
            IconButton(
              tooltip: 'Agregar uno',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _update(ref, quantity: object.quantity + 1),
            ),
            IconButton(
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _delete(context, ref),
            ),
          ],
        ),
        onTap: pending
            ? () => _update(ref, confirmed: true)
            : null,
      ),
    );
  }

  Future<void> _update(
    WidgetRef ref, {
    int? quantity,
    bool? confirmed,
  }) async {
    try {
      await ref.read(roomsProvider.notifier).updateObject(
            roomId,
            object.id,
            quantity: quantity,
            confirmed: confirmed,
          );
    } catch (_) {/* el provider recarga en el próximo intento */}
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(roomsProvider.notifier).deleteObject(roomId, object.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }
}

class _ObjectFormSheet extends ConsumerStatefulWidget {
  const _ObjectFormSheet({required this.roomId});

  final String roomId;

  @override
  ConsumerState<_ObjectFormSheet> createState() => _ObjectFormSheetState();
}

class _ObjectFormSheetState extends ConsumerState<_ObjectFormSheet> {
  final _name = TextEditingController();
  int _quantity = 1;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(roomsProvider.notifier)
          .addObject(widget.roomId, name, _quantity);
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
    final theme = Theme.of(context);
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
          Text('Nuevo objeto', style: theme.textTheme.titleMedium),
          const SizedBox(height: EquaSpace.md),
          TextField(
            key: const Key('objectNameField'),
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Ej. Lavadora, Espejo, Planta',
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: EquaSpace.md),
          Row(
            children: [
              Text('Cantidad', style: theme.textTheme.bodyMedium),
              const Spacer(),
              IconButton(
                onPressed: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_quantity', style: theme.textTheme.titleMedium),
              IconButton(
                onPressed: () => setState(() => _quantity++),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: EquaSpace.lg),
          ElevatedButton(
            key: const Key('saveObject'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Guardando…' : 'Guardar'),
          ),
        ],
      ),
    );
  }
}
