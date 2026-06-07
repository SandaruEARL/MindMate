import 'dart:math' as math;
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';
import 'package:mindmate/core/widgets/voice_mic_button.dart';
import 'package:mindmate/features/emergency_support/screens/emergency_support_page.dart';

class MindfulnessPage extends StatefulWidget {
  const MindfulnessPage({super.key});

  @override
  State<MindfulnessPage> createState() => _MindfulnessPageState();
}

class _MindfulnessPageState extends State<MindfulnessPage>
    with TickerProviderStateMixin {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _stt = stt.SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _progressController;
  final List<Timer> _guidanceTimers = [];

  bool _isPlaying = false;
  String _sessionLabel = 'Tap a session to begin';

  bool _isListening = false;
  bool _sttAvailable = false;
  bool _isProcessing = false;
  String _recognizedText = '';
  String _statusLabel = 'Tap the mic and speak';
  bool _shouldAutoListen = false;
  String _currentState = 'idle'; // 'idle', 'awaiting_meditation_choice', 'awaiting_reflection_response'
  String _detectedEmotion = 'none'; // 'none', 'stress', 'anxiety', 'sleep', 'sad'
  final List<_Message> _chatHistory = [
    _Message("Hello! I am your Mindfulness VUI guide. Tap the microphone to talk to me, or choose a session below.", isUser: false),
  ];

  final List<Map<String, dynamic>> _sessions = [
    {
      'title': 'Body Scan',
      'subtitle': '5 min · Full-body awareness',
      'icon': Icons.accessibility_new_rounded,
      'color': const Color(0xFF9C6FDE),
      'duration': const Duration(minutes: 5),
    },
    {
      'title': 'Mindful Observation',
      'subtitle': '3 min · Focus on the present',
      'icon': Icons.visibility_rounded,
      'color': const Color(0xFF4CAF82),
      'duration': const Duration(minutes: 3),
    },
    {
      'title': 'Loving Kindness',
      'subtitle': '5 min · Compassion meditation',
      'icon': Icons.favorite_rounded,
      'color': const Color(0xFFE05C5C),
      'duration': const Duration(minutes: 5),
    },
  ];

  final List<Map<String, dynamic>> _meditationSessions = [
    {
      'title': 'Beginner Meditation',
      'subtitle': '5 min · Focus on breathing basics',
      'icon': Icons.spa_rounded,
      'color': const Color(0xFF42A5F5),
      'duration': const Duration(minutes: 5),
    },
    {
      'title': 'Anxiety Reduction',
      'subtitle': '5 min · Calm panic and release stress',
      'icon': Icons.healing_rounded,
      'color': const Color(0xFFFF7043),
      'duration': const Duration(minutes: 5),
    },
    {
      'title': 'Focus & Concentration',
      'subtitle': '5 min · Sharpen mind and awareness',
      'icon': Icons.center_focus_strong_rounded,
      'color': const Color(0xFF26A69A),
      'duration': const Duration(minutes: 5),
    },
    {
      'title': 'Gratitude Meditation',
      'subtitle': '5 min · Reflect on life\'s gifts',
      'icon': Icons.volunteer_activism_rounded,
      'color': const Color(0xFFEC407A),
      'duration': const Duration(minutes: 5),
    },
    {
      'title': 'Breathing Exercise',
      'subtitle': '3 min · 4-4-6 breathing cycles',
      'icon': Icons.air_rounded,
      'color': const Color(0xFF00E676),
      'duration': const Duration(minutes: 3),
    },
    {
      'title': 'Sleep Relaxation',
      'subtitle': '5 min · Soothing bedtime routine',
      'icon': Icons.bedtime_rounded,
      'color': const Color(0xFF7986CB),
      'duration': const Duration(minutes: 5),
    },
  ];

  @override
  void initState() {
    super.initState();
    _initStt();
    _initTts();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(minutes: 5),
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onSessionComplete();
      }
    });
  }

  Future<void> _restoreNormalTtsSettings() async {
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _restoreNormalTtsSettings();

    _tts.setErrorHandler((msg) {
      debugPrint("TTS error: $msg");
      if (mounted && _isPlaying) {
        _stopSession();
      }
    });

    _tts.setCompletionHandler(() {
      if (mounted && !_isPlaying && _shouldAutoListen) {
        setState(() {
          _shouldAutoListen = false;
        });
        _startListening();
      }
    });

    await Future.delayed(const Duration(milliseconds: 300));
    await _tts.speak(
      'You are in the Mindfulness page. Choose a session to begin your practice.',
    );
  }

  Future<void> _initStt() async {
    _sttAvailable = await _stt.initialize(
      onError: (e) {
        debugPrint('STT error: $e');
        if (mounted) {
          setState(() {
            _isListening = false;
            _statusLabel = 'Error. Try again.';
          });
        }
      },
      onStatus: (s) {
        debugPrint('STT status: $s');
        if ((s == 'done' || s == 'notListening') && _isListening && mounted) {
          _stopListening();
        }
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _onMicTap() async {
    if (_isPlaying) {
      await _stopSession();
      return;
    }
    _isListening ? _stopListening() : _startListening();
  }

  Future<void> _startListening() async {
    if (!_sttAvailable) {
      await _tts.speak('Speech recognition is not available on this device.');
      return;
    }
    await _tts.stop();
    setState(() {
      _isListening = true;
      _recognizedText = '';
      _statusLabel = 'Listening…';
    });
    await _stt.listen(
      onResult: (r) {
        if (mounted) setState(() => _recognizedText = r.recognizedWords);
      },
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_US',
      cancelOnError: true,
      partialResults: true,
    );
  }

  Future<void> _stopListening() async {
    if (_isProcessing) return;
    _isProcessing = true;
    await _stt.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
        _statusLabel = 'Processing…';
        if (_recognizedText.isNotEmpty) {
          _chatHistory.add(_Message(_recognizedText, isUser: true));
        }
      });
    }
    await _handleVoiceCommand(_recognizedText.toLowerCase());
    _isProcessing = false;
  }

  Future<void> _speakConversationalResponse(String response) async {
    setState(() {
      _chatHistory.add(_Message(response, isUser: false));
      _shouldAutoListen = true;
      _statusLabel = 'Speaking answer…';
    });
    await _tts.speak(response);
  }

  Future<void> _handleVoiceCommand(String text) async {
    if (text.isEmpty) {
      setState(() => _statusLabel = "I didn't catch that. Try again.");
      await _tts.speak("I didn't catch that. Please try again.");
      return;
    }

    // 1. Detect Crisis / Self-Harm cues (VUI Safety & Emergency Trigger)
    if (text.contains('kill myself') ||
        text.contains('suicide') ||
        text.contains('hurt myself') ||
        text.contains('end my life') ||
        text.contains('die') ||
        text.contains('crisis') ||
        text.contains('emergency') ||
        text.contains('self harm') ||
        text.contains('cutting') ||
        text.contains('harming')) {
      setState(() => _statusLabel = 'Redirecting to Emergency Support…');
      final msg = 'I hear how much pain you are in, and I want you to be safe. '
          'I am redirecting you to our emergency support page immediately. Please connect with a professional. You are not alone.';
      _chatHistory.add(_Message(msg, isUser: false));
      await _tts.speak(msg);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EmergencySupportPage()),
        );
      }
      return;
    }

    // 2. Handle state: reflection response (Completion loop feedback)
    if (_currentState == 'awaiting_reflection_response') {
      _currentState = 'idle';
      if (text.contains('better') ||
          text.contains('good') ||
          text.contains('relaxed') ||
          text.contains('calm') ||
          text.contains('fine') ||
          text.contains('peace') ||
          text.contains('well') ||
          text.contains('happy') ||
          text.contains('great')) {
        await _speakConversationalResponse(
          'I am so glad to hear that! Keep carrying this peace and warmth with you as you go about your day.'
        );
      } else {
        await _speakConversationalResponse(
          'That is completely okay, healing takes time. Would you like to try another session later, or talk to me?'
        );
      }
      return;
    }

    // 3. Handle state: choosing meditation option (Turn-taking choice)
    if (_currentState == 'awaiting_meditation_choice') {
      _currentState = 'idle';
      if (text.contains('breathing') || text.contains('one') || text.contains('first')) {
        setState(() => _chatHistory.add(_Message('Starting Breathing Exercise…', isUser: false)));
        await _runBreathingExercise();
      } else if (text.contains('body') || text.contains('scan') || text.contains('two') || text.contains('second')) {
        setState(() => _chatHistory.add(_Message('Starting Body Scan…', isUser: false)));
        await _runBodyScan();
      } else if (text.contains('sleep') || text.contains('relaxation') || text.contains('three') || text.contains('third')) {
        setState(() => _chatHistory.add(_Message('Starting Sleep Relaxation…', isUser: false)));
        await _runSleepRelaxation();
      } else if (text.contains('loving') || text.contains('kindness') || text.contains('four') || text.contains('fourth') || text.contains('compassion')) {
        setState(() => _chatHistory.add(_Message('Starting Loving Kindness…', isUser: false)));
        await _runLovingKindness();
      } else {
        // Auto-select based on the detected emotion
        if (_detectedEmotion == 'stress') {
          await _speakConversationalResponse('Okay, let\'s start with a Body Scan to release that physical stress.');
          await Future.delayed(const Duration(seconds: 4));
          await _runBodyScan();
        } else if (_detectedEmotion == 'anxiety') {
          await _speakConversationalResponse('Okay, let\'s practice our Breathing Exercise to calm your anxiety.');
          await Future.delayed(const Duration(seconds: 4));
          await _runBreathingExercise();
        } else if (_detectedEmotion == 'sleep') {
          await _speakConversationalResponse('Okay, let\'s do a Sleep Relaxation session to wind down for bed.');
          await Future.delayed(const Duration(seconds: 4));
          await _runSleepRelaxation();
        } else if (_detectedEmotion == 'sad') {
          await _speakConversationalResponse('Okay, let\'s practice a Loving Kindness meditation to bring warmth to your heart.');
          await Future.delayed(const Duration(seconds: 4));
          await _runLovingKindness();
        } else {
          await _speakConversationalResponse('I will start a simple Beginner Meditation to help you relax.');
          await Future.delayed(const Duration(seconds: 4));
          await _runBeginnerMeditation();
        }
      }
      return;
    }

    // 4. Detect Panic / High Anxiety / Fear cues (Empathetic VUI Intervention + Suggest choice)
    if (text.contains('panic') ||
        text.contains('scared') ||
        text.contains('cannot breathe') ||
        text.contains('heart is racing') ||
        text.contains('fear') ||
        text.contains('terrified') ||
        text.contains('anxious') ||
        text.contains('anxiety')) {
      _detectedEmotion = 'anxiety';
      _currentState = 'awaiting_meditation_choice';
      await _speakConversationalResponse(
        'I hear that you are feeling anxious right now. Let\'s take a slow breath together. '
        'Would you like to try a Breathing exercise, a Body scan, or a Sleep relaxation session?'
      );
      return;
    }

    // 5. Detect Stress / Feeling Overwhelmed/Tense cues (Empathetic VUI Intervention + Suggest choice)
    if (text.contains('stressed') ||
        text.contains('overwhelmed') ||
        text.contains('pressure') ||
        text.contains('exhausted') ||
        text.contains('tired') ||
        text.contains('tense') ||
        text.contains('stress') ||
        text.contains('relax') ||
        text.contains('relaxing')) {
      _detectedEmotion = 'stress';
      _currentState = 'awaiting_meditation_choice';
      await _speakConversationalResponse(
        'I hear that things feel heavy right now. Let\'s take a moment together. '
        'Would you like to try a Body scan, a Breathing exercise, or a Sleep relaxation session?'
      );
      return;
    }

    // 6. Detect Sleep issues
    if (text.contains('sleep') || text.contains('insomnia') || text.contains('bedtime') || text.contains('restless') || text.contains('cannot sleep')) {
      _detectedEmotion = 'sleep';
      _currentState = 'awaiting_meditation_choice';
      await _speakConversationalResponse(
        'I hear that you\'re having trouble resting. Let\'s get comfortable. '
        'Would you like to try our Sleep relaxation, a Breathing exercise, or a Body scan?'
      );
      return;
    }

    // 7. Detect Sadness / Loneliness cues (Empathetic VUI Intervention + Suggest choice)
    if (text.contains('sad') ||
        text.contains('lonely') ||
        text.contains('depressed') ||
        text.contains('unhappy') ||
        text.contains('crying') ||
        text.contains('hopeless') ||
        text.contains('grief')) {
      _detectedEmotion = 'sad';
      _currentState = 'awaiting_meditation_choice';
      await _speakConversationalResponse(
        'I\'m sorry that you\'re feeling down right now. You are valued and you are not alone. '
        'Would you like to practice a Loving Kindness meditation, a Breathing exercise, or a Body scan?'
      );
      return;
    }

    // 8. Detect Psychoeducation & Mindfulness Informational Queries (Helpful & Safe Insights)
    if (text.contains('what is mindfulness') || text.contains('explain mindfulness')) {
      await _speakConversationalResponse(
        'Mindfulness is the practice of being fully present in the current moment, without judgment. '
        'It helps you observe your thoughts, feelings, and sensations gently, which can reduce stress and increase emotional balance. '
        'Would you like to start a meditation session now, or ask another question?'
      );
      return;
    }

    if (text.contains('what is meditation') || text.contains('why should i meditate') || text.contains('benefits of meditation')) {
      await _speakConversationalResponse(
        'Regular meditation helps calm your nervous system, improves your focus, reduces stress and anxiety, and builds emotional resilience. '
        'It is a gentle way to care for your mind. '
        'Would you like to try one of our guided meditations now, or ask something else?'
      );
      return;
    }

    if (text.contains('what is body scan') || text.contains('explain body scan') || text.contains('how does body scan help')) {
      await _speakConversationalResponse(
        'A body scan is a mindfulness practice where you mentally scan your body from head to toe, paying attention to physical sensations. '
        'It helps you reconnect with your body and release stored physical tension. '
        'Would you like to start the Body Scan session now, or ask another question?'
      );
      return;
    }

    if (text.contains('what is loving kindness') || text.contains('explain loving kindness') || text.contains('compassion meditation')) {
      await _speakConversationalResponse(
        'Loving Kindness meditation involves sending wishes of safety, happiness, and peace to yourself, your loved ones, and eventually all living beings. '
        'It helps cultivate compassion and reduce negative emotions. '
        'Would you like to start the Loving Kindness session now, or ask another question?'
      );
      return;
    }

    if (text.contains('what is mindful observation') || text.contains('explain mindful observation')) {
      await _speakConversationalResponse(
        'Mindful Observation is a practice where you focus your visual attention on a single object in front of you. '
        'It grounds you in the physical present and slows down rapid thoughts. '
        'Would you like to start the Mindful Observation session now, or ask another question?'
      );
      return;
    }

    if (text.contains('what is anxiety') || text.contains('how to manage anxiety') || text.contains('help with anxiety')) {
      await _speakConversationalResponse(
        'Anxiety is a natural response to stress, but it can feel overwhelming. '
        'You can manage it by taking slow, deep breaths, grounding yourself in the present, or doing our Anxiety Reduction meditation. '
        'Would you like me to start the Anxiety Reduction meditation for you now?'
      );
      return;
    }

    if (text.contains('what is stress') || text.contains('how to manage stress') || text.contains('help with stress')) {
      await _speakConversationalResponse(
        'Stress is how your body responds to daily challenges and pressures. '
        'You can manage it by setting boundaries, taking deep breaths, and using a Body Scan or breathing exercises to relax your muscles. '
        'Would you like to try a meditation session now, or ask something else?'
      );
      return;
    }

    if (text.contains('what is depression') || text.contains('help with depression') || text.contains('explain depression')) {
      await _speakConversationalResponse(
        'Depression is a common mental health challenge that can feel like a heavy weight, causing sadness or loss of interest. '
        'Please know that you are not alone, and speaking to a professional or a loved one is a courageous first step. '
        'We also have a Loving Kindness meditation for comfort, or I can guide you to our Emergency Support page. '
        'Would you like to view our Emergency contacts, or start a meditation?'
      );
      return;
    }

    if (text.contains('what can i say') || text.contains('features') || text.contains('how does this work') || text.contains('help')) {
      await _speakConversationalResponse(
        'You can say, "Start Body Scan", "Start Anxiety Reduction", "Start Loving Kindness", or "Start Beginner Meditation". '
        'You can also ask questions like, "What is mindfulness?", "How do I manage anxiety?", or say "Go back". '
        'What would you like to do now?'
      );
      return;
    }

    // 9. Standard command mapping
    if (text.contains('body') || text.contains('scan')) {
      setState(() => _statusLabel = 'Starting Body Scan…');
      await _runBodyScan();
    } else if (text.contains('observation') || text.contains('present') || text.contains('look')) {
      setState(() => _statusLabel = 'Starting Mindful Observation…');
      await _runMindfulObservation();
    } else if (text.contains('loving') || text.contains('kindness') || text.contains('compassion') || text.contains('love')) {
      setState(() => _statusLabel = 'Starting Loving Kindness…');
      await _runLovingKindness();
    } else if (text.contains('beginner') || (text.contains('start') && text.contains('meditation'))) {
      setState(() => _statusLabel = 'Starting Beginner Meditation…');
      await _runBeginnerMeditation();
    } else if (text.contains('anxiety') || text.contains('reduction')) {
      setState(() => _statusLabel = 'Starting Anxiety Reduction…');
      await _runAnxietyReduction();
    } else if (text.contains('focus') || text.contains('concentration') || text.contains('attention')) {
      setState(() => _statusLabel = 'Starting Focus & Concentration…');
      await _runFocusConcentration();
    } else if (text.contains('gratitude') || text.contains('thankful') || text.contains('blessings')) {
      setState(() => _statusLabel = 'Starting Gratitude Meditation…');
      await _runGratitudeMeditation();
    } else if (text.contains('breathing') || text.contains('air') || text.contains('breath')) {
      setState(() => _statusLabel = 'Starting Breathing Exercise…');
      await _runBreathingExercise();
    } else if (text.contains('sleep') || text.contains('bedtime') || text.contains('relaxation')) {
      setState(() => _statusLabel = 'Starting Sleep Relaxation…');
      await _runSleepRelaxation();
    } else if (text.contains('stop') || text.contains('pause') || text.contains('cancel')) {
      setState(() => _statusLabel = 'Stopping practice…');
      await _stopSession();
    } else if (text.contains('back') || text.contains('home') || text.contains('exit')) {
      setState(() => _statusLabel = 'Going back…');
      await _tts.speak('Going back to the home page.');
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      setState(() => _statusLabel = 'Command not recognized. Try saying a session name or "go back".');
      await _tts.speak(
        'I heard "$_recognizedText" but I did not recognize that command. '
        'Try saying: Body Scan, Mindful Observation, Loving Kindness, Beginner Meditation, Anxiety Reduction, Focus, Gratitude, Breathing Exercise, Sleep Relaxation, Stop, or Go Back.',
      );
    }
  }

  void _clearGuidanceTimers() {
    for (final timer in _guidanceTimers) {
      timer.cancel();
    }
    _guidanceTimers.clear();
  }

  Future<void> _startSession({
    required String title,
    required Duration duration,
    required List<Map<String, dynamic>> cues,
    bool playMusic = false,
  }) async {
    if (_isPlaying) return;

    _clearGuidanceTimers();

    setState(() {
      _isPlaying = true;
      _sessionLabel = '$title in progress…';
    });

    _progressController.duration = duration;
    _progressController.reset();
    _progressController.forward();

    if (playMusic) {
      try {
        await _audioPlayer.play(AssetSource('sounds/smooth.mp3'));
        await _audioPlayer.setVolume(0.4);
      } catch (e) {
        debugPrint('Error playing background audio: $e');
      }
    }

    // Configure calm, soft, slow speech settings for the meditation session
    await _tts.setSpeechRate(0.20); // Extremely slow and peaceful speed for meditation
    await _tts.setPitch(0.85);      // Warmer, lower, and more soothing pitch
    await _tts.setVolume(0.65);     // Soft, gentle volume

    // Schedule voice guidance cues
    for (final cue in cues) {
      final offset = cue['offset'] as Duration;
      final text = cue['text'] as String;

      if (offset == Duration.zero) {
        await _tts.speak(text);
      } else {
        final timer = Timer(offset, () async {
          if (mounted && _isPlaying) {
            await _tts.speak(text);
          }
        });
        _guidanceTimers.add(timer);
      }
    }
  }

  Future<void> _runBodyScan() async {
    await _startSession(
      title: 'Body Scan',
      duration: const Duration(minutes: 5),
      cues: [
        {
          'offset': Duration.zero,
          'text': "Welcome... Let's begin the Body Scan meditation... Find a comfortable posture... close your eyes... and allow your arms to rest naturally... Take a deep... slow breath in... and let it out.",
        },
        {
          'offset': const Duration(seconds: 25),
          'text': "Bring your awareness... to the simple sensation of breathing... Feel the air entering your nostrils... filling your lungs... and gently leaving your body... Settle into this present moment.",
        },
        {
          'offset': const Duration(seconds: 50),
          'text': "Now... gently shift your attention... to the top of your head... Focus on your scalp... Notice any sensations here... tingling... heat... or tightness... Just observe.",
        },
        {
          'offset': const Duration(seconds: 75),
          'text': "Move your focus down... to your forehead and eyes... Let your eyelids feel heavy... Relax your cheeks... your lips... and especially your jaw... letting it hang slightly loose.",
        },
        {
          'offset': const Duration(seconds: 100),
          'text': "Let the wave of relaxation... travel down your neck and throat... Now feel your shoulders... If they are raised... let them drop down completely... Breathe warmth... into your shoulders.",
        },
        {
          'offset': const Duration(seconds: 125),
          'text': "Guide your awareness down... through your upper arms... past your elbows... into your forearms... wrists... and hands... Feel the space your hands occupy... Let your fingers soften.",
        },
        {
          'offset': const Duration(seconds: 150),
          'text': "Now... direct your attention to your chest... Feel the physical expansion as you inhale... and the release as you exhale... Notice the steady rhythm... of your heartbeat.",
        },
        {
          'offset': const Duration(seconds: 175),
          'text': "Let your awareness sink down... into your abdomen... Feel the gentle rise and fall of your stomach... Allow your breathing... to be natural... effortless... and deep.",
        },
        {
          'offset': const Duration(seconds: 200),
          'text': "Shift your focus... to your back... Scan your upper back... then slowly move down your spine... to your lower back... Breathe into any areas of tension... and let them soften.",
        },
        {
          'offset': const Duration(seconds: 225),
          'text': "Bring your attention... to your hips and pelvis... Feel the weight of your body pressing down onto the seat... Allow yourself to feel fully supported... and grounded.",
        },
        {
          'offset': const Duration(seconds: 250),
          'text': "Move down into your legs... Feel your thighs... knees... and calves... Let go of any holding or tightness in the muscles... Just let your legs rest... deeply.",
        },
        {
          'offset': const Duration(seconds: 275),
          'text': "Finally... focus on your feet... ankles... and toes... Notice the sensation of touch... where your feet meet the floor... Feel the stability... and support.",
        },
        {
          'offset': const Duration(seconds: 295),
          'text': "Take a deep breath... and feel your entire body... as one unified, relaxed space... You are fully present... and at peace... Gently open your eyes... when you are ready.",
        },
      ],
      playMusic: true,
    );
  }

  Future<void> _runMindfulObservation() async {
    await _startSession(
      title: 'Mindful Observation',
      duration: const Duration(minutes: 3),
      cues: [
        {
          'offset': Duration.zero,
          'text': "Welcome to Mindful Observation... Open your eyes... and choose a single, simple object in front of you... Let your gaze rest on it... with soft, gentle curiosity.",
        },
        {
          'offset': const Duration(seconds: 20),
          'text': "Begin by observing the overall shape of the object... Notice its contours... its silhouette... and its edges... Try to look at it as if you have never seen it before.",
        },
        {
          'offset': const Duration(seconds: 40),
          'text': "Now... focus your attention on the colors... Notice the different shades... how they blend together... and how the light interacts... with the colors.",
        },
        {
          'offset': const Duration(seconds: 60),
          'text': "Observe the texture of its surface... Is it smooth... rough... matte... or glossy?... Imagine how it would feel to the touch... Just observe the visual details.",
        },
        {
          'offset': const Duration(seconds: 80),
          'text': "Notice the play of light and shadow on the object... Where does the light hit it directly?... Where do the shadows fall?... See how these details define its form.",
        },
        {
          'offset': const Duration(seconds: 100),
          'text': "If your mind starts to wander... or you find yourself thinking about other things... that is completely normal... Gently guide your focus back... to looking at the object.",
        },
        {
          'offset': const Duration(seconds: 120),
          'text': "Look even closer now... Notice any small imperfections... dust particles... lines... or details that you didn't see at first... Give the object your full presence.",
        },
        {
          'offset': const Duration(seconds: 140),
          'text': "Observe the space surrounding the object... Notice how it interacts with its environment... the contrast between the object... and the background.",
        },
        {
          'offset': const Duration(seconds: 160),
          'text': "Let go of any thoughts or descriptions... Just enjoy the simple act of seeing... Let your mind be still... and receptive.",
        },
        {
          'offset': const Duration(seconds: 175),
          'text': "Take a deep breath... Slowly bring your focus back to the room... carrying this sense of calm... and clarity... with you.",
        },
      ],
      playMusic: false,
    );
  }

  Future<void> _runLovingKindness() async {
    await _startSession(
      title: 'Loving Kindness',
      duration: const Duration(minutes: 5),
      cues: [
        {
          'offset': Duration.zero,
          'text': "Welcome to Loving Kindness meditation... Close your eyes... settle into your body... and take a slow, deep breath... Let your heart and mind soften.",
        },
        {
          'offset': const Duration(seconds: 25),
          'text': "Bring your awareness... to your heart center... Imagine a warm, glowing light radiating from your chest... filled with kindness and peace.",
        },
        {
          'offset': const Duration(seconds: 50),
          'text': "Think of someone who has loved or helped you deeply... a mentor... a dear friend... or a family member... Visualize them sitting right in front of you.",
        },
        {
          'offset': const Duration(seconds: 75),
          'text': "Send them your heartfelt wishes, repeating silently... May you be happy... May you be healthy... May you be safe... May you live with ease.",
        },
        {
          'offset': const Duration(seconds: 100),
          'text': "Feel the warm energy of these wishes... connecting you to them... Let the feeling of love and appreciation... fill your chest.",
        },
        {
          'offset': const Duration(seconds: 125),
          'text': "Now... bring the focus to yourself... You deserve your own love and compassion... Visualize yourself in your mind's eye.",
        },
        {
          'offset': const Duration(seconds: 150),
          'text': "Direct these same wishes to yourself, repeating silently... May I be happy... May I be healthy... May I be safe... May I live with ease.",
        },
        {
          'offset': const Duration(seconds: 175),
          'text': "Breathe in kindness... and feel it filling every cell of your body... Let go of any self-criticism or judgment... Accept yourself completely.",
        },
        {
          'offset': const Duration(seconds: 200),
          'text': "Now... bring to mind a neutral person... someone you see in daily life... like a coworker or neighbor... but don't know well... Imagine their presence.",
        },
        {
          'offset': const Duration(seconds: 225),
          'text': "Remember that they also experience joys and struggles... just like you... Send them wishes... May you be happy... May you be healthy... May you live with ease.",
        },
        {
          'offset': const Duration(seconds: 250),
          'text': "Finally... expand this feeling of loving-kindness outward... Imagine it spreading to your home... your community... your country... and all living beings everywhere.",
        },
        {
          'offset': const Duration(seconds: 275),
          'text': "Repeat silently... May all beings be happy... May all beings be healthy... May all beings be safe... May all beings live with ease.",
        },
        {
          'offset': const Duration(seconds: 295),
          'text': "Rest in this open, unlimited space of compassion... Take a deep breath... and gently open your eyes... when you feel ready.",
        },
      ],
      playMusic: false,
    );
  }

  Future<void> _runBeginnerMeditation() async {
    await _startSession(
      title: 'Beginner Meditation',
      duration: const Duration(minutes: 5),
      cues: [
        {
          'offset': Duration.zero,
          'text': "Welcome to your beginner meditation... Let's start by finding a comfortable sitting position... Close your eyes softly... and allow your body to settle.",
        },
        {
          'offset': const Duration(seconds: 25),
          'text': "Take a deep, full breath in... hold it for a moment... and exhale slowly... releasing all your thoughts... and entering the present moment.",
        },
        {
          'offset': const Duration(seconds: 50),
          'text': "Now... let your breathing return to its natural rhythm... Don't try to change it... simply observe... the natural flow of your breath.",
        },
        {
          'offset': const Duration(seconds: 75),
          'text': "Notice the sensation... of the breath entering your nose... Feel the coolness as you inhale... and the slight warmth as you exhale... Just focus here.",
        },
        {
          'offset': const Duration(seconds: 100),
          'text': "Feel your chest... and stomach... rise and fall with each breath... Like the waves of the ocean... steady... calming... and soothing.",
        },
        {
          'offset': const Duration(seconds: 125),
          'text': "If thoughts arise... that is completely natural... Simply label them as thinking... and gently return... your focus back to the breath.",
        },
        {
          'offset': const Duration(seconds: 150),
          'text': "Each breath is a fresh start... a new moment to be present... Breathe in clarity... breathe out distraction... Enjoy this quiet space.",
        },
        {
          'offset': const Duration(seconds: 175),
          'text': "Feel the weight of your body... resting on the seat... Feel grounded... secure... and fully supported by the earth below you.",
        },
        {
          'offset': const Duration(seconds: 200),
          'text': "Let your shoulders soften even more... Relax your hands... relax your face... Let a soft smile rest on your lips.",
        },
        {
          'offset': const Duration(seconds: 225),
          'text': "Keep following the breath... all the way in... and all the way out... Feeling the space between each breath... the stillness.",
        },
        {
          'offset': const Duration(seconds: 250),
          'text': "Allow your mind to just be... No goals... no tasks... nothing to accomplish... Just breathing... and resting in this moment.",
        },
        {
          'offset': const Duration(seconds: 275),
          'text': "As we come to the end... take a deep breath... and feel a sense of appreciation... for taking this time for yourself.",
        },
        {
          'offset': const Duration(seconds: 295),
          'text': "Gently wiggle your fingers and toes... Slowly open your eyes... carrying this peace... with you into the rest of your day.",
        },
      ],
      playMusic: false,
    );
  }

  Future<void> _runAnxietyReduction() async {
    await _startSession(
      title: 'Anxiety Reduction',
      duration: const Duration(minutes: 5),
      cues: [
        {
          'offset': Duration.zero,
          'text': "Welcome... This meditation is designed to release anxiety... and bring you back to safety... Sit comfortably... close your eyes... and take a deep breath.",
        },
        {
          'offset': const Duration(seconds: 25),
          'text': "Inhale slowly through your nose... and exhale with a long, soft sigh... letting go... of any tightness in your chest... and shoulders.",
        },
        {
          'offset': const Duration(seconds: 50),
          'text': "Remember... you are safe in this moment... There is nothing you need to fix... nothing you need to figure out right now... Just be here.",
        },
        {
          'offset': const Duration(seconds: 75),
          'text': "If your chest feels tight... place a hand gently over your heart... Feel the warm touch of your hand... and the soft beat... of your heart.",
        },
        {
          'offset': const Duration(seconds: 100),
          'text': "As you breathe in... imagine breathing in cool... soothing blue light... As you breathe out... release any worry or tension... letting it fade away.",
        },
        {
          'offset': const Duration(seconds: 125),
          'text': "With each exhale... feel your muscles releasing their grip... Let your shoulders drop... relax your stomach... let your jaw go loose.",
        },
        {
          'offset': const Duration(seconds: 150),
          'text': "Anxiety is just energy passing through... You do not need to fight it... or judge it... Allow it to flow... like clouds passing in the sky.",
        },
        {
          'offset': const Duration(seconds: 175),
          'text': "Focus on the sensation of your feet on the ground... Feel the strong... steady earth beneath you... supporting you completely... You are grounded.",
        },
        {
          'offset': const Duration(seconds: 200),
          'text': "Repeat silently to yourself... I am safe... I am here... I can handle this... Let these words sink deep... into your mind.",
        },
        {
          'offset': const Duration(seconds: 225),
          'text': "Take a long... slow inhale... counting to four... then hold for four... and exhale for six... This slows down your nervous system... bringing calm.",
        },
        {
          'offset': const Duration(seconds: 250),
          'text': "Feel the quiet space... inside yourself... Beneath the noise of thoughts... there is a deep... undisturbed well of peace... Rest here.",
        },
        {
          'offset': const Duration(seconds: 275),
          'text': "Breathe in peace... breathe out ease... You are doing wonderfully... You have everything you need... to be calm.",
        },
        {
          'offset': const Duration(seconds: 295),
          'text': "Slowly bring your movement back... Take a gentle breath... and open your eyes... knowing you can return to this safety... anytime.",
        },
      ],
      playMusic: false,
    );
  }

  Future<void> _runFocusConcentration() async {
    await _startSession(
      title: 'Focus & Concentration',
      duration: const Duration(minutes: 5),
      cues: [
        {
          'offset': Duration.zero,
          'text': "Welcome... Let's begin the focus and concentration meditation... Sit upright... align your spine... close your eyes... and take a sharp, clear breath.",
        },
        {
          'offset': const Duration(seconds: 25),
          'text': "Bring your attention to a single point... such as the tip of your nose... Notice the sensation of air... moving in... and out... at that exact spot.",
        },
        {
          'offset': const Duration(seconds: 50),
          'text': "As you breathe in... feel your mind becoming alert... and clear... As you breathe out... release any scattered thoughts... or mental fog.",
        },
        {
          'offset': const Duration(seconds: 75),
          'text': "Keep your focus laser-sharp... on the inhalation... and the exhalation... If your mind drifts even slightly... gently but firmly... bring it back.",
        },
        {
          'offset': const Duration(seconds: 100),
          'text': "Imagine your mind is like a clear, calm lake... Thoughts are like ripples... Let them settle... revealing the clear depth... below.",
        },
        {
          'offset': const Duration(seconds: 125),
          'text': "Engage your curiosity... Notice the beginning... the middle... and the end of each breath... Stay with it... from moment to moment.",
        },
        {
          'offset': const Duration(seconds: 150),
          'text': "Feel the posture of your body... upright... dignified... and focused... This stability in body... supports stability in mind.",
        },
        {
          'offset': const Duration(seconds: 175),
          'text': "Breathe in focus... breathe out distraction... Allow all external sounds... and thoughts... to fade into the background.",
        },
        {
          'offset': const Duration(seconds: 200),
          'text': "With each breath... sharpen your awareness... You are training your mind... like a muscle... building strength... and presence.",
        },
        {
          'offset': const Duration(seconds: 225),
          'text': "If you feel restless... take a deep breath... and anchor yourself... right back to the tip of your nose... Clear... alert... and still.",
        },
        {
          'offset': const Duration(seconds: 250),
          'text': "Enjoy the clarity... of a single-pointed focus... The mind is quiet... open... and highly capable... Rest in this sharp awareness.",
        },
        {
          'offset': const Duration(seconds: 275),
          'text': "Bring a sense of appreciation... to this newfound mental clarity... You are ready... to focus on your day... with ease.",
        },
        {
          'offset': const Duration(seconds: 295),
          'text': "Gently take a final deep breath... open your eyes... carrying this sharp... alert focus... with you.",
        },
      ],
      playMusic: false,
    );
  }

  Future<void> _runGratitudeMeditation() async {
    await _startSession(
      title: 'Gratitude Meditation',
      duration: const Duration(minutes: 5),
      cues: [
        {
          'offset': Duration.zero,
          'text': "Welcome to Gratitude meditation... Sit comfortably... close your eyes... and take a deep... relaxing breath... Let your heart center open.",
        },
        {
          'offset': const Duration(seconds: 25),
          'text': "Bring to mind one simple thing... you are grateful for today... It could be the warm sun... a hot cup of tea... or simply being alive... Feel that appreciation.",
        },
        {
          'offset': const Duration(seconds: 50),
          'text': "Now... think of a person in your life... who makes you feel safe... supported... or loved... Picture their smile... and send them silent thanks.",
        },
        {
          'offset': const Duration(seconds: 75),
          'text': "Feel the warm sensation of gratitude... filling your heart... and spreading through your chest... like soft sunlight.",
        },
        {
          'offset': const Duration(seconds: 100),
          'text': "Think about a challenge... or lesson... you have experienced... and find one small thing... you learned from it... Appreciate your own growth.",
        },
        {
          'offset': const Duration(seconds: 125),
          'text': "Direct gratitude to your physical body... It breathes for you... walks for you... and keeps you healthy... Thank your body... for its strength.",
        },
        {
          'offset': const Duration(seconds: 150),
          'text': "Notice the simple abundance... in your life... the roof over your head... the food you eat... the people you know... Let the feeling of fullness grow.",
        },
        {
          'offset': const Duration(seconds: 175),
          'text': "Repeat silently to yourself... I am grateful for this day... I am grateful for my life... I welcome joy... and peace... into my heart.",
        },
        {
          'offset': const Duration(seconds: 200),
          'text': "Breathe in the feeling of appreciation... breathe out kindness... Let any resentment... or dissatisfaction... dissolve on the exhale.",
        },
        {
          'offset': const Duration(seconds: 225),
          'text': "Let this warmth... radiate to everyone around you... Send gratitude to your friends... family... and even strangers... wishing them well.",
        },
        {
          'offset': const Duration(seconds: 250),
          'text': "Rest in this beautiful state of appreciation... You lack nothing in this moment... You are rich... in blessings... and peace.",
        },
        {
          'offset': const Duration(seconds: 275),
          'text': "Take a deep... slow inhale... letting the gratitude settle... deep into your heart... ready to guide your day.",
        },
        {
          'offset': const Duration(seconds: 295),
          'text': "Gently take a final breath... open your eyes... and share your warmth... and gratitude... with the world.",
        },
      ],
      playMusic: false,
    );
  }

  Future<void> _runBreathingExercise() async {
    await _startSession(
      title: 'Breathing Exercise',
      duration: const Duration(minutes: 3),
      cues: [
        {
          'offset': Duration.zero,
          'text': "Welcome to the Breathing Exercise... Let's practice four four six breathing... We will inhale for four seconds... hold for four... and exhale for six... Get ready... Inhale... two... three... four... Hold... two... three... four... Exhale... two... three... four... five... six.",
        },
        {
          'offset': const Duration(seconds: 25),
          'text': "Cycle two... Inhale... two... three... four... Hold... two... three... four... Exhale... two... three... four... five... six.",
        },
        {
          'offset': const Duration(seconds: 50),
          'text': "Feel your body settle... Cycle three... Inhale... two... three... four... Hold... two... three... four... Exhale... two... three... four... five... six.",
        },
        {
          'offset': const Duration(seconds: 75),
          'text': "Keep it steady... Cycle four... Inhale... two... three... four... Hold... two... three... four... Exhale... two... three... four... five... six.",
        },
        {
          'offset': const Duration(seconds: 100),
          'text': "Let go of thoughts... Cycle five... Inhale... two... three... four... Hold... two... three... four... Exhale... two... three... four... five... six.",
        },
        {
          'offset': const Duration(seconds: 125),
          'text': "Breathe naturally now... Feel the calm flowing through your body... Relax.",
        },
        {
          'offset': const Duration(seconds: 150),
          'text': "Slow, deep breathing triggers your relaxation response... instantly calming your nervous system... Rest in this quiet space.",
        },
        {
          'offset': const Duration(seconds: 170),
          'text': "Take a final deep breath in... and let it go completely.",
        },
      ],
      playMusic: false,
    );
  }

  Future<void> _runSleepRelaxation() async {
    await _startSession(
      title: 'Sleep Relaxation',
      duration: const Duration(minutes: 5),
      cues: [
        {
          'offset': Duration.zero,
          'text': "Welcome to sleep relaxation... Lie down comfortably... let your eyes close... feel the heavy support of your bed... Let go of the day.",
        },
        {
          'offset': const Duration(seconds: 30),
          'text': "Let your feet feel heavy... let your legs go completely loose... releasing all tension and weight.",
        },
        {
          'offset': const Duration(seconds: 60),
          'text': "Feel your chest rise and fall... with a slow... gentle... sleepy rhythm... You have done enough today... it is time to rest.",
        },
        {
          'offset': const Duration(seconds: 90),
          'text': "Your shoulders sink down... your arms feel heavy and relaxed by your side... breathe in calm... breathe out sleep.",
        },
        {
          'offset': const Duration(seconds: 120),
          'text': "Relax the muscles in your face... your jaw... your forehead... letting your mind drift into deep quiet.",
        },
        {
          'offset': const Duration(seconds: 150),
          'text': "With every breath out... you are sinking deeper and deeper... into comfort... and safety.",
        },
        {
          'offset': const Duration(seconds: 180),
          'text': "There is nothing else you need to do... nowhere else you need to be... just drifting... flowing into sleep.",
        },
        {
          'offset': const Duration(seconds: 210),
          'text': "Quiet mind... relaxed body... peaceful sleep... Good night.",
        },
      ],
      playMusic: true,
    );
  }

  Future<void> _stopSession() async {
    _clearGuidanceTimers();
    await _tts.stop();
    await _restoreNormalTtsSettings();
    await _audioPlayer.stop();
    _progressController.stop();
    _progressController.reset();
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _sessionLabel = 'Session stopped.';
        _currentState = 'idle';
      });
    }
  }

  Future<void> _onSessionComplete() async {
    _clearGuidanceTimers();
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _sessionLabel = 'Session complete. How do you feel now?';
        _chatHistory.add(_Message('Session complete. Well done.', isUser: false));
      });
    }
    await _tts.speak('Session complete. Well done... How do you feel now?');
    setState(() {
      _currentState = 'awaiting_reflection_response';
      _shouldAutoListen = true;
    });
    await Future.delayed(const Duration(seconds: 4));
    await _restoreNormalTtsSettings();
    await _audioPlayer.stop();
  }

  @override
  void dispose() {
    _clearGuidanceTimers();
    _tts.stop();
    _stt.stop();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const accent = Color(0xFF9C6FDE);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Mindfulness'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: cs.onSurface,
      ),
      body: Stack(
        children: [
          // ── Scrollable foreground content ──────────────────────────
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 220),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Guided session player ────────────────────────────────
                    Center(
                      child: Column(
                        children: [
                          AnimatedBuilder(
                            animation: _progressController,
                            builder: (context, child) {
                              return GestureDetector(
                                onTap: () {
                                  if (_isPlaying) {
                                    _stopSession();
                                  }
                                },
                                child: Tooltip(
                                  message: _isPlaying ? 'Tap to stop session' : '',
                                  child: _MindfulProgressIndicator(
                                    progress: _progressController.value,
                                    isPlaying: _isPlaying,
                                    accentColor: accent,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _sessionLabel,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          if (_isPlaying) ...[
                            const SizedBox(height: 10),
                            AnimatedBuilder(
                              animation: _progressController,
                              builder: (context, child) {
                                final total = _progressController.duration ?? const Duration(minutes: 5);
                                final elapsed = total * _progressController.value;
                                final remaining = total - elapsed;
                                
                                final minutes = remaining.inMinutes;
                                final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
                                
                                return TweenAnimationBuilder<double>(
                                  duration: const Duration(milliseconds: 300),
                                  tween: Tween(begin: 1.0, end: 1.05),
                                  builder: (context, scale, child) {
                                    return Transform.scale(
                                      scale: scale,
                                      child: Text(
                                        '$minutes:$seconds',
                                        style: TextStyle(
                                          fontSize: 34,
                                          fontWeight: FontWeight.w900,
                                          color: accent,
                                          letterSpacing: 1.5,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                          shadows: [
                                            Shadow(
                                              color: accent.withOpacity(0.25),
                                              blurRadius: 8.0,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'TAP PULSING CIRCLE TO STOP',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurfaceVariant.withOpacity(0.4),
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Conversational Chat Bubbles ───────────────────────────
                    Container(
                      height: 180,
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLowest.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: cs.outlineVariant.withOpacity(0.3),
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
                                'VUI Conversation Log',
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
                              reverse: true, // Show newest messages at the bottom
                              itemCount: _chatHistory.length,
                              itemBuilder: (context, index) {
                                final msg = _chatHistory[_chatHistory.length - 1 - index];
                                return Align(
                                  alignment: msg.isUser
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
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
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

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

                    // ── Session cards ────────────────────────────────────────
                    ...List.generate(_sessions.length, (i) {
                      final s = _sessions[i];
                      final isCurrentPlaying = _isPlaying && _sessionLabel.contains(s['title'] as String);
                      return GestureDetector(
                        onTap: _isPlaying ? null : () {
                          if (s['title'] == 'Body Scan') {
                            _runBodyScan();
                          } else if (s['title'] == 'Mindful Observation') {
                            _runMindfulObservation();
                          } else if (s['title'] == 'Loving Kindness') {
                            _runLovingKindness();
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: (s['color'] as Color).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCurrentPlaying
                                  ? (s['color'] as Color)
                                  : (s['color'] as Color).withOpacity(0.2),
                              width: isCurrentPlaying ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: (s['color'] as Color).withOpacity(0.15),
                                child: Icon(
                                  s['icon'] as IconData,
                                  color: s['color'] as Color,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s['title'] as String,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                    const SizedBox(height: 3),
                                    Text(s['subtitle'] as String,
                                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                              if (isCurrentPlaying)
                                Icon(Icons.volume_up_rounded, color: s['color'] as Color)
                              else if (!_isPlaying)
                                Icon(Icons.play_arrow_rounded, color: (s['color'] as Color).withOpacity(0.5)),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 28),

                    Text(
                      'Guided Meditation Sessions 🎧',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface),
                    ),
                    const SizedBox(height: 12),

                    // ── Guided Meditation Sessions ───────────────────────────
                    ...List.generate(_meditationSessions.length, (i) {
                      final s = _meditationSessions[i];
                      final isCurrentPlaying = _isPlaying && _sessionLabel.contains(s['title'] as String);
                      return GestureDetector(
                        onTap: _isPlaying ? null : () {
                          if (s['title'] == 'Beginner Meditation') {
                            _runBeginnerMeditation();
                          } else if (s['title'] == 'Anxiety Reduction') {
                            _runAnxietyReduction();
                          } else if (s['title'] == 'Focus & Concentration') {
                            _runFocusConcentration();
                          } else if (s['title'] == 'Gratitude Meditation') {
                            _runGratitudeMeditation();
                          } else if (s['title'] == 'Breathing Exercise') {
                            _runBreathingExercise();
                          } else if (s['title'] == 'Sleep Relaxation') {
                            _runSleepRelaxation();
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: (s['color'] as Color).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCurrentPlaying
                                  ? (s['color'] as Color)
                                  : (s['color'] as Color).withOpacity(0.2),
                              width: isCurrentPlaying ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: (s['color'] as Color).withOpacity(0.15),
                                child: Icon(
                                  s['icon'] as IconData,
                                  color: s['color'] as Color,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s['title'] as String,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                    const SizedBox(height: 3),
                                    Text(s['subtitle'] as String,
                                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                              if (isCurrentPlaying)
                                Icon(Icons.volume_up_rounded, color: s['color'] as Color)
                              else if (!_isPlaying)
                                Icon(Icons.play_arrow_rounded, color: (s['color'] as Color).withOpacity(0.5)),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),

          // ── Fixed floating mic button overlay at bottom ─────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: VoiceMicButton(
                  isListening: _isListening,
                  onTap: _onMicTap,
                  statusLabel: _statusLabel,
                  recognizedText: _recognizedText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Concentric Rotating Dash Ring and Progress Painters ──────────────────────

class _CircularSessionProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CircularSessionProgressPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 6.0;
    final center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width - strokeWidth) / 2 - 2;

    // 1. Draw background track line
    final trackPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..strokeWidth = strokeWidth - 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, trackPaint);

    // 2. Draw active progress line with gradient
    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      
      // Gradient from accent color to a slightly brighter/lighter version of it
      final hsl = HSLColor.fromColor(color);
      final lighterColor = hsl.withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0)).toColor();
      
      final gradient = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 2 * math.pi - math.pi / 2,
        colors: [color, lighterColor, color],
        stops: const [0.0, 0.5, 1.0],
      );

      final progressPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final double sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(
        rect,
        -math.pi / 2, // Start at 12 o'clock
        sweepAngle,
        false,
        progressPaint,
      );

      // 3. Draw a glowing indicator dot at the end of the progress arc
      final double endAngle = -math.pi / 2 + sweepAngle;
      final double dotX = center.dx + radius * math.cos(endAngle);
      final double dotY = center.dy + radius * math.sin(endAngle);
      final Offset dotOffset = Offset(dotX, dotY);

      // Glow effect under the dot
      final glowPaint = Paint()
        ..color = lighterColor.withOpacity(0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
      canvas.drawCircle(dotOffset, 7.0, glowPaint);

      // Core white dot
      final dotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(dotOffset, 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircularSessionProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _MindfulProgressIndicator extends StatefulWidget {
  final double progress;
  final bool isPlaying;
  final Color accentColor;

  const _MindfulProgressIndicator({
    required this.progress,
    required this.isPlaying,
    required this.accentColor,
  });

  @override
  State<_MindfulProgressIndicator> createState() => _MindfulProgressIndicatorState();
}

class _MindfulProgressIndicatorState extends State<_MindfulProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isPlaying) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _MindfulProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.animateTo(0.0, duration: const Duration(milliseconds: 500));
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // 1. Dynamic Breathing Ripple Ring (Background glow)
            if (widget.isPlaying) ...[
              // Outer breathing ripple 1
              Container(
                width: 140 + (50 * _pulseAnimation.value),
                height: 140 + (50 * _pulseAnimation.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.accentColor.withOpacity(0.08 * (1.0 - _pulseAnimation.value)),
                ),
              ),
              // Inner breathing ripple 2
              Container(
                width: 140 + (25 * _pulseAnimation.value),
                height: 140 + (25 * _pulseAnimation.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.accentColor.withOpacity(0.12 * (1.0 - _pulseAnimation.value)),
                ),
              ),
            ],

            // 2. The core meditation icon circle (pulsing in size slightly)
            Transform.scale(
              scale: widget.isPlaying ? _scaleAnimation.value : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.accentColor.withOpacity(widget.isPlaying ? 0.25 : 0.12),
                  border: Border.all(
                    color: widget.accentColor.withOpacity(widget.isPlaying ? 0.7 : 0.3),
                    width: 2,
                  ),
                  boxShadow: widget.isPlaying
                      ? [
                          BoxShadow(
                            color: widget.accentColor.withOpacity(0.25 * _pulseAnimation.value),
                            blurRadius: 15.0,
                            spreadRadius: 2.0,
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  Icons.self_improvement_rounded,
                  size: 64,
                  color: widget.accentColor.withOpacity(widget.isPlaying ? 1.0 : 0.6),
                ),
              ),
            ),

            // 3. Progress arc surrounding the circle
            if (widget.isPlaying || widget.progress > 0)
              SizedBox(
                width: 156,
                height: 156,
                child: CustomPaint(
                  painter: _CircularSessionProgressPainter(
                    progress: widget.progress,
                    color: widget.accentColor,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Message {
  final String text;
  final bool isUser;
  _Message(this.text, {required this.isUser});
}