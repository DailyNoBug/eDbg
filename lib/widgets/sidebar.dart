import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/app_state.dart';
import '../core/models.dart';


class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(registryProvider);
    final selected = ref.watch(selectedVarsProvider);
    return ListView(
      children: registry.entries.map((e) {
        final type = e.key; final keys = e.value.toList()..sort();
        return ExpansionTile(title: Text(type), children: [
          for (final k in keys)
            CheckboxListTile(
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: selected.contains(VariablePath(type, k)),
              title: Text(k),
              onChanged: (v) {
                final vp = VariablePath(type, k);
                final set = {...ref.read(selectedVarsProvider)};
                if (v == true) set.add(vp); else set.remove(vp);
                ref.read(selectedVarsProvider.notifier).state = set;
              },
            )
        ]);
      }).toList(),
    );
  }
}