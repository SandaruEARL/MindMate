import 'package:flutter/material.dart';

class VoiceMicButtonEmergencySupport extends StatefulWidget {
  const VoiceMicButtonEmergencySupport({
    super.key,
    required this.isListening,
    required this.onTap,
    this.statusLabel,
    this.recognizedText,
    this.size = 88,
  });

  final bool isListening;
  final VoidCallback onTap;
  final String? statusLabel;
  final String? recognizedText;
  final double size;

  @override
  State<VoiceMicButtonEmergencySupport> createState() =>
      _VoiceMicButtonEmergencySupportState();
}

class _VoiceMicButtonEmergencySupportState
    extends State<VoiceMicButtonEmergencySupport>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _ring1;
  late Animation<double> _ring2;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _ring1 = Tween<double>(
      begin: 1.0,
      end: 1.35,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    _ring2 = Tween<double>(begin: 1.0, end: 1.55).animate(
      CurvedAnimation(
        parent: _pulse,
        curve: const Interval(0.35, 1.0, curve: Curves.easeInOut),
      ),
    );
  }

  @override
  void didUpdateWidget(VoiceMicButtonEmergencySupport old) {
    super.didUpdateWidget(old);
    if (widget.isListening && !old.isListening) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isListening && old.isListening) {
      _pulse.stop();
      _pulse.reset();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeColor = const Color(0xFFE05C5C);
    final idleColor = const Color(0xFF3F51B5);
    final btnColor = widget.isListening ? activeColor : idleColor;
    final s = widget.size;

    final statusText =
        widget.statusLabel ??
        (widget.isListening ? 'Listening…' : 'Tap the mic to speak');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulse rings + button  ← NOW FIRST
        GestureDetector(
          onTap: widget.onTap,
          child: SizedBox(
            width: s + 44,
            height: s + 22,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (widget.isListening)
                  AnimatedBuilder(
                    animation: _ring2,
                    builder: (_, __) => Transform.scale(
                      scale: _ring2.value,
                      child: Container(
                        width: s,
                        height: s,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: btnColor.withOpacity(0.15),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (widget.isListening)
                  AnimatedBuilder(
                    animation: _ring1,
                    builder: (_, __) => Transform.scale(
                      scale: _ring1.value,
                      child: Container(
                        width: s,
                        height: s,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: btnColor.withOpacity(0.30),
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: s,
                  height: s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: btnColor,
                  ),
                  child: Icon(
                    widget.isListening ? Icons.stop_rounded : Icons.mic_rounded,
                    size: s * 0.45,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 0),

        // Status label  ← NOW BELOW
        Text(
          statusText,
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),

        // Recognised text  ← NOW BELOW
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: (widget.recognizedText?.isNotEmpty ?? false)
              ? Padding(
                  key: const ValueKey('rec'),
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '"${widget.recognizedText}"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                )
              : const SizedBox(key: ValueKey('empty'), height: 0),
        ),
      ],
    );
  }
}
