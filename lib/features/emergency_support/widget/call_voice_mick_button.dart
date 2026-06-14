import 'package:flutter/material.dart';

// ── VoiceMicButton ────────────────────────────────────────────────────────────
//
// A self-contained, reusable microphone button with a pulse animation.
// Drop it anywhere in the app — just pass [isListening] and [onTap].
//
// Example usage:
//
//   VoiceMicButton(
//     isListening: _isListening,
//     onTap: _onMicTap,
//   )
//
// Optional parameters let you tweak size, colours and the status label
// shown beneath the button.

class CallVoiceMickButton extends StatefulWidget {
  const CallVoiceMickButton({
    super.key,
    required this.isListening,
    required this.onTap,
    this.size = 100,
    this.statusLabel,
    this.recognizedText,
    this.activeColor,
    this.idleColor,
  });

  /// Whether the mic is currently recording.
  final bool isListening;

  /// Called when the user taps the button.
  final VoidCallback onTap;

  /// Diameter of the circular button (default 100).
  final double size;

  /// Optional status text shown below the button.
  /// Falls back to 'Listening…' / 'Tap the mic and speak'.
  final String? statusLabel;

  /// Partial recognised text shown above the button while listening.
  final String? recognizedText;

  /// Button colour while listening (defaults to [ColorScheme.error]).
  final Color? activeColor;

  /// Button colour while idle (defaults to [ColorScheme.primary]).
  final Color? idleColor;

  @override
  State<CallVoiceMickButton> createState() => _CallVoiceMickButtonState();
}

class _CallVoiceMickButtonState extends State<CallVoiceMickButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(CallVoiceMickButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Start / stop the pulse whenever isListening changes.
    if (widget.isListening && !oldWidget.isListening) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isListening && oldWidget.isListening) {
      _pulseController
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final defaultStatus = widget.isListening
        ? 'Listening…'
        : 'Tap the mic and speak';
    final statusText = widget.statusLabel ?? defaultStatus;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Pulsing mic button ────────────────────────────────────
        ScaleTransition(
          scale: _pulseAnim,
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF3F51B5),
              ),
              child: Icon(
                widget.isListening ? Icons.stop_rounded : Icons.mic_rounded,
                size: widget.size * 0.6,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Recognised text (shown while listening) ──────────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: (widget.recognizedText?.isNotEmpty ?? false)
              ? Padding(
                  key: const ValueKey('recognized'),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '"${widget.recognizedText}"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : const SizedBox(key: ValueKey('empty')),
        ),

        const SizedBox(height: 12),

        // ── Status label ──────────────────────────────────────────
        Text(
          statusText,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
