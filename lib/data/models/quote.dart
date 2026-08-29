import 'package:hive/hive.dart';

/// A motivational quote. [isCustom] distinguishes user-added quotes from
/// the bundled static list, so the default list can be safely reset
/// without touching user-authored entries.
class Quote extends HiveObject {
  String id;
  String text;
  String author;
  bool isCustom;

  Quote({
    required this.id,
    required this.text,
    required this.author,
    this.isCustom = false,
  });
}

class QuoteAdapter extends TypeAdapter<Quote> {
  @override
  final int typeId = 3;

  @override
  Quote read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return Quote(
      id: fields[0] as String,
      text: fields[1] as String,
      author: fields[2] as String,
      isCustom: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Quote obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.author)
      ..writeByte(3)
      ..write(obj.isCustom);
  }
}
