import 'package:flutter/material.dart';
import 'package:mindmate/core/widgets/voice_mic_button.dart';
import '../controllers/mood_tracking_controller.dart';

class MoodTrackingPage extends StatefulWidget {
  const MoodTrackingPage({super.key});

  @override
  State<MoodTrackingPage> createState() => _MoodTrackingPageState();
}

class _MoodTrackingPageState extends State<MoodTrackingPage> {
  late final MoodTrackingController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = MoodTrackingController();
    _controller.onScrollToBottom = _scrollToBottom;
    _controller.init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.attachContext(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final accentColor = _controller.selectedMood?.color ?? const Color(0xFF6C63FF);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                // ── Custom Header ─────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF3F51B5),
                          foregroundColor: Colors.white,
                          shape: const CircleBorder(),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded, size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Mood Tracking',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3F51B5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── TOP: Mood selector ───────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _MoodSelectorGrid(
                    moods: availableMoods,
                    selected: _controller.selectedMood,
                    onSelect: _controller.selectMood,
                    disabled: _controller.isBotThinking,
                  ),
                ),

                // ── PHASE LABEL ──────────────────────────────────────────────
                if (_controller.selectedMood != null)
                  _PhaseLabel(
                    isPreset: _controller.isPresetPhase,
                    isEnded: _controller.conversationEnded,
                    accentColor: accentColor,
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Divider(height: 1, color: Colors.black.withOpacity(0.05)),
                ),

                // ── MIDDLE: Conversational area ──────────────────────────────
                Expanded(
                  child: _ConversationArea(
                    turns: _controller.turns,
                    isBotThinking: _controller.isBotThinking,
                    selectedMood: _controller.selectedMood,
                    scrollController: _scrollController,
                    isEnded: _controller.conversationEnded,
                    accentColor: accentColor,
                  ),
                ),

                // ── BOTTOM: Mic Button ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: _controller.conversationEnded
                      ? _EndedMessage(color: accentColor)
                      : VoiceMicButton(
                          isListening: _controller.isListening,
                          onTap: _controller.onMicTap,
                          statusLabel: _controller.statusLabel,
                          recognizedText: _controller.recognizedText,
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Additional Widgets ────────────────────────────────────────────────────────

class _MoodSelectorGrid extends StatelessWidget {
  const _MoodSelectorGrid({
    required this.moods,
    required this.selected,
    required this.onSelect,
    required this.disabled,
  });

  final List<MoodData> moods;
  final MoodData? selected;
  final void Function(MoodData) onSelect;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < moods.length; i += 3) {
      final first = moods[i];
      final second = i + 1 < moods.length ? moods[i + 1] : null;
      final third = i + 2 < moods.length ? moods[i + 2] : null;

      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _MoodCard3D(
                  mood: first,
                  isSelected: selected?.label == first.label,
                  disabled: disabled,
                  onTap: () => onSelect(first),
                ),
              ),
              const SizedBox(width: 12),
              second != null
                  ? Expanded(
                      child: _MoodCard3D(
                        mood: second,
                        isSelected: selected?.label == second.label,
                        disabled: disabled,
                        onTap: () => onSelect(second),
                      ),
                    )
                  : const Expanded(child: SizedBox()),
              if (second != null) const SizedBox(width: 12),
              third != null
                  ? Expanded(
                      child: _MoodCard3D(
                        mood: third,
                        isSelected: selected?.label == third.label,
                        disabled: disabled,
                        onTap: () => onSelect(third),
                      ),
                    )
                  : const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );
      if (i + 3 < moods.length) rows.add(const SizedBox(height: 12));
    }

    return Column(children: rows);
  }
}

class _MoodCard3D extends StatefulWidget {
  const _MoodCard3D({
    required this.mood,
    required this.isSelected,
    required this.disabled,
    required this.onTap,
  });

  final MoodData mood;
  final bool isSelected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  State<_MoodCard3D> createState() => _MoodCard3DState();
}

class _MoodCard3DState extends State<_MoodCard3D> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.mood.color;
    final hsl = HSLColor.fromColor(color);
    final shadowColor = hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0)).toColor();

    final effectivelyPressed = _isPressed || widget.isSelected;

    return GestureDetector(
      onTapDown: widget.disabled ? null : (_) => setState(() => _isPressed = true),
      onTapUp: widget.disabled ? null : (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          transform: Matrix4.translationValues(0, effectivelyPressed ? 6.0 : 0.0, 0),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: widget.isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: effectivelyPressed
                ? []
                : [BoxShadow(color: widget.isSelected ? Colors.transparent : shadowColor, offset: const Offset(0, 6), blurRadius: 0)],
            border: widget.isSelected ? null : Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.mood.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.mood.label.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: widget.isSelected ? Colors.white : color,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhaseLabel extends StatelessWidget {
  const _PhaseLabel({
    required this.isPreset,
    required this.isEnded,
    required this.accentColor,
  });

  final bool isPreset;
  final bool isEnded;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    if (isEnded) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, size: 14, color: accentColor),
            const SizedBox(width: 6),
            Text('Session complete', style: TextStyle(fontSize: 12, color: accentColor, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
    if (!isPreset) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 14, color: accentColor),
            const SizedBox(width: 6),
            Text('MindMate is here for you', style: TextStyle(fontSize: 12, color: accentColor, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
    return const SizedBox(height: 4);
  }
}

class _ConversationArea extends StatelessWidget {
  const _ConversationArea({
    required this.turns,
    required this.isBotThinking,
    required this.selectedMood,
    required this.scrollController,
    required this.isEnded,
    required this.accentColor,
  });

  final List<ConversationTurn> turns;
  final bool isBotThinking;
  final MoodData? selectedMood;
  final ScrollController scrollController;
  final bool isEnded;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    if (selectedMood == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.waving_hand_rounded, size: 48, color: const Color(0xFF3F51B5).withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(
                'How are you feeling today?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF3F51B5).withOpacity(0.7)),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a mood above or use your voice.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: const Color(0xFF3F51B5).withOpacity(0.5)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      itemCount: turns.length + (isBotThinking ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == turns.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: accentColor.withOpacity(0.15),
                  radius: 16,
                  child: Icon(Icons.more_horiz, color: accentColor, size: 18),
                ),
                const SizedBox(width: 12),
                Text('Thinking…', style: TextStyle(color: accentColor, fontStyle: FontStyle.italic)),
              ],
            ),
          );
        }

        final turn = turns[index];
        final isUser = turn.speaker == SpeakerType.user;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                CircleAvatar(
                  backgroundColor: accentColor.withOpacity(0.15),
                  radius: 16,
                  child: Icon(Icons.auto_awesome, color: accentColor, size: 16),
                ),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? accentColor : accentColor.withOpacity(0.08),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                  ),
                  child: Text(
                    turn.text,
                    style: TextStyle(color: isUser ? Colors.white : Theme.of(context).colorScheme.onSurface, fontSize: 15, height: 1.4),
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 12),
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  radius: 16,
                  child: Icon(Icons.person, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 18),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _EndedMessage extends StatelessWidget {
  const _EndedMessage({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            'Session Finished',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'You can go back home or open another module.',
            textAlign: TextAlign.center,
            style: TextStyle(color: color.withOpacity(0.8), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
