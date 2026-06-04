// sleep_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/sleep_content.dart';
import '../services/sleep_engine.dart';
import '../themes/sky_theme.dart';

// ════════════════════════════════════════════════════════════════
// 1. SCREEN
// ════════════════════════════════════════════════════════════════

class SleepVuiScreen extends ConsumerStatefulWidget {
  const SleepVuiScreen({super.key});

  @override
  ConsumerState<SleepVuiScreen> createState() => _SleepVuiScreenState();
}

class _SleepVuiScreenState extends ConsumerState<SleepVuiScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _pulseController;
  late Animation<double>   _pulseAnim;
  final TextEditingController _textController   = TextEditingController();
  final ScrollController      _scrollController = ScrollController();

  // ── Theme state ────────────────────────────────────────────────
  late SkyPeriod _period;
  bool           _isManualOverride = false;
  Timer?         _overrideTimer;
  Timer?         _realTimeTimer;

  static const Duration _kOverrideDuration = Duration(minutes: 3);

  static SkyPeriod _nextPeriod(SkyPeriod p) {
    const cycle = SkyPeriod.values;
    return cycle[(p.index + 1) % cycle.length];
  }

  void _toggleTheme() {
    final actual    = computeSkyPeriod();
    final newPeriod = _nextPeriod(_period);
    setState(() => _period = newPeriod);

    if (newPeriod != actual) {
      _isManualOverride = true;
      _overrideTimer?.cancel();
      _overrideTimer = Timer(_kOverrideDuration, _revertToRealTheme);

      final snackTheme = themeForPeriod(newPeriod);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: snackTheme.chipBg,
        content: Text(
          '${snackTheme.celestialEmoji} Preview: ${newPeriod.name} · reverts in 3 min',
          style: TextStyle(color: snackTheme.textPrimary),
        ),
        duration: const Duration(seconds: 3),
      ));
    } else {
      _isManualOverride = false;
      _overrideTimer?.cancel();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  void _revertToRealTheme() {
    if (!mounted) return;
    final actual = computeSkyPeriod();
    setState(() { _period = actual; _isManualOverride = false; });
    final snackTheme = themeForPeriod(actual);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: snackTheme.chipBg,
      content: Text(
        '${snackTheme.celestialEmoji} Back to real time · ${actual.name}',
        style: TextStyle(color: snackTheme.textPrimary),
      ),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  void initState() {
    super.initState();

    _period = computeSkyPeriod();
    assert(() {
      debugPrint('SleepScreen init — local hour: ${DateTime.now().toLocal().hour}, period: ${_period.name}');
      return true;
    }());

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _realTimeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!_isManualOverride && mounted) {
        final actual = computeSkyPeriod();
        if (actual != _period) setState(() => _period = actual);
      }
    });
  }

  @override
  void dispose() {
    _overrideTimer?.cancel();
    _realTimeTimer?.cancel();
    _pulseController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(sleepVuiNotifierProvider);
    final notifier = ref.read(sleepVuiNotifierProvider.notifier);
    final theme    = themeForPeriod(_period);

    ref.listen<SleepVuiState>(sleepVuiNotifierProvider, (prev, next) {
      if (next.pendingRoute != null) {
        notifier.clearPendingRoute();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: theme.chipBg,
            content: Text('Navigating to ${next.pendingRoute}',
                style: TextStyle(color: theme.textPrimary)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      if (next.history.length != (prev?.history.length ?? 0)) {
        _scrollToBottom();
      }
    });

    final bool isListening  = state.status == SleepVuiStatus.listening;
    final bool isProcessing = state.status == SleepVuiStatus.processing;
    final bool isSpeaking   = state.status == SleepVuiStatus.speaking;
    final bool isBusy       = isListening || isProcessing || isSpeaking;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      color: theme.gradientColors[0],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: BackButton(color: theme.textPrimary),
          title: Text(
            'Sleep hygiene',
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.3,
            ),
          ),
          centerTitle: true,
          actions: [
            _SkyControlButton(
              label: _isManualOverride
                  ? '${theme.nextPeriodIcon}·'
                  : theme.nextPeriodIcon,
              onTap: _toggleTheme,
              color: theme.textPrimary,
            ),
            const SizedBox(width: 8),
          ],
        ),

        body: Stack(
          children: [
            // ── Animated background ──────────────────────────────
            Positioned.fill(
              child: _SkyBackground(
                scrollController: _scrollController,
                period:           _period,
              ),
            ),

            // ── Content ──────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  _MicSection(
                    isListening:   isListening,
                    isBusy:        isBusy,
                    pulseAnim:     _pulseAnim,
                    status:        state.status,
                    accentColor:   theme.accentColor,
                    textSecondary: theme.textSecondary,
                    onTap: () {
                      if (isListening) {
                        notifier.stopListening();
                      } else if (!isBusy) {
                        notifier.startVoiceTurn();
                      }
                    },
                  ),

                  if (state.status == SleepVuiStatus.error &&
                      state.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.red.shade700.withOpacity(0.5)),
                        ),
                        child: Text(state.errorMessage!,
                            style: TextStyle(
                                color: Colors.red.shade200, fontSize: 13)),
                      ),
                    ),

                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...state.history.map((msg) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ChatBubble(
                              text:    msg.text,
                              isUser:  msg.isUser,
                              theme:   theme,
                              intentLabel: (!msg.isUser && msg.intent != null)
                                  ? _intentLabel(msg.intent!, msg.confidence ?? 0)
                                  : null,
                            ),
                          )),

                          if (state.tips != null && state.tips!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            ...state.tips!.map((t) =>
                                _SleepTipCard(tip: t, theme: theme)),
                          ],

                          if (state.routineSteps != null &&
                              state.routineSteps!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _RoutineStepper(
                                steps: state.routineSteps!, theme: theme),
                          ],

                          if (state.suggestions != null &&
                              state.suggestions!.isNotEmpty &&
                              !isBusy) ...[
                            const SizedBox(height: 12),
                            _SuggestionChips(
                              suggestions: state.suggestions!,
                              theme:       theme,
                              onTap: (s) => notifier.sendSuggestion(s),
                            ),
                          ],

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  _TextInputBar(
                    controller: _textController,
                    enabled:    !isBusy,
                    theme:      theme,
                    onSend: () {
                      final text = _textController.text.trim();
                      if (text.isEmpty) return;
                      _textController.clear();
                      notifier.sendTextMessage(text);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _intentLabel(SleepIntent intent, double confidence) {
    final pct = (confidence * 100).toStringAsFixed(0);
    return 'intent: ${intent.name}  $pct%';
  }
}

// ════════════════════════════════════════════════════════════════
// 2. SKY CONTROL BUTTON
// ════════════════════════════════════════════════════════════════

class _SkyControlButton extends StatelessWidget {
  final IconData?    icon;
  final String?      label;
  final VoidCallback onTap;
  final Color        color;

  const _SkyControlButton({
    this.icon,
    this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.12),
        ),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(icon, color: color, size: 18)
            : Text(label!, style: const TextStyle(fontSize: 15)),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 3. SKY BACKGROUND
// ════════════════════════════════════════════════════════════════

class _SkyBackground extends StatefulWidget {
  final ScrollController scrollController;
  final SkyPeriod        period;

  const _SkyBackground({
    required this.scrollController,
    required this.period,
  });

  @override
  State<_SkyBackground> createState() => _SkyBackgroundState();
}

class _SkyBackgroundState extends State<_SkyBackground>
    with TickerProviderStateMixin {

  late AnimationController _cloudDrift;
  late Animation<double>   _cloudDriftAnim;

  late AnimationController _celestialRise;
  late Animation<double>   _celestialRiseAnim;

  late AnimationController _entryController;
  late Animation<double>   _entryAnim;
  bool _entryDone = false;

  double _scrollOffset = 0.0;

  static const List<List<double>> _stars = [
    [0.05,0.04,2.5],[0.15,0.10,1.5],[0.28,0.07,2.0],[0.42,0.03,1.5],
    [0.55,0.09,2.5],[0.68,0.05,1.5],[0.80,0.12,2.0],[0.92,0.04,2.5],
    [0.10,0.18,1.5],[0.35,0.22,2.0],[0.60,0.17,1.5],[0.78,0.25,2.0],
    [0.90,0.20,1.5],[0.20,0.32,2.5],[0.48,0.30,1.5],[0.72,0.35,2.0],
    [0.85,0.40,1.5],[0.08,0.45,2.0],[0.33,0.50,1.5],[0.55,0.48,2.5],
    [0.70,0.55,1.5],[0.88,0.52,2.0],[0.18,0.60,1.5],[0.40,0.65,2.0],
    [0.62,0.62,1.5],[0.80,0.68,2.5],[0.05,0.72,1.5],[0.25,0.75,2.0],
    [0.50,0.78,1.5],[0.75,0.80,2.0],[0.93,0.75,1.5],[0.12,0.85,2.5],
    [0.38,0.88,1.5],[0.60,0.90,2.0],[0.82,0.92,1.5],
  ];

  @override
  void initState() {
    super.initState();

    _cloudDrift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
    _cloudDriftAnim = Tween<double>(begin: 0, end: 1).animate(_cloudDrift);

    _celestialRise = AnimationController(
      vsync: this,
      duration: themeForPeriod(widget.period).celestialDuration,
      value:    clockProgressForPeriod(widget.period),
    );
    _celestialRiseAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _celestialRise, curve: Curves.easeInOut),
    );
    _celestialRise.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _celestialRise.value = clockProgressForPeriod(widget.period);
        _celestialRise.forward();
      }
    });
    _celestialRise.forward();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _entryAnim = CurvedAnimation(
      parent: _entryController,
      curve:  Curves.easeOutCubic,
    );
    _entryController.forward().then((_) {
      if (mounted) setState(() => _entryDone = true);
    });

    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(_SkyBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.period != oldWidget.period) {
      _celestialRise.duration = themeForPeriod(widget.period).celestialDuration;
      _celestialRise.value    = clockProgressForPeriod(widget.period);
      _celestialRise.forward();
    }
  }

  @override
  void dispose() {
    _cloudDrift.dispose();
    _celestialRise.dispose();
    _entryController.dispose();
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (mounted) setState(() => _scrollOffset = widget.scrollController.offset);
  }

  @override
  Widget build(BuildContext context) {
    final w     = MediaQuery.of(context).size.width;
    final h     = MediaQuery.of(context).size.height;
    final theme = themeForPeriod(widget.period);
    final isNight = widget.period == SkyPeriod.night;

    return AnimatedBuilder(
      animation: Listenable.merge([_cloudDriftAnim, _celestialRiseAnim, _entryAnim]),
      builder: (context, _) {
        final scrollParallax = _scrollOffset * 0.3;

        double cloudPos(double phase) =>
            (h + 80) - ((_cloudDriftAnim.value + phase) % 1.0) * (h + 200);

        final cloud1Base = cloudPos(0.0)  - scrollParallax;
        final cloud2Base = cloudPos(0.33) - scrollParallax * 0.7;
        final cloud3Base = cloudPos(0.66) - scrollParallax * 0.5;

        final entryLift = _entryDone ? 0.0 : (1.0 - _entryAnim.value) * 300.0;

        final t = _celestialRiseAnim.value;
        const pad  = 60.0;
        const apex = 80.0;
        const base = 180.0;
        const k    = (base - apex) / 0.25;

        final arcY      = apex + k * (t - 0.5) * (t - 0.5);
        final celestialX = -pad + t * (w + 2 * pad);
        final celestialY = arcY;

        final entrySlide = _entryDone
            ? 0.0
            : (1.0 - _entryAnim.value) * (isNight ? -120.0 : 120.0);

        return Stack(
          children: [
            // ── Sky gradient ─────────────────────────────────────
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin:  Alignment.topCenter,
                    end:    Alignment.bottomCenter,
                    colors: theme.gradientColors,
                    stops:  theme.gradientStops,
                  ),
                ),
              ),
            ),

            // ── Nebula glow 1 ─────────────────────────────────────
            Positioned(
              top: -60, right: -80,
              child: Container(
                width: 280, height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    theme.nebulaColor1.withOpacity(0.07),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),

            // ── Nebula glow 2 ─────────────────────────────────────
            Positioned(
              bottom: -40, left: -60,
              child: Container(
                width: 220, height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    theme.nebulaColor2.withOpacity(0.08),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),

            // ── Stars (night only) ────────────────────────────────
            if (theme.showStars)
              ..._stars.asMap().entries.map((e) {
                final i = e.key;
                final s = e.value;
                return Positioned(
                  left: w * s[0],
                  top:  h * s[1],
                  child: Container(
                    width: s[2], height: s[2],
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Colors.white),
                  )
                      .animate(
                    onPlay: (c) => c.repeat(reverse: true),
                    delay: Duration(milliseconds: i * 180),
                  )
                      .custom(
                    duration: Duration(milliseconds: 1400 + (i % 5) * 200),
                    builder: (_, v, child) =>
                        Opacity(opacity: 0.15 + v * 0.75, child: child),
                  ),
                );
              }),

            // ── Sun glow halo ─────────────────────────────────────
            if (theme.showHorizonGlow)
              Positioned(
                left: celestialX + entrySlide - 38,
                top:  celestialY - 38,
                child: Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      theme.horizonGlowColor.withOpacity(theme.horizonGlowOpacity),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),

            // ── Celestial body ────────────────────────────────────
            Positioned(
              left: celestialX + entrySlide,
              top:  celestialY,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                child: Text(
                  theme.celestialEmoji,
                  key: ValueKey(widget.period),
                  style: TextStyle(fontSize: theme.celestialSize),
                ),
              ),
            ),

            // ── Cloud 1 — left ────────────────────────────────────
            Positioned(
              left: -8,
              top:  cloud1Base + entryLift,
              child: Opacity(
                opacity: theme.cloudOpacityPrimary,
                child: Text('☁️',
                    style: TextStyle(fontSize: isNight ? 64.0 : 72.0)),
              ),
            ),

            // ── Cloud 2 — right ───────────────────────────────────
            Positioned(
              right: -12,
              top:   cloud2Base + entryLift,
              child: Opacity(
                opacity: theme.cloudOpacitySecondary,
                child: Text('☁️',
                    style: TextStyle(fontSize: isNight ? 48.0 : 56.0)),
              ),
            ),

            // ── Cloud 3 — mid (when theme enables it) ─────────────
            if (theme.showThirdCloud)
              Positioned(
                left: w * 0.3,
                top:  cloud3Base + entryLift,
                child: Opacity(
                  opacity: 0.6,
                  child: const Text('☁️', style: TextStyle(fontSize: 52)),
                ),
              ),

            // ── Horizon glow bar (bottom) ─────────────────────────
            if (theme.showHorizonGlow)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end:   Alignment.topCenter,
                      colors: [
                        theme.horizonGlowColor
                            .withOpacity(theme.horizonGlowOpacity),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 4. MIC SECTION
// ════════════════════════════════════════════════════════════════

class _MicSection extends StatelessWidget {
  final bool              isListening;
  final bool              isBusy;
  final Animation<double> pulseAnim;
  final SleepVuiStatus    status;
  final Color             accentColor;
  final Color             textSecondary;
  final VoidCallback      onTap;

  const _MicSection({
    required this.isListening,
    required this.isBusy,
    required this.pulseAnim,
    required this.status,
    required this.accentColor,
    required this.textSecondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MicButton(
            isListening: isListening,
            isBusy:      isBusy,
            pulseAnim:   pulseAnim,
            accentColor: accentColor,
            onTap:       onTap,
          ),
          if (isBusy) ...[
            const SizedBox(height: 10),
            Text(_label(status),
                style: TextStyle(fontSize: 13, color: textSecondary)),
          ],
        ],
      ),
    );
  }

  String _label(SleepVuiStatus s) {
    switch (s) {
      case SleepVuiStatus.listening:  return 'Listening…';
      case SleepVuiStatus.processing: return 'Thinking…';
      case SleepVuiStatus.speaking:   return 'Speaking…';
      default:                         return '';
    }
  }
}

// ════════════════════════════════════════════════════════════════
// 5. MIC BUTTON
// ════════════════════════════════════════════════════════════════

class _MicButton extends StatelessWidget {
  final bool              isListening;
  final bool              isBusy;
  final Animation<double> pulseAnim;
  final Color             accentColor;
  final VoidCallback      onTap;

  const _MicButton({
    required this.isListening,
    required this.isBusy,
    required this.pulseAnim,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final circle = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130, height: 130,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isListening
              ? accentColor.withOpacity(0.15)
              : Colors.white.withOpacity(0.08),
          border: Border.all(
            color: isListening
                ? accentColor.withOpacity(0.6)
                : Colors.white.withOpacity(0.15),
            width: 1.5,
          ),
          boxShadow: isListening
              ? [BoxShadow(
              color: accentColor.withOpacity(0.25),
              blurRadius: 28, spreadRadius: 4)]
              : [],
        ),
        child: Icon(
          isListening ? Icons.stop_rounded : Icons.mic,
          size: 44,
          color: isListening ? accentColor : Colors.white.withOpacity(0.85),
        ),
      ),
    );

    if (isListening) {
      return AnimatedBuilder(
        animation: pulseAnim,
        builder: (_, child) =>
            Transform.scale(scale: pulseAnim.value, child: child),
        child: circle,
      );
    }
    return circle;
  }
}

// ════════════════════════════════════════════════════════════════
// 6. CHAT BUBBLE
// ════════════════════════════════════════════════════════════════

class _ChatBubble extends StatelessWidget {
  final String   text;
  final bool     isUser;
  final SkyTheme theme;
  final String?  intentLabel;

  const _ChatBubble({
    required this.text,
    required this.isUser,
    required this.theme,
    this.intentLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
      isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isUser ? theme.userBubble : theme.assistBubble,
            borderRadius: BorderRadius.only(
              topLeft:     const Radius.circular(16),
              topRight:    const Radius.circular(16),
              bottomLeft:  Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            border: Border.all(
              color: isUser
                  ? theme.accentColor.withOpacity(0.2)
                  : Colors.white.withOpacity(0.06),
              width: 1,
            ),
          ),
          child: Text(text,
              style: TextStyle(
                  fontSize: 14, height: 1.5,
                  color: isUser ? theme.textPrimary : theme.textSecondary)),
        ),
        if (intentLabel != null)
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 4),
            child: Text(intentLabel!,
                style: TextStyle(
                    fontSize: 11,
                    color: theme.textSecondary.withOpacity(0.5))),
          ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 7. SUGGESTION CHIPS
// ════════════════════════════════════════════════════════════════

class _SuggestionChips extends StatelessWidget {
  final List<String>         suggestions;
  final SkyTheme             theme;
  final ValueChanged<String> onTap;

  const _SuggestionChips({
    required this.suggestions,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: suggestions.map((s) => GestureDetector(
        onTap: () => onTap(s),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color:        theme.chipBg,
            borderRadius: BorderRadius.circular(20),
            border:       Border.all(color: theme.chipBorder),
          ),
          child: Text(s,
              style: TextStyle(fontSize: 13, color: theme.textSecondary)),
        ),
      )).toList(),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 8. SLEEP TIP CARD
// ════════════════════════════════════════════════════════════════

class _SleepTipCard extends StatelessWidget {
  final SleepTip tip;
  final SkyTheme theme;
  const _SleepTipCard({required this.tip, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        theme.assistBubble,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.accentColor.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tip.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tip.title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimary, fontSize: 14)),
                const SizedBox(height: 3),
                Text(tip.body,
                    style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 13, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 9. ROUTINE STEPPER
// ════════════════════════════════════════════════════════════════

class _RoutineStepper extends StatelessWidget {
  final List<String> steps;
  final SkyTheme     theme;
  const _RoutineStepper({required this.steps, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color:        theme.assistBubble,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.accentColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('🌙', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text('30-min wind-down',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.accentColor, fontSize: 14)),
          ]),
          const SizedBox(height: 10),
          ...steps.asMap().entries.map((e) => _StepRow(
            index:  e.key,
            text:   e.value,
            isLast: e.key == steps.length - 1,
            theme:  theme,
          )),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int      index;
  final String   text;
  final bool     isLast;
  final SkyTheme theme;

  const _StepRow({
    required this.index,
    required this.text,
    required this.isLast,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(children: [
              Container(
                width: 8, height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.accentColor.withOpacity(0.7),
                ),
              ),
              if (!isLast)
                Expanded(child: Container(
                    width: 1.5,
                    color: theme.accentColor.withOpacity(0.25))),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(text,
                  style: TextStyle(
                      height: 1.5, color: theme.textSecondary, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 10. TEXT INPUT BAR
// ════════════════════════════════════════════════════════════════

class _TextInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool         enabled;
  final SkyTheme     theme;
  final VoidCallback onSend;

  const _TextInputBar({
    required this.controller,
    required this.enabled,
    required this.theme,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      decoration: BoxDecoration(
        color: theme.inputBg,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller:  controller,
              enabled:     enabled,
              onSubmitted: (_) => onSend(),
              style: TextStyle(fontSize: 14, color: theme.textPrimary),
              cursorColor: theme.accentColor,
              decoration: InputDecoration(
                hintText:  'or type here…',
                hintStyle: TextStyle(
                    color: theme.textSecondary.withOpacity(0.5), fontSize: 14),
                filled:    true,
                fillColor: theme.inputFill,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:   BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.08), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                      color: theme.accentColor.withOpacity(0.4), width: 1),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: enabled ? onSend : null,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled
                    ? theme.accentColor.withOpacity(0.2)
                    : Colors.white.withOpacity(0.05),
                border: Border.all(
                  color: enabled
                      ? theme.accentColor.withOpacity(0.5)
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Icon(
                Icons.arrow_upward_rounded,
                color: enabled ? theme.accentColor : Colors.white.withOpacity(0.3),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}