import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mindmate/core/widgets/voice_mic_button.dart';
import 'package:mindmate/features/mindfulness/controllers/mindfulness_controller.dart';
import 'package:mindmate/features/mindfulness/services/mindfulness_session_data.dart';
import 'package:mindmate/features/mindfulness/widgets/mindful_progress_indicator.dart';
import 'package:mindmate/features/mindfulness/widgets/mindfulness_chat_log.dart';
import 'package:mindmate/features/mindfulness/widgets/mindfulness_session_card.dart';

class MindfulnessPage extends StatefulWidget {
  const MindfulnessPage({super.key});

  @override
  State<MindfulnessPage> createState() => _MindfulnessPageState();
}

class _MindfulnessPageState extends State<MindfulnessPage>
    with TickerProviderStateMixin {
  late final MindfulnessController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = MindfulnessController(vsync: this);
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });
    _ctrl.init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ctrl.attachContext(context);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Tab-toggle pill button ─────────────────────────────────────────────────

  Widget _tabButton({
    required String id,
    required String label,
    required IconData icon,
    required Color accent,
    required ColorScheme cs,
  }) {
    final active = _ctrl.activeTab == id;
    return GestureDetector(
      onTap: () => _ctrl.setActiveTab(active ? 'chat' : id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? accent.withOpacity(0.18)
              : cs.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? accent : cs.outlineVariant.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: active ? accent : cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: active ? cs.onSurface : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Active session info card ──────────────────────────────────────────────

  Map<String, dynamic>? _currentSessionData() {
    for (final s in [...kMindfulnessSessions, ...kGuidedMeditationSessions]) {
      if (_ctrl.sessionLabel.contains(s['title'] as String)) return s;
    }
    return null;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const accent = Color(0xFF9C6FDE);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Mindfulness & Meditation'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: cs.onSurface,
      ),
      body: Stack(
        children: [
          // ── Scrollable content ───────────────────────────────────────────
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: GestureDetector(
                onTap: () {
                  if (!_ctrl.isPlaying && _ctrl.activeTab != 'chat') {
                    _ctrl.setActiveTab('chat');
                  }
                },
                behavior: HitTestBehavior.translucent,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 280),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Progress indicator + tab toggles ─────────────────
                      Center(
                        child: Column(
                          children: [
                            AnimatedBuilder(
                              animation: _ctrl.progressController,
                              builder: (_, __) => GestureDetector(
                                onTap: () {
                                  if (_ctrl.isPlaying) {
                                    _ctrl.stopSession();
                                  } else if (_ctrl.activeTab != 'chat') {
                                    _ctrl.setActiveTab('chat');
                                  }
                                },
                                child: Tooltip(
                                  message: _ctrl.isPlaying
                                      ? 'Tap to stop session'
                                      : '',
                                  child: MindfulProgressIndicator(
                                    progress: _ctrl.progressController.value,
                                    isPlaying: _ctrl.isPlaying,
                                    accentColor: accent,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Tab toggles (only when not playing)
                            if (!_ctrl.isPlaying)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _tabButton(
                                    id: 'mindfulness',
                                    label: 'Mindfulness',
                                    icon: Icons.self_improvement_rounded,
                                    accent: accent,
                                    cs: cs,
                                  ),
                                  const SizedBox(width: 12),
                                  _tabButton(
                                    id: 'guided',
                                    label: 'Guided Meditation',
                                    icon: Icons.spa_rounded,
                                    accent: accent,
                                    cs: cs,
                                  ),
                                ],
                              )
                            else ...[
                              // Active session info card
                              Builder(builder: (_) {
                                final data = _currentSessionData();
                                if (data == null) return const SizedBox.shrink();
                                return ActiveSessionCard(
                                  session: data,
                                  progressController: _ctrl.progressController,
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Chat log (default view + while playing) ──────────
                      if (_ctrl.activeTab == 'chat' || _ctrl.isPlaying)
                        MindfulnessChatLog(chatHistory: _ctrl.chatHistory),

                      // ── Mindfulness sessions list ─────────────────────────
                      if (!_ctrl.isPlaying && _ctrl.activeTab == 'mindfulness') ...[
                        const SizedBox(height: 16),
                        Text(
                          'Mindfulness Sessions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...kMindfulnessSessions.map((s) =>
                            MindfulnessSessionCard(
                              session: s,
                              onTap: () {
                                switch (s['title']) {
                                  case 'Body Scan':
                                    _ctrl.runBodyScan();
                                    break;
                                  case 'Mindful Observation':
                                    _ctrl.runMindfulObservation();
                                    break;
                                  case 'Loving Kindness':
                                    _ctrl.runLovingKindness();
                                    break;
                                }
                              },
                            )),
                      ],

                      // ── Guided meditation list ────────────────────────────
                      if (!_ctrl.isPlaying && _ctrl.activeTab == 'guided') ...[
                        const SizedBox(height: 16),
                        Text(
                          'Guided Meditation Sessions 🎧',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...kGuidedMeditationSessions.map((s) =>
                            MindfulnessSessionCard(
                              session: s,
                              onTap: () {
                                switch (s['title']) {
                                  case 'Beginner Meditation':
                                    _ctrl.runBeginnerMeditation();
                                    break;
                                  case 'Anxiety Reduction':
                                    _ctrl.runAnxietyReduction();
                                    break;
                                  case 'Focus & Concentration':
                                    _ctrl.runFocusConcentration();
                                    break;
                                  case 'Gratitude Meditation':
                                    _ctrl.runGratitudeMeditation();
                                    break;
                                }
                              },
                            )),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Floating mic button (pinned at bottom) ───────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: VoiceMicButton(
                  isListening: _ctrl.isListening,
                  onTap: _ctrl.onMicTap,
                  statusLabel: _ctrl.statusLabel,
                  recognizedText: _ctrl.recognizedText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}