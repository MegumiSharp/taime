import 'package:flutter/material.dart';

/// Icons an activity can use. Names are stored in the database.
const Map<String, IconData> activityIcons = {
  'circle': Icons.circle_rounded,
  'book': Icons.menu_book_rounded,
  'barbell': Icons.fitness_center_rounded,
  'broom': Icons.cleaning_services_rounded,
  'code': Icons.code_rounded,
  'briefcase': Icons.work_rounded,
  'palette': Icons.palette_rounded,
  'music': Icons.music_note_rounded,
  'game': Icons.sports_esports_rounded,
  'cook': Icons.restaurant_rounded,
  'run': Icons.directions_run_rounded,
  'plant': Icons.local_florist_rounded,
  'heart': Icons.favorite_rounded,
  'house': Icons.home_rounded,
  'cart': Icons.shopping_cart_rounded,
  'camera': Icons.photo_camera_rounded,
  'pen': Icons.edit_rounded,
  'brain': Icons.psychology_rounded,
};

IconData iconFor(String name) =>
    activityIcons[name] ?? Icons.circle_rounded;
