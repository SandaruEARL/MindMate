import 'package:flutter/material.dart';
import 'package:mindmate/features/emergency_support/widget/voice_mic_button_emergency_support.dart';
import '../models/emergency_contact.dart';
import '../controllers/emergency_support_controller.dart';

class EmergencySupportPage extends StatefulWidget {
  const EmergencySupportPage({super.key});

  @override
  State<EmergencySupportPage> createState() => _EmergencySupportPageState();
}

class _EmergencySupportPageState extends State<EmergencySupportPage> {
  final EmergencySupportController _controller = EmergencySupportController();

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  Future<void> _editNumber(EmergencyContact contact) async {
    final textController = TextEditingController(text: _controller.numberFor(contact));
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit number — ${contact.title}'),
        content: TextField(
          controller: textController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: 'Enter phone number',
            prefixIcon: Icon(Icons.phone),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newNumber = textController.text.trim();
              await _controller.saveNumber(contact.key, newNumber);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: cs.surface,
          appBar: AppBar(
            title: const Text(
              'Emergency Support',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: cs.onSurface,
          ),
          body: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: _Banner(pendingCall: _controller.pendingCall),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Emergency Contacts',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 160),
                      children: [
                        ...emergencyContacts.map(
                          (c) => _ContactCard(
                            contact: c,
                            number: _controller.numberFor(c),
                            isPending: _controller.pendingCall?.key == c.key,
                            onTap: () => _controller.onContactTap(c),
                            onEdit: () => _editNumber(c),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Declarative Dialog Overlay for Confirmation
              if (_controller.pendingCall != null)
                Container(
                  color: Colors.black.withOpacity(0.6),
                  alignment: Alignment.topCenter,
                  padding: const EdgeInsets.fromLTRB(16, 60, 16, 0),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _controller.pendingCall!.color.withOpacity(0.4),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _controller.pendingCall!.color.withOpacity(0.12),
                            ),
                            child: Icon(_controller.pendingCall!.icon, color: _controller.pendingCall!.color, size: 32),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Call ${_controller.pendingCall!.title}?',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _controller.pendingCall!.color,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: _controller.pendingCall!.color.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.phone_rounded, color: _controller.pendingCall!.color, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  _controller.numberFor(_controller.pendingCall!),
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: _controller.pendingCall!.color,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _controller.isListening ? Icons.mic_rounded : Icons.mic_off_rounded,
                                size: 16,
                                color: _controller.isListening ? _controller.pendingCall!.color : cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _controller.isListening ? 'Listening for your voice…' : 'Say "confirm" or "cancel"',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _controller.isListening ? _controller.pendingCall!.color : cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _controller.handleConfirmation('confirm'),
                                  icon: const Icon(Icons.call_rounded),
                                  label: const Text('Confirm'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _controller.pendingCall!.color,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _controller.handleConfirmation('cancel'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: BorderSide(color: _controller.pendingCall!.color.withOpacity(0.4)),
                                  ),
                                  child: const Text('Cancel', style: TextStyle(fontSize: 15)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 32,
                child: VoiceMicButtonEmergencySupport(
                  isListening: _controller.isListening,
                  onTap: _controller.onMicTap,
                  statusLabel: _controller.statusLabel,
                  recognizedText: _controller.isListening ? _controller.recognizedText : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  const _Banner({this.pendingCall});
  final EmergencyContact? pendingCall;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFE05C5C).withOpacity(0.85),
            const Color(0xFFE05C5C).withOpacity(0.50),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🆘  You are not alone',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            pendingCall != null
                ? 'Say "confirm" to call, or "cancel" to go back.'
                : 'Help is always available. Tap a contact or use your voice.',
            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.number,
    required this.onTap,
    required this.onEdit,
    this.isPending = false,
  });

  final EmergencyContact contact;
  final String number;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasNumber = number.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isPending ? contact.color.withOpacity(0.15) : contact.color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: contact.color.withOpacity(isPending ? 0.5 : 0.2),
            width: isPending ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: contact.color.withOpacity(0.18),
              child: Icon(contact.icon, color: contact.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    hasNumber ? number : 'Tap ✏️ to add number',
                    style: TextStyle(
                      color: hasNumber ? contact.color : cs.onSurfaceVariant,
                      fontWeight: hasNumber ? FontWeight.bold : FontWeight.normal,
                      fontSize: hasNumber ? 15 : 13,
                      fontStyle: hasNumber ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                  Text(contact.subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            IconButton(
              onPressed: onEdit,
              icon: Icon(Icons.edit_rounded, size: 18, color: cs.onSurfaceVariant),
              tooltip: 'Edit number',
            ),
            if (hasNumber) Icon(Icons.call_rounded, color: contact.color, size: 20),
          ],
        ),
      ),
    );
  }
}
