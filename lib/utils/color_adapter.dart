import 'package:flutter/material.dart'; // For Color
import 'package:hive/hive.dart';

class ColorAdapter extends TypeAdapter<Color> {
  @override
  final int typeId = 100; // Choose a unique typeId not used by other adapters

  @override
  Color read(BinaryReader reader) {
    // Read the integer value stored for the color
    final value = reader.readInt();
    return Color(value);
  }

  @override
  void write(BinaryWriter writer, Color obj) {
    // Write the integer value of the color
    writer.writeInt(obj.value);
  }
}
