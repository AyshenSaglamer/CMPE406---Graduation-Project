import 'package:flutter/material.dart';

import '../data/care_store.dart';
import '../services/api_exception.dart';
import '../widgets/ai_chat_button.dart';

/// The patient's care team: invite a doctor or caregiver by the email of
/// their DiaMate account, see who has access or has not answered yet, and
/// stop sharing. The invited person accepts in their own app.
class CareTeamScreen extends StatefulWidget {
  const CareTeamScreen({super.key, this.store});

  /// Defaults to [careStore]; tests pass one with a fake backend.
  final CareStore? store;

  @override
  State<CareTeamScreen> createState() => _CareTeamScreenState();
}

class _CareTeamScreenState extends State<CareTeamScreen> {
  static const _blue = Color(0xFF168AF7);
  static const _muted = Color(0xFF718096);
  static const _red = Color(0xFFE85D75);

  /// Same rule as the register screen.
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<CareRelationship> relationships = [];
  bool isLoading = true;
  String? loadError;
  bool isInviting = false;
  String? inviteError;

  CareStore get _store => widget.store ?? careStore;

  List<CareRelationship> get _open =>
      relationships.where((r) => r.isOpen).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final result = await _store.list();

      if (!mounted) {
        return;
      }

      setState(() {
        relationships = result;
        isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        loadError = e.message;
      });
    }
  }

  Future<void> _invite() async {
    setState(() {
      inviteError = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isInviting = true;
    });

    try {
      final created = await _store.invite(_emailController.text);

      if (!mounted) {
        return;
      }

      setState(() {
        isInviting = false;
        relationships = [created, ...relationships];
        _emailController.clear();
      });

      _showMessage(
        'Invitation sent to ${created.memberName.isEmpty ? created.memberEmail : created.memberName}.',
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isInviting = false;
        inviteError = e.fieldErrors['memberEmail'] ?? e.message;
      });
    }
  }

  Future<void> _revoke(CareRelationship relationship) async {
    final who = relationship.memberName.isEmpty
        ? relationship.memberEmail
        : relationship.memberName;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          relationship.isPending ? 'Cancel invitation?' : 'Stop sharing?',
        ),
        content: Text(
          relationship.isPending
              ? 'The invitation to $who will be withdrawn.'
              : '$who will no longer see your health data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: _red),
            child: Text(relationship.isPending ? 'Withdraw' : 'Stop sharing'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await _store.revoke(relationship.id);
    } on ApiException catch (e) {
      if (mounted) {
        _showMessage(e.message);
      }
      return;
    }

    if (!mounted) {
      return;
    }

    _showMessage(
      relationship.isPending
          ? 'Invitation withdrawn.'
          : '$who no longer has access.',
    );
    _load();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: const AiChatButton(),
      backgroundColor: const Color(0xFFF7FAFD),
      appBar: AppBar(
        title: const Text('Care Team'),
        backgroundColor: const Color(0xFFF7FAFD),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            _buildInviteCard(),
            const SizedBox(height: 22),
            const Text(
              'People with access',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            ..._buildList(),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.person_add_alt_1_rounded, color: _blue),
                  SizedBox(width: 8),
                  Text(
                    'Invite your doctor or caregiver',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter the email of their DiaMate account. After they accept, '
                'they can see your glucose, meals, insulin and activity and '
                'receive your alerts.',
                style: TextStyle(fontSize: 12, height: 1.4, color: _muted),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.send,
                onFieldSubmitted: (_) => _invite(),
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'doctor@example.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  errorText: inviteError,
                  errorMaxLines: 3,
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) {
                    return 'Please enter an email.';
                  }
                  if (!_emailPattern.hasMatch(email)) {
                    return 'Please enter a valid email.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: isInviting ? null : _invite,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(isInviting ? 'Sending…' : 'Send invitation'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildList() {
    if (isLoading && relationships.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (loadError != null) {
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Text(loadError!, textAlign: TextAlign.center),
                TextButton(onPressed: _load, child: const Text('Try again')),
              ],
            ),
          ),
        ),
      ];
    }

    final open = _open;

    if (open.isEmpty) {
      return const [
        Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Nobody can see your data yet. Invite your doctor or a '
              'family member above.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _muted),
            ),
          ),
        ),
      ];
    }

    return [
      for (final r in open)
        _CareMemberTile(relationship: r, onRemove: () => _revoke(r)),
    ];
  }
}

class _CareMemberTile extends StatelessWidget {
  const _CareMemberTile({required this.relationship, required this.onRemove});

  final CareRelationship relationship;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final r = relationship;

    final Color statusColor;
    if (r.isPending) {
      statusColor = const Color(0xFFF0A126);
    } else if (r.hasAccess) {
      statusColor = const Color(0xFF35B779);
    } else {
      statusColor = const Color(0xFF9AA8B7);
    }

    final name = r.memberName.isEmpty ? r.memberEmail : r.memberName;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEAF5FF),
          child: Icon(
            r.isClinician
                ? Icons.medical_services_rounded
                : Icons.family_restroom_rounded,
            color: const Color(0xFF168AF7),
            size: 20,
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(r.roleLabel, style: const TextStyle(fontSize: 12)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  r.statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        trailing: IconButton(
          tooltip: r.isPending ? 'Withdraw invitation' : 'Stop sharing',
          icon: const Icon(Icons.person_remove_outlined,
              color: Color(0xFF9AA8B7)),
          onPressed: onRemove,
        ),
      ),
    );
  }
}
