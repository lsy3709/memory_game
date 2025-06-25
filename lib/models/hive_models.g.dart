// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiveGameRecordAdapter extends TypeAdapter<HiveGameRecord> {
  @override
  final int typeId = 0;

  @override
  HiveGameRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveGameRecord(
      id: fields[0] as String,
      playerName: fields[1] as String,
      email: fields[2] as String,
      score: fields[3] as int,
      matchCount: fields[4] as int,
      failCount: fields[5] as int,
      maxCombo: fields[6] as int,
      timeLeft: fields[7] as int,
      totalTime: fields[8] as int,
      createdAt: fields[9] as DateTime,
      isCompleted: fields[10] as bool,
      gameType: fields[11] as GameType,
      isSynced: fields[12] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, HiveGameRecord obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.playerName)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.score)
      ..writeByte(4)
      ..write(obj.matchCount)
      ..writeByte(5)
      ..write(obj.failCount)
      ..writeByte(6)
      ..write(obj.maxCombo)
      ..writeByte(7)
      ..write(obj.timeLeft)
      ..writeByte(8)
      ..write(obj.totalTime)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.isCompleted)
      ..writeByte(11)
      ..write(obj.gameType)
      ..writeByte(12)
      ..write(obj.isSynced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveGameRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveMultiplayerGameRecordAdapter
    extends TypeAdapter<HiveMultiplayerGameRecord> {
  @override
  final int typeId = 1;

  @override
  HiveMultiplayerGameRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveMultiplayerGameRecord(
      id: fields[0] as String,
      gameTitle: fields[1] as String,
      players: (fields[2] as List).cast<HivePlayerGameResult>(),
      createdAt: fields[3] as DateTime,
      isCompleted: fields[4] as bool,
      totalTime: fields[5] as int,
      timeLeft: fields[6] as int,
      gameType: fields[7] as GameType,
      isSynced: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, HiveMultiplayerGameRecord obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.gameTitle)
      ..writeByte(2)
      ..write(obj.players)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.isCompleted)
      ..writeByte(5)
      ..write(obj.totalTime)
      ..writeByte(6)
      ..write(obj.timeLeft)
      ..writeByte(7)
      ..write(obj.gameType)
      ..writeByte(8)
      ..write(obj.isSynced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveMultiplayerGameRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HivePlayerGameResultAdapter extends TypeAdapter<HivePlayerGameResult> {
  @override
  final int typeId = 2;

  @override
  HivePlayerGameResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HivePlayerGameResult(
      playerName: fields[0] as String,
      email: fields[1] as String,
      score: fields[2] as int,
      matchCount: fields[3] as int,
      failCount: fields[4] as int,
      maxCombo: fields[5] as int,
      timeLeft: fields[6] as int,
      isWinner: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, HivePlayerGameResult obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.playerName)
      ..writeByte(1)
      ..write(obj.email)
      ..writeByte(2)
      ..write(obj.score)
      ..writeByte(3)
      ..write(obj.matchCount)
      ..writeByte(4)
      ..write(obj.failCount)
      ..writeByte(5)
      ..write(obj.maxCombo)
      ..writeByte(6)
      ..write(obj.timeLeft)
      ..writeByte(7)
      ..write(obj.isWinner);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HivePlayerGameResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveOnlineRoomAdapter extends TypeAdapter<HiveOnlineRoom> {
  @override
  final int typeId = 3;

  @override
  HiveOnlineRoom read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveOnlineRoom(
      id: fields[0] as String,
      roomName: fields[1] as String,
      hostId: fields[2] as String,
      hostName: fields[3] as String,
      hostEmail: fields[4] as String,
      hostLevel: fields[5] as int,
      guestId: fields[6] as String?,
      guestName: fields[7] as String?,
      guestEmail: fields[8] as String?,
      guestLevel: fields[9] as int?,
      status: fields[10] as RoomStatus,
      createdAt: fields[11] as DateTime,
      gameStartedAt: fields[12] as DateTime?,
      maxPlayers: fields[13] as int,
      isPrivate: fields[14] as bool,
      password: fields[15] as String?,
      isSynced: fields[16] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, HiveOnlineRoom obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.roomName)
      ..writeByte(2)
      ..write(obj.hostId)
      ..writeByte(3)
      ..write(obj.hostName)
      ..writeByte(4)
      ..write(obj.hostEmail)
      ..writeByte(5)
      ..write(obj.hostLevel)
      ..writeByte(6)
      ..write(obj.guestId)
      ..writeByte(7)
      ..write(obj.guestName)
      ..writeByte(8)
      ..write(obj.guestEmail)
      ..writeByte(9)
      ..write(obj.guestLevel)
      ..writeByte(10)
      ..write(obj.status)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.gameStartedAt)
      ..writeByte(13)
      ..write(obj.maxPlayers)
      ..writeByte(14)
      ..write(obj.isPrivate)
      ..writeByte(15)
      ..write(obj.password)
      ..writeByte(16)
      ..write(obj.isSynced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveOnlineRoomAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GameTypeAdapter extends TypeAdapter<GameType> {
  @override
  final int typeId = 4;

  @override
  GameType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return GameType.local;
      case 1:
        return GameType.online;
      default:
        return GameType.local;
    }
  }

  @override
  void write(BinaryWriter writer, GameType obj) {
    switch (obj) {
      case GameType.local:
        writer.writeByte(0);
        break;
      case GameType.online:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RoomStatusAdapter extends TypeAdapter<RoomStatus> {
  @override
  final int typeId = 5;

  @override
  RoomStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RoomStatus.waiting;
      case 1:
        return RoomStatus.ready;
      case 2:
        return RoomStatus.playing;
      case 3:
        return RoomStatus.finished;
      case 4:
        return RoomStatus.cancelled;
      default:
        return RoomStatus.waiting;
    }
  }

  @override
  void write(BinaryWriter writer, RoomStatus obj) {
    switch (obj) {
      case RoomStatus.waiting:
        writer.writeByte(0);
        break;
      case RoomStatus.ready:
        writer.writeByte(1);
        break;
      case RoomStatus.playing:
        writer.writeByte(2);
        break;
      case RoomStatus.finished:
        writer.writeByte(3);
        break;
      case RoomStatus.cancelled:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
