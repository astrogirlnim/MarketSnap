// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vendor_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VendorProfileAdapter extends TypeAdapter<VendorProfile> {
  @override
  final int typeId = 1;

  @override
  VendorProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VendorProfile(
      uid: fields[0] as String,
      displayName: fields[1] as String,
      stallName: fields[2] as String,
      marketCity: fields[3] as String,
      avatarURL: fields[4] as String?,
      allowLocation: fields[5] as bool,
      localAvatarPath: fields[6] as String?,
      needsSync: fields[7] as bool,
      lastUpdated: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, VendorProfile obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.displayName)
      ..writeByte(2)
      ..write(obj.stallName)
      ..writeByte(3)
      ..write(obj.marketCity)
      ..writeByte(4)
      ..write(obj.avatarURL)
      ..writeByte(5)
      ..write(obj.allowLocation)
      ..writeByte(6)
      ..write(obj.localAvatarPath)
      ..writeByte(7)
      ..write(obj.needsSync)
      ..writeByte(8)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VendorProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
