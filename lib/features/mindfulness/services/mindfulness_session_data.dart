// mindfulness_session_data.dart
// Contains all session cue scripts and session list definitions.

import 'package:flutter/material.dart';

// ── Session List Definitions ──────────────────────────────────────────────────

final List<Map<String, dynamic>> kMindfulnessSessions = [
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

final List<Map<String, dynamic>> kGuidedMeditationSessions = [
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
];

// ── Session Cue Scripts ───────────────────────────────────────────────────────

const kBodyScanCues = <Map<String, dynamic>>[
  {'offset': Duration.zero, 'text': "Welcome... Let's begin the Body Scan meditation... Find a comfortable posture... close your eyes... and allow your arms to rest naturally... Take a deep... slow breath in... and let it out."},
  {'offset': Duration(seconds: 25), 'text': "Bring your awareness... to the simple sensation of breathing... Feel the air entering your nostrils... filling your lungs... and gently leaving your body... Settle into this present moment."},
  {'offset': Duration(seconds: 50), 'text': "Now... gently shift your attention... to the top of your head... Focus on your scalp... Notice any sensations here... tingling... heat... or tightness... Just observe."},
  {'offset': Duration(seconds: 75), 'text': "Move your focus down... to your forehead and eyes... Let your eyelids feel heavy... Relax your cheeks... your lips... and especially your jaw... letting it hang slightly loose."},
  {'offset': Duration(seconds: 100), 'text': "Let the wave of relaxation... travel down your neck and throat... Now feel your shoulders... If they are raised... let them drop down completely... Breathe warmth... into your shoulders."},
  {'offset': Duration(seconds: 125), 'text': "Guide your awareness down... through your upper arms... past your elbows... into your forearms... wrists... and hands... Feel the space your hands occupy... Let your fingers soften."},
  {'offset': Duration(seconds: 150), 'text': "Now... direct your attention to your chest... Feel the physical expansion as you inhale... and the release as you exhale... Notice the steady rhythm... of your heartbeat."},
  {'offset': Duration(seconds: 175), 'text': "Let your awareness sink down... into your abdomen... Feel the gentle rise and fall of your stomach... Allow your breathing... to be natural... effortless... and deep."},
  {'offset': Duration(seconds: 200), 'text': "Shift your focus... to your back... Scan your upper back... then slowly move down your spine... to your lower back... Breathe into any areas of tension... and let them soften."},
  {'offset': Duration(seconds: 225), 'text': "Bring your attention... to your hips and pelvis... Feel the weight of your body pressing down onto the seat... Allow yourself to feel fully supported... and grounded."},
  {'offset': Duration(seconds: 250), 'text': "Move down into your legs... Feel your thighs... knees... and calves... Let go of any holding or tightness in the muscles... Just let your legs rest... deeply."},
  {'offset': Duration(seconds: 275), 'text': "Finally... focus on your feet... ankles... and toes... Notice the sensation of touch... where your feet meet the floor... Feel the stability... and support."},
  {'offset': Duration(seconds: 295), 'text': "Take a deep breath... and feel your entire body... as one unified, relaxed space... You are fully present... and at peace... Gently open your eyes... when you are ready."},
];

const kMindfulObservationCues = <Map<String, dynamic>>[
  {'offset': Duration.zero, 'text': "Welcome to Mindful Observation... Open your eyes... and choose a single, simple object in front of you... Let your gaze rest on it... with soft, gentle curiosity."},
  {'offset': Duration(seconds: 20), 'text': "Begin by observing the overall shape of the object... Notice its contours... its silhouette... and its edges... Try to look at it as if you have never seen it before."},
  {'offset': Duration(seconds: 40), 'text': "Now... focus your attention on the colors... Notice the different shades... how they blend together... and how the light interacts... with the colors."},
  {'offset': Duration(seconds: 60), 'text': "Observe the texture of its surface... Is it smooth... rough... matte... or glossy?... Imagine how it would feel to the touch... Just observe the visual details."},
  {'offset': Duration(seconds: 80), 'text': "Notice the play of light and shadow on the object... Where does the light hit it directly?... Where do the shadows fall?... See how these details define its form."},
  {'offset': Duration(seconds: 100), 'text': "If your mind starts to wander... or you find yourself thinking about other things... that is completely normal... Gently guide your focus back... to looking at the object."},
  {'offset': Duration(seconds: 120), 'text': "Look even closer now... Notice any small imperfections... dust particles... lines... or details that you didn't see at first... Give the object your full presence."},
  {'offset': Duration(seconds: 140), 'text': "Observe the space surrounding the object... Notice how it interacts with its environment... the contrast between the object... and the background."},
  {'offset': Duration(seconds: 160), 'text': "Let go of any thoughts or descriptions... Just enjoy the simple act of seeing... Let your mind be still... and receptive."},
  {'offset': Duration(seconds: 175), 'text': "Take a deep breath... Slowly bring your focus back to the room... carrying this sense of calm... and clarity... with you."},
];

const kLovingKindnessCues = <Map<String, dynamic>>[
  {'offset': Duration.zero, 'text': "Welcome to Loving Kindness meditation... Close your eyes... settle into your body... and take a slow, deep breath... Let your heart and mind soften."},
  {'offset': Duration(seconds: 25), 'text': "Bring your awareness... to your heart center... Imagine a warm, glowing light radiating from your chest... filled with kindness and peace."},
  {'offset': Duration(seconds: 50), 'text': "Think of someone who has loved or helped you deeply... a mentor... a dear friend... or a family member... Visualize them sitting right in front of you."},
  {'offset': Duration(seconds: 75), 'text': "Send them your heartfelt wishes, repeating silently... May you be happy... May you be healthy... May you be safe... May you live with ease."},
  {'offset': Duration(seconds: 100), 'text': "Feel the warm energy of these wishes... connecting you to them... Let the feeling of love and appreciation... fill your chest."},
  {'offset': Duration(seconds: 125), 'text': "Now... bring the focus to yourself... You deserve your own love and compassion... Visualize yourself in your mind's eye."},
  {'offset': Duration(seconds: 150), 'text': "Direct these same wishes to yourself, repeating silently... May I be happy... May I be healthy... May I be safe... May I live with ease."},
  {'offset': Duration(seconds: 175), 'text': "Breathe in kindness... and feel it filling every cell of your body... Let go of any self-criticism or judgment... Accept yourself completely."},
  {'offset': Duration(seconds: 200), 'text': "Now... bring to mind a neutral person... someone you see in daily life... like a coworker or neighbor... but don't know well... Imagine their presence."},
  {'offset': Duration(seconds: 225), 'text': "Remember that they also experience joys and struggles... just like you... Send them wishes... May you be happy... May you be healthy... May you live with ease."},
  {'offset': Duration(seconds: 250), 'text': "Finally... expand this feeling of loving-kindness outward... Imagine it spreading to your home... your community... your country... and all living beings everywhere."},
  {'offset': Duration(seconds: 275), 'text': "Repeat silently... May all beings be happy... May all beings be healthy... May all beings be safe... May all beings live with ease."},
  {'offset': Duration(seconds: 295), 'text': "Rest in this open, unlimited space of compassion... Take a deep breath... and gently open your eyes... when you feel ready."},
];

const kBeginnerMeditationCues = <Map<String, dynamic>>[
  {'offset': Duration.zero, 'text': "Welcome to your beginner meditation... Let's start by finding a comfortable sitting position... Close your eyes softly... and allow your body to settle."},
  {'offset': Duration(seconds: 25), 'text': "Take a deep, full breath in... hold it for a moment... and exhale slowly... releasing all your thoughts... and entering the present moment."},
  {'offset': Duration(seconds: 50), 'text': "Now... let your breathing return to its natural rhythm... Don't try to change it... simply observe... the natural flow of your breath."},
  {'offset': Duration(seconds: 75), 'text': "Notice the sensation... of the breath entering your nose... Feel the coolness as you inhale... and the slight warmth as you exhale... Just focus here."},
  {'offset': Duration(seconds: 100), 'text': "Feel your chest... and stomach... rise and fall with each breath... Like the waves of the ocean... steady... calming... and soothing."},
  {'offset': Duration(seconds: 125), 'text': "If thoughts arise... that is completely natural... Simply label them as thinking... and gently return... your focus back to the breath."},
  {'offset': Duration(seconds: 150), 'text': "Each breath is a fresh start... a new moment to be present... Breathe in clarity... breathe out distraction... Enjoy this quiet space."},
  {'offset': Duration(seconds: 175), 'text': "Feel the weight of your body... resting on the seat... Feel grounded... secure... and fully supported by the earth below you."},
  {'offset': Duration(seconds: 200), 'text': "Let your shoulders soften even more... Relax your hands... relax your face... Let a soft smile rest on your lips."},
  {'offset': Duration(seconds: 225), 'text': "Keep following the breath... all the way in... and all the way out... Feeling the space between each breath... the stillness."},
  {'offset': Duration(seconds: 250), 'text': "Allow your mind to just be... No goals... no tasks... nothing to accomplish... Just breathing... and resting in this moment."},
  {'offset': Duration(seconds: 275), 'text': "As we come to the end... take a deep breath... and feel a sense of appreciation... for taking this time for yourself."},
  {'offset': Duration(seconds: 295), 'text': "Gently wiggle your fingers and toes... Slowly open your eyes... carrying this peace... with you into the rest of your day."},
];

const kAnxietyReductionCues = <Map<String, dynamic>>[
  {'offset': Duration.zero, 'text': "Welcome... This meditation is designed to release anxiety... and bring you back to safety... Sit comfortably... close your eyes... and take a deep breath."},
  {'offset': Duration(seconds: 25), 'text': "Inhale slowly through your nose... and exhale with a long, soft sigh... letting go... of any tightness in your chest... and shoulders."},
  {'offset': Duration(seconds: 50), 'text': "Remember... you are safe in this moment... There is nothing you need to fix... nothing you need to figure out right now... Just be here."},
  {'offset': Duration(seconds: 75), 'text': "If your chest feels tight... place a hand gently over your heart... Feel the warm touch of your hand... and the soft beat... of your heart."},
  {'offset': Duration(seconds: 100), 'text': "As you breathe in... imagine breathing in cool... soothing blue light... As you breathe out... release any worry or tension... letting it fade away."},
  {'offset': Duration(seconds: 125), 'text': "With each exhale... feel your muscles releasing their grip... Let your shoulders drop... relax your stomach... let your jaw go loose."},
  {'offset': Duration(seconds: 150), 'text': "Anxiety is just energy passing through... You do not need to fight it... or judge it... Allow it to flow... like clouds passing in the sky."},
  {'offset': Duration(seconds: 175), 'text': "Focus on the sensation of your feet on the ground... Feel the strong... steady earth beneath you... supporting you completely... You are grounded."},
  {'offset': Duration(seconds: 200), 'text': "Repeat silently to yourself... I am safe... I am here... I can handle this... Let these words sink deep... into your mind."},
  {'offset': Duration(seconds: 225), 'text': "Take a long... slow inhale... counting to four... then hold for four... and exhale for six... This slows down your nervous system... bringing calm."},
  {'offset': Duration(seconds: 250), 'text': "Feel the quiet space... inside yourself... Beneath the noise of thoughts... there is a deep... undisturbed well of peace... Rest here."},
  {'offset': Duration(seconds: 275), 'text': "Breathe in peace... breathe out ease... You are doing wonderfully... You have everything you need... to be calm."},
  {'offset': Duration(seconds: 295), 'text': "Slowly bring your movement back... Take a gentle breath... and open your eyes... knowing you can return to this safety... anytime."},
];

const kFocusConcentrationCues = <Map<String, dynamic>>[
  {'offset': Duration.zero, 'text': "Welcome... Let's begin the focus and concentration meditation... Sit upright... align your spine... close your eyes... and take a sharp, clear breath."},
  {'offset': Duration(seconds: 25), 'text': "Bring your attention to a single point... such as the tip of your nose... Notice the sensation of air... moving in... and out... at that exact spot."},
  {'offset': Duration(seconds: 50), 'text': "As you breathe in... feel your mind becoming alert... and clear... As you breathe out... release any scattered thoughts... or mental fog."},
  {'offset': Duration(seconds: 75), 'text': "Keep your focus laser-sharp... on the inhalation... and the exhalation... If your mind drifts even slightly... gently but firmly... bring it back."},
  {'offset': Duration(seconds: 100), 'text': "Imagine your mind is like a clear, calm lake... Thoughts are like ripples... Let them settle... revealing the clear depth... below."},
  {'offset': Duration(seconds: 125), 'text': "Engage your curiosity... Notice the beginning... the middle... and the end of each breath... Stay with it... from moment to moment."},
  {'offset': Duration(seconds: 150), 'text': "Feel the posture of your body... upright... dignified... and focused... This stability in body... supports stability in mind."},
  {'offset': Duration(seconds: 175), 'text': "Breathe in focus... breathe out distraction... Allow all external sounds... and thoughts... to fade into the background."},
  {'offset': Duration(seconds: 200), 'text': "With each breath... sharpen your awareness... You are training your mind... like a muscle... building strength... and presence."},
  {'offset': Duration(seconds: 225), 'text': "If you feel restless... take a deep breath... and anchor yourself... right back to the tip of your nose... Clear... alert... and still."},
  {'offset': Duration(seconds: 250), 'text': "Enjoy the clarity... of a single-pointed focus... The mind is quiet... open... and highly capable... Rest in this sharp awareness."},
  {'offset': Duration(seconds: 275), 'text': "Bring a sense of appreciation... to this newfound mental clarity... You are ready... to focus on your day... with ease."},
  {'offset': Duration(seconds: 295), 'text': "Gently take a final deep breath... open your eyes... carrying this sharp... alert focus... with you."},
];

const kGratitudeMeditationCues = <Map<String, dynamic>>[
  {'offset': Duration.zero, 'text': "Welcome to Gratitude meditation... Sit comfortably... close your eyes... and take a deep... relaxing breath... Let your heart center open."},
  {'offset': Duration(seconds: 25), 'text': "Bring to mind one simple thing... you are grateful for today... It could be the warm sun... a hot cup of tea... or simply being alive... Feel that appreciation."},
  {'offset': Duration(seconds: 50), 'text': "Now... think of a person in your life... who makes you feel safe... supported... or loved... Picture their smile... and send them silent thanks."},
  {'offset': Duration(seconds: 75), 'text': "Feel the warm sensation of gratitude... filling your heart... and spreading through your chest... like soft sunlight."},
  {'offset': Duration(seconds: 100), 'text': "Think about a challenge... or lesson... you have experienced... and find one small thing... you learned from it... Appreciate your own growth."},
  {'offset': Duration(seconds: 125), 'text': "Direct gratitude to your physical body... It breathes for you... walks for you... and keeps you healthy... Thank your body... for its strength."},
  {'offset': Duration(seconds: 150), 'text': "Notice the simple abundance... in your life... the roof over your head... the food you eat... the people you know... Let the feeling of fullness grow."},
  {'offset': Duration(seconds: 175), 'text': "Repeat silently to yourself... I am grateful for this day... I am grateful for my life... I welcome joy... and peace... into my heart."},
  {'offset': Duration(seconds: 200), 'text': "Breathe in the feeling of appreciation... breathe out kindness... Let any resentment... or dissatisfaction... dissolve on the exhale."},
  {'offset': Duration(seconds: 225), 'text': "Let this warmth... radiate to everyone around you... Send gratitude to your friends... family... and even strangers... wishing them well."},
  {'offset': Duration(seconds: 250), 'text': "Rest in this beautiful state of appreciation... You lack nothing in this moment... You are rich... in blessings... and peace."},
  {'offset': Duration(seconds: 275), 'text': "Take a deep... slow inhale... letting the gratitude settle... deep into your heart... ready to guide your day."},
  {'offset': Duration(seconds: 295), 'text': "Gently take a final breath... open your eyes... and share your warmth... and gratitude... with the world."},
];
