// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'regular_user_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RegularUserProfileAdapter extends TypeAdapter<RegularUserProfile> {
  @override
  final int typeId = 4;

  @override
  RegularUserProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RegularUserProfile(
      uid: fields[0] as String,
      displayName: fields[1] as String,
      avatarURL: fields[2] as String?,
      localAvatarPath: fields[3] as String?,
      needsSync: fields[4] as bool,
      phoneNumber: fields[6] as String?,
      email: fields[7] as String?,
    )..lastUpdatedMillis = fields[5] as int;
  }

  @override
  void write(BinaryWriter writer, RegularUserProfile obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.displayName)
      ..writeByte(2)
      ..write(obj.avatarURL)
      ..writeByte(3)
      ..write(obj.localAvatarPath)
      ..writeByte(4)
      ..write(obj.needsSync)
      ..writeByte(5)
      ..write(obj.lastUpdatedMillis)
      ..writeByte(6)
      ..write(obj.phoneNumber)
      ..writeByte(7)
      ..write(obj.email);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegularUserProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
