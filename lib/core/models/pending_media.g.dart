// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_media.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PendingMediaItemAdapter extends TypeAdapter<PendingMediaItem> {
  @override
  final int typeId = 3;

  @override
  PendingMediaItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PendingMediaItem(
      filePath: fields[1] as String,
      mediaType: fields[2] as MediaType,
      vendorId: fields[6] as String,
      caption: fields[4] as String?,
      location: (fields[5] as Map?)?.cast<String, double>(),
      filterType: fields[7] as String?,
      id: fields[0] as String?,
      createdAt: fields[3] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, PendingMediaItem obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.filePath)
      ..writeByte(2)
      ..write(obj.mediaType)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.caption)
      ..writeByte(5)
      ..write(obj.location)
      ..writeByte(6)
      ..write(obj.vendorId)
      ..writeByte(7)
      ..write(obj.filterType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingMediaItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MediaTypeAdapter extends TypeAdapter<MediaType> {
  @override
  final int typeId = 2;

  @override
  MediaType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MediaType.photo;
      case 1:
        return MediaType.video;
      default:
        return MediaType.photo;
    }
  }

  @override
  void write(BinaryWriter writer, MediaType obj) {
    switch (obj) {
      case MediaType.photo:
        writer.writeByte(0);
        break;
      case MediaType.video:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
