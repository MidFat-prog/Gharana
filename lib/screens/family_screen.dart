import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state   = StateProvider.of(context);
    final members = state.members;
    final isAdmin = state.currentUser?.role == MemberRole.admin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Family'),
        actions: const [],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [

          // ── Household card ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F2040), Color(0xFF1A3A6B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: const Text('گھ', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(state.household?.name ?? 'My Household', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                  Text(state.household?.city ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ]),
              ]),
              const SizedBox(height: 18),
              Container(height: 0.5, color: Colors.white24),
              const SizedBox(height: 14),
              Row(children: [
                // FIX: removed backslash — was '\${members.length}', now correctly interpolates
                _HouseholdStat(label: 'Members', value: '${members.length}'),
                _HouseholdStat(label: 'Plan',    value: 'Family'),
                _HouseholdStat(label: 'Role',    value: state.currentUser?.roleLabel ?? ''),
              ]),
              if (isAdmin && state.household != null) ...[
                const SizedBox(height: 14),
                Container(height: 0.5, color: Colors.white24),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Invite Code', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                      state.household!.inviteCode,
                      style: const TextStyle(color: Colors.white, fontSize: 26,
                          fontWeight: FontWeight.w800, letterSpacing: 6),
                    ),
                  ]),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: state.household!.inviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Row(children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            'Invite code ${state.household!.inviteCode} copied!',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          )),
                        ]),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        duration: const Duration(seconds: 3),
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(children: [
                        Icon(Icons.share_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('Share', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ]),
              ],
            ]),
          ),

          const SectionHeader(title: 'Members'),
          ...members.map((m) => _MemberCard(
            member: m,
            state:  state,
            isAdmin: isAdmin,
            isCurrentUser: state.currentUser?.id == m.id,
            onEdit:   () => _showMemberForm(context, state, m),  // m is always non-null here
            onRemove: () => _confirmRemove(context, state, m),
          )),

          const SectionHeader(title: 'Activity Overview'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: members.map((m) {
                final txCount = state.transactions.where((t) => t.memberId == m.id).length;
                final spent   = state.spentByMember(m.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(children: [
                    AvatarWidget(initials: m.initials, color: m.color, size: 38),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                      Text('$txCount transactions this month',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ])),
                    Text(state.formatAmount(spent),
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: m.color)),
                  ]),
                );
              }).toList(),
            ),
          ),

          if (!isAdmin) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceWarm,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(children: const [
                Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Expanded(child: Text('Only the Admin can add or remove members.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  // Edit existing member only — no direct add (members must register + join via invite code)
  void _showMemberForm(BuildContext context, AppState state, AppMember existing) {
    final nameCtrl  = TextEditingController(text: existing.name);
    final phoneCtrl = TextEditingController(text: existing.phone);
    MemberRole selectedRole = existing.role;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => StatefulBuilder(builder: (ctx, setLocal) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Edit Member', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_rounded, color: AppColors.primary, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_rounded, color: AppColors.primary, size: 20),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Role', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(children: MemberRole.values.map((role) {
              final label = role == MemberRole.admin ? 'Admin' : role == MemberRole.manager ? 'Manager' : 'Spender';
              final active = selectedRole == role;
              return Expanded(child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setLocal(() => selectedRole = role),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary.withOpacity(0.1) : AppColors.surfaceWarm,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: active ? AppColors.primary : AppColors.divider),
                    ),
                    alignment: Alignment.center,
                    child: Text(label, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: active ? AppColors.primary : AppColors.textSecondary,
                    )),
                  ),
                ),
              ));
            }).toList()),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final name  = nameCtrl.text.trim();
                  final phone = phoneCtrl.text.trim();
                  if (name.isEmpty || phone.isEmpty) return;
                  state.updateMember(existing.copyWith(name: name, phone: phone, role: selectedRole));
                  Navigator.pop(context);
                },
                child: const Text('Save Changes'),
              ),
            ),
          ]),
        );
      }),
    );
  }

  void _showInviteDialog(BuildContext context, AppState state) {
    final code = state.household!.inviteCode;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Invite Family Member', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Share this code with your family member. They register in the app and enter this code to join.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.surfaceWarm,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Text(code,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                  letterSpacing: 8, color: AppColors.primary),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context, AppState state, AppMember m) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Member', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Remove ${m.name} from the household?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () { state.removeMember(m.id); Navigator.pop(context); },
            child: const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _HouseholdStat extends StatelessWidget {
  final String label, value;
  const _HouseholdStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
    Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
  ]));
}

class _MemberCard extends StatelessWidget {
  final AppMember member;
  final AppState state;
  final bool isAdmin;
  final bool isCurrentUser;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  const _MemberCard({required this.member, required this.state, required this.isAdmin,
    required this.isCurrentUser, required this.onEdit, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final m = member;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isCurrentUser ? m.color.withOpacity(0.3) : AppColors.divider),
      ),
      child: Row(children: [
        Stack(children: [
          AvatarWidget(initials: m.initials, color: m.color, size: 48),
          if (isCurrentUser) Positioned(right: 0, bottom: 0,
              child: Container(width: 14, height: 14,
                decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2)),
              )),
        ]),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
            if (isCurrentUser) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: const Text('You', style: TextStyle(fontSize: 9, color: AppColors.accent, fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
          const SizedBox(height: 3),
          Row(children: [
            _RoleBadge(role: m.role, color: m.color),
            const SizedBox(width: 8),
            Text(m.phone, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
          ]),
        ])),
        if (isAdmin)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textLight),
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (v) { if (v == 'edit') onEdit(); else if (v == 'remove') onRemove(); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit',
                  child: Row(children: [Icon(Icons.edit_rounded, size: 16, color: AppColors.textSecondary), SizedBox(width: 8), Text('Edit')])),
              if (!isCurrentUser)
                const PopupMenuItem(value: 'remove',
                    child: Row(children: [Icon(Icons.person_remove_rounded, size: 16, color: AppColors.error), SizedBox(width: 8), Text('Remove', style: TextStyle(color: AppColors.error))])),
            ],
          ),
      ]),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final MemberRole role; final Color color;
  const _RoleBadge({required this.role, required this.color});

  IconData get _icon => role == MemberRole.admin ? Icons.shield_rounded
      : role == MemberRole.manager ? Icons.manage_accounts_rounded : Icons.person_rounded;
  String get _label => role == MemberRole.admin ? 'Admin'
      : role == MemberRole.manager ? 'Manager' : 'Spender';

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(_icon, size: 11, color: color),
    const SizedBox(width: 3),
    Text(_label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  ]);
}