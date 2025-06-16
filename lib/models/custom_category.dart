// filepath: lib/models/custom_category.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'custom_category.g.dart'; // Hive generator will create this

@HiveType(
  typeId: 28,
) // Ensure typeId is unique (0 for RecordingEntry, 1 for ColorAdapter)
class CustomCategory extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late String emoji;

  @HiveField(3)
  late int colorValue; // Store color as int

  @HiveField(4)
  late int iconColorValue; // Store icon color as int

  CustomCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorValue,
    required this.iconColorValue,
  });

  Color get color => Color(colorValue);
  Color get iconColor => Color(iconColorValue);

  // Helper to convert to the Map format used by widgets (can be kept if used elsewhere)
  Map<String, dynamic> toMap() {
    return {
      'id': id, // Keep track if it's custom
      'name': name,
      'emoji': emoji,
      'color': Color(colorValue),
      'iconColor': Color(iconColorValue),
      'isCustom': true,
    };
  }

  // Method to convert CustomCategory instance to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'colorValue': colorValue,
      'iconColorValue': iconColorValue,
    };
  }

  // Factory constructor to create a CustomCategory instance from a JSON map
  factory CustomCategory.fromJson(Map<String, dynamic> json) {
    return CustomCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      colorValue: json['colorValue'] as int,
      iconColorValue: json['iconColorValue'] as int,
    );
  }
}
