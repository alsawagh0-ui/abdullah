import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/enums.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';

/// C2
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});
  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _name = TextEditingController();
  GroupType _type = GroupType.home;
  bool _approval = false;
  bool _gamification = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.createGroup)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, autofocus: true, decoration: InputDecoration(labelText: s.groupName, hintText: 'البيت'), onChanged: (_) => setState(() {}), textInputAction: TextInputAction.done),
          const SizedBox(height: 20),
          Text(s.groupType, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in GroupType.values)
                ChoiceChip(
                  avatar: Icon(GroupIcon.iconFor(t), size: 18),
                  label: Text(s.groupTypeLabel(t)),
                  selected: _type == t,
                  onSelected: (_) => setState(() {
                    _type = t;
                    if (t == GroupType.company || t == GroupType.department || t == GroupType.team) _approval = true;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SwitchListTile(value: _approval, onChanged: (v) => setState(() => _approval = v), title: Text(s.requiresApprovalDefault), subtitle: Text(s.requiresApprovalDefaultHint, style: const TextStyle(fontSize: 12)), contentPadding: EdgeInsets.zero),
          SwitchListTile(value: _gamification, onChanged: (v) => setState(() => _gamification = v), title: Text(s.gamification), subtitle: Text(s.gamificationHint, style: const TextStyle(fontSize: 12)), contentPadding: EdgeInsets.zero),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _name.text.trim().isEmpty
                ? null
                : () async {
                    final g = await guard(context, () => api.createGroup(name: _name.text.trim(), type: _type, settings: GroupSettings(requiresApprovalDefault: _approval, gamificationEnabled: _gamification)));
                    if (g != null && context.mounted) context.pushReplacement('/group/${g.id}/invite');
                  },
            child: Text(s.create),
          ),
        ],
      ),
    );
  }
}
