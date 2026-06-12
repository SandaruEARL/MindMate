import 'package:flutter/material.dart';
import 'package:mindmate/features/mindfulness/controllers/mindfulness_controller.dart';

/// Chat / VUI conversation log widget.
/// Displays the conversation history between the user and the VUI.
class MindfulnessChatLog extends StatefulWidget {
  final List<MindfulnessMessage> chatHistory;

  const MindfulnessChatLog({super.key, required this.chatHistory});

  @override
  State<MindfulnessChatLog> createState() => _MindfulnessChatLogState();
}

class _MindfulnessChatLogState extends State<MindfulnessChatLog> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant MindfulnessChatLog oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll to latest message when history grows
    if (widget.chatHistory.length != oldWidget.chatHistory.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0); // reversed list, so 0 = latest
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const accent = Color(0xFF9C6FDE);

    return Container(
      height: 250,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.forum_rounded, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                'Mindfulness and Meditation Conversation',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurfaceVariant.withOpacity(0.8),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              itemCount: widget.chatHistory.length,
              itemBuilder: (context, index) {
                final msg = widget.chatHistory[widget.chatHistory.length - 1 - index];
                return Align(
                  alignment:
                      msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: msg.isUser
                          ? accent.withOpacity(0.15)
                          : cs.surfaceContainerHighest.withOpacity(0.6),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: Radius.circular(msg.isUser ? 12 : 4),
                        bottomRight: Radius.circular(msg.isUser ? 4 : 12),
                      ),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(fontSize: 13, color: cs.onSurface),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
