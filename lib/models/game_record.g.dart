// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GameRecordAdapter extends TypeAdapter<GameRecord> {
  @override
  final int typeId = 0;

  @override
  GameRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GameRecord(
      playerName: fields[0] as String,
      score: fields[1] as int,
      playedAt: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, GameRecord obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.playerName)
      ..writeByte(1)
      ..write(obj.score)
      ..writeByte(2)
      ..write(obj.playedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PlayerGameResultAdapter extends TypeAdapter<PlayerGameResult> {
  @override
  final int typeId = 1;

  @override
  PlayerGameResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlayerGameResult(
      playerName: fields[0] as String,
      score: fields[1] as int,
    );
  }

  @override
  void write(BinaryWriter writer, PlayerGameResult obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.playerName)
      ..writeByte(1)
      ..write(obj.score);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerGameResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MultiplayerGameRecordAdapter extends TypeAdapter<MultiplayerGameRecord> {
  @override
  final int typeId = 2;

  @override
  MultiplayerGameRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MultiplayerGameRecord(
      players: (fields[0] as List).cast<PlayerGameResult>(),
      playedAt: fields[1] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, MultiplayerGameRecord obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.players)
      ..writeByte(1)
      ..write(obj.playedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MultiplayerGameRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
