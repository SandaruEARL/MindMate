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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest.withOpacity(0.4),
        border: Border.symmetric(
          horizontal: BorderSide(color: cs.outlineVariant.withOpacity(0.3)),
        ),
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
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    mainAxisAlignment: msg.isUser
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!msg.isUser) ...[
                        CircleAvatar(
                          backgroundColor: accent.withOpacity(0.15),
                          radius: 16,
                          child: Icon(Icons.auto_awesome, color: accent, size: 16),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: msg.isUser ? accent : accent.withOpacity(0.08),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: Radius.circular(msg.isUser ? 20 : 4),
                              bottomRight: Radius.circular(msg.isUser ? 4 : 20),
                            ),
                          ),
                          child: Text(
                            msg.text,
                            style: TextStyle(
                              color: msg.isUser
                                  ? Colors.white
                                  : cs.onSurface,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                      if (msg.isUser) ...[
                        const SizedBox(width: 12),
                        CircleAvatar(
                          backgroundColor: cs.surfaceContainerHighest,
                          radius: 16,
                          child: Icon(
                            Icons.person,
                            color: cs.onSurfaceVariant,
                            size: 18,
                          ),
                        ),
                      ],
                    ],
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
