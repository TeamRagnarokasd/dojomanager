import 'package:flutter/material.dart';

import '../../../services/asd_governance_service.dart';

/// "Consiglio direttivo": view/add/edit/delete asd_board_members (full name
/// + role). Opened from the Scadenzario app bar.
class AsdBoardMembersSheet extends StatefulWidget {
  const AsdBoardMembersSheet({Key? key}) : super(key: key);

  @override
  State<AsdBoardMembersSheet> createState() => _AsdBoardMembersSheetState();
}

class _AsdBoardMembersSheetState extends State<AsdBoardMembersSheet> {
  final _service = AsdGovernanceService.instance;

  bool _isLoading = true;
  List<AsdBoardMember> _members = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final members = await _service.getBoardMembers();
      if (!mounted) return;
      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Errore nel caricamento: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _showMemberDialog({AsdBoardMember? member}) async {
    final nameController = TextEditingController(text: member?.fullName ?? '');
    var selectedRole = member?.role ?? kAsdBoardRoleKeys.first;
    var isActive = member?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(member == null ? 'Nuovo membro' : 'Modifica membro'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nome e cognome'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Campo obbligatorio' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(labelText: 'Ruolo'),
                  items: kAsdBoardRoleKeys
                      .map((key) => DropdownMenuItem(
                            value: key,
                            child: Text(asdBoardRoleLabel(key)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedRole = value);
                    }
                  },
                ),
                if (member != null) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Attivo'),
                    value: isActive,
                    onChanged: (value) => setDialogState(() => isActive = value),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    try {
      if (member == null) {
        await _service.addBoardMember(
          fullName: nameController.text.trim(),
          role: selectedRole,
        );
      } else {
        await _service.updateBoardMember(
          member.id,
          fullName: nameController.text.trim(),
          role: selectedRole,
          isActive: isActive,
        );
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il salvataggio: $e')),
      );
    }
  }

  Future<void> _confirmDelete(AsdBoardMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare questo membro?'),
        content: Text('Eliminare "${member.fullName}" dal consiglio direttivo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteBoardMember(member.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante l\'eliminazione: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Consiglio direttivo',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.person_add_alt_1),
                    tooltip: 'Aggiungi membro',
                    onPressed: () => _showMemberDialog(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _members.isEmpty
                          ? const Center(child: Text('Nessun membro inserito.'))
                          : ListView.builder(
                              controller: scrollController,
                              padding: EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                MediaQuery.of(context).viewPadding.bottom + 24,
                              ),
                              itemCount: _members.length,
                              itemBuilder: (context, index) {
                                final member = _members[index];
                                return ListTile(
                                  title: Text(
                                    member.fullName,
                                    style: TextStyle(
                                      color: member.isActive ? null : Colors.grey,
                                    ),
                                  ),
                                  subtitle: Text(
                                    member.isActive
                                        ? asdBoardRoleLabel(member.role)
                                        : '${asdBoardRoleLabel(member.role)} (non attivo)',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 20),
                                        onPressed: () =>
                                            _showMemberDialog(member: member),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 20),
                                        onPressed: () => _confirmDelete(member),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        );
      },
    );
  }
}
