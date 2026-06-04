import 'package:flutter/material.dart';

// ── Team member data ──────────────────────────────────────────────────────────

class TeamMember {
  const TeamMember({
    required this.id,
    required this.name,
    required this.feature,
    required this.role,
    required this.color,
  });

  final String id;
  final String name;
  final String feature;
  final String role;
  final Color color;
}

const List<TeamMember> teamMembers = [
  TeamMember(
    id: 'CT/2020/012',
    name: 'Herman P.H.S.L',
    role: 'Group Leader, Developer',
    feature: 'Sleep hygiene tips & bedtime routines',
    color: Color(0xFF3F51B5),
  ),
  TeamMember(
    id: 'CT/2020/027',
    name: 'Kumara J.A.C.D',
    role: 'UI/UX Designer, DevOps Engineer',
    feature: 'Mood tracking & daily emotional check-ins',
    color: Color(0xFF3F51B5),
  ),
  TeamMember(
    id: 'CT/2020/046',
    name: 'Dangampola E.R',
    role: 'Developer',
    feature: 'Mindfulness & meditation guidance',
    color: Color(0xFF3F51B5),
  ),
  TeamMember(
    id: 'CT/2020/075',
    name: 'Rathnayaka H.M.T.C.B',
    role: 'Architect, Developer',
    feature: 'Professional help & emergency contacts',
    color: Color(0xFF3F51B5),
  ),
  TeamMember(
    id: 'CT/2020/086',
    name: 'Jayawickrama G.K.W',
    role: 'QA Engineer, Developer',
    feature: 'Breathing exercises & guided relaxation',
    color: Color(0xFF3F51B5),
  ),
];

// ── Public helper to open the sheet ──────────────────────────────────────────

void showAboutUsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (_) => const AboutUsSheet(),
  );
}

// ── AboutUsSheet ──────────────────────────────────────────────────────────────

class AboutUsSheet extends StatelessWidget {
  const AboutUsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 16, bottom: 16),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/uok_logo.png',
                      height: 48,
                      width: 48,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.account_balance,
                        size: 40,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Speech Interface',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'SWST 44042 • Group C',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  'Voice User Interface (VUI) for Mental Health & Wellbeing Support - Continuous Assessment',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Divider(
                height: 1,
                thickness: 1,
                color: colorScheme.outlineVariant.withOpacity(0.3),
              ),

              const SizedBox(height: 8),

              // Members list
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 40),
                  itemCount: teamMembers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 28),
                  itemBuilder: (context, index) {
                    final member = teamMembers[index];
                    return MinimalMemberRow(member: member);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Member Row ────────────────────────────────────────────────────────────────

class MinimalMemberRow extends StatelessWidget {
  const MinimalMemberRow({super.key, required this.member});

  final TeamMember member;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 4),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name + CT Number (same line)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      member.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),

                  Text(
                    member.id,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 2),

              // Role
              Text(
                member.role,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: member.color,
                ),
              ),

              const SizedBox(height: 6),

              // Feature
              Text(
                member.feature,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
