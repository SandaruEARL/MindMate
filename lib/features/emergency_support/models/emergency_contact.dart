import 'package:flutter/material.dart';

class EmergencyContact {
  const EmergencyContact({
    required this.key,
    required this.title,
    required this.defaultNumber,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String key;
  final String title;
  final String defaultNumber;
  final String subtitle;
  final IconData icon;
  final Color color;
}

const List<EmergencyContact> emergencyContacts = [
  EmergencyContact(
    key: 'police',
    title: 'Police',
    defaultNumber: '119',
    subtitle: 'Law enforcement · Sri Lanka',
    icon: Icons.local_police_rounded,
    color: Color(0xFF1565C0),
  ),
  EmergencyContact(
    key: 'ambulance',
    title: 'Ambulance',
    defaultNumber: '1990',
    subtitle: 'Suwa Seriya · Sri Lanka',
    icon: Icons.local_hospital_outlined,
    color: Color(0xFFC62828),
  ),
  EmergencyContact(
    key: 'fire',
    title: 'Fire & Rescue',
    defaultNumber: '110',
    subtitle: 'Fire department · Sri Lanka',
    icon: Icons.local_fire_department_rounded,
    color: Color.fromARGB(255, 223, 136, 5),
  ),

  EmergencyContact(
    key: 'mental_health',
    title: 'Mental Health Hotline',
    defaultNumber: '1926',
    subtitle: 'Available 24/7 · Sri Lanka',
    icon: Icons.phone_in_talk_rounded,
    color: Color(0xFF6A1B9A),
  ),
  EmergencyContact(
    key: 'friend',
    title: 'Friend',
    defaultNumber: '',
    subtitle: 'Your trusted friend',
    icon: Icons.people_rounded,
    color: Color(0xFF00897B),
  ),
  // EmergencyContact(
  //   key: 'home',
  //   title: 'Home',
  //   defaultNumber: '',
  //   subtitle: 'Your home contact',
  //   icon: Icons.home_rounded,
  //   color: Color(0xFF2E7D32),
  // ),
];
