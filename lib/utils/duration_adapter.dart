import 'package:hive/hive.dart';

class DurationAdapter extends TypeAdapter<Duration> {
  @override
  final int typeId = 100; // IMPORTANT: Choose a unique typeId not used by other adapters in your project.

  @override
  Duration read(BinaryReader reader) {
    // This assumes you stored (or intend to store) duration as total milliseconds (an int).
    final int milliseconds = reader.readInt();
    return Duration(milliseconds: milliseconds);
  }

  @override
  void write(BinaryWriter writer, Duration obj) {
    // This will store the duration as total milliseconds (an int).
    writer.writeInt(obj.inMilliseconds);
  }
}
