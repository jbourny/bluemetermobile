import 'dart:convert';
import 'dart:typed_data';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';

import '../../protocol/blue_protocol.dart';
import '../../state/data_storage.dart';
import 'message_processor.dart';

class SyncContainerDirtyDataProcessor implements IMessageProcessor {
  final DataStorage _storage;

  SyncContainerDirtyDataProcessor(this._storage);

  @override
  void process(Uint8List payload) {
    try {
      if (_storage.currentPlayerUuid == Int64.ZERO) return;

      final dirty = SyncContainerDirtyData.fromBuffer(payload);
      if (!dirty.hasVData() || !dirty.vData.hasBufferS() || dirty.vData.bufferS.isEmpty) return;

      final buf = Uint8List.fromList(dirty.vData.bufferS);
      final reader = _BinaryReader(buf);

      if (!_doesStreamHaveIdentifier(reader)) return;

      final fieldIndex = reader.readUInt32();
      reader.readInt32(); // Skip padding

      // The playerUid derived from currentPlayerUuid might be 0 if not set yet.
      // But SyncContainerDirtyData is always for "Me".
      // If we don't have the UUID yet, we can't update the player info map correctly.
      // However, we can try to update the "Unknown" player if we assume 0 is placeholder?
      // No, we need the real UUID.
      
      if (_storage.currentPlayerUuid == Int64.ZERO) {
         debugPrint("[BM] SyncContainerDirtyData received but CurrentPlayerUUID is 0. Ignoring.");
         return;
      }

      final playerUid = _storage.currentPlayerUuid; 
      debugPrint("[BM] SyncContainerDirtyData processing for PlayerUID: $playerUid");
      
      _storage.ensurePlayer(playerUid);

      debugPrint("[BM] SyncContainerDirtyData FieldIndex: $fieldIndex");

      // Special handling for 0xFFFFFFFD (4294967293)
      if (fieldIndex == 0xFFFFFFFD || fieldIndex == 4294967293) {
        debugPrint("[BM] SyncContainerDirtyData - Special marker 0xFFFFFFFD detected");
        // This might be a special marker, try to read the data after it
        _tryReadSpecialMarkerData(reader, playerUid);
        return;
      }

      switch (fieldIndex) {
        case 2:
          _processNameAndPowerLevel(reader, playerUid);
          break;
        case 16:
          _processHp(reader, playerUid);
          break;
        case 61:
          _processProfession(reader, playerUid);
          break;
        default:
          debugPrint("[BM] SyncContainerDirtyData Unhandled FieldIndex: $fieldIndex");
          break;
      }
    } catch (e) {
      debugPrint("Error processing SyncContainerDirtyData: $e");
    }
  }

  void _processNameAndPowerLevel(_BinaryReader reader, Int64 playerUid) {
    if (!_doesStreamHaveIdentifier(reader)) {
        debugPrint("[BM] SyncContainerDirtyData _processNameAndPowerLevel: No Identifier");
        return;
    }
    final fieldIndex = reader.readUInt32();
    reader.readInt32();
    
    debugPrint("[BM] SyncContainerDirtyData _processNameAndPowerLevel FieldIndex: $fieldIndex");

    switch (fieldIndex) {
      case 5:
        final playerName = _streamReadString(reader);
        debugPrint("[BM] SyncContainerDirtyData Name Update (Field 5): $playerName");
        if (playerName.isNotEmpty) {
          _storage.setPlayerName(playerUid, playerName);
        }
        break;

      case 35:
        final fightPoint = reader.readUInt32();
        reader.readInt32();
        debugPrint("[BM] SyncContainerDirtyData Power Update: $fightPoint");
        if (fightPoint != 0) {
          _storage.setPlayerCombatPower(playerUid, fightPoint);
        }
        break;
      default:
        debugPrint("[BM] SyncContainerDirtyData _processNameAndPowerLevel Unhandled SubField: $fieldIndex");
        break;
    }
  }

  void _processHp(_BinaryReader reader, Int64 playerUid) {
    if (!_doesStreamHaveIdentifier(reader)) return;
    final fieldIndex = reader.readUInt32();
    reader.readInt32();

    switch (fieldIndex) {
      case 1:
        final curHp = reader.readUInt32();
        _storage.setPlayerHp(playerUid, curHp);
        break;
      case 2:
        final maxHp = reader.readUInt32();
        _storage.setPlayerMaxHp(playerUid, maxHp);
        break;
    }
  }

  void _processProfession(_BinaryReader reader, Int64 playerUid) {
    if (!_doesStreamHaveIdentifier(reader)) return;
    final fieldIndex = reader.readUInt32();
    reader.readInt32();

    if (fieldIndex == 1) {
      final curProfessionId = reader.readUInt32();
      reader.readInt32();
      if (curProfessionId != 0) {
        _storage.setPlayerProfessionId(playerUid, curProfessionId);
      }
    }
  }

  void _tryReadSpecialMarkerData(_BinaryReader reader, Int64 playerUid) {
    debugPrint("[BM] SyncContainerDirtyData - Special marker data. Remaining bytes: ${reader.remaining}");
    
    // Try to read what comes after the marker
    if (reader.remaining < 8) return;
    
    // Skip the padding after the marker
    reader.readInt32();
    
    // Try to see if there's an identifier and then data
    if (_doesStreamHaveIdentifier(reader)) {
      final subFieldIndex = reader.readUInt32();
      reader.readInt32();
      debugPrint("[BM] SyncContainerDirtyData - After 0xFFFFFFFD, found SubField: $subFieldIndex");
      
      // Maybe this contains the name?
      if (subFieldIndex == 5 || subFieldIndex == 26) {
        try {
          final name = _streamReadString(reader);
          debugPrint("[BM] SyncContainerDirtyData - Name from 0xFFFFFFFD SubField $subFieldIndex: '$name'");
          if (name.isNotEmpty) {
            _storage.setPlayerName(playerUid, name);
          }
        } catch (e) {
          debugPrint("[BM] SyncContainerDirtyData - Failed to read name from 0xFFFFFFFD: $e");
        }
      }
    }
  }

  bool _doesStreamHaveIdentifier(_BinaryReader reader) {
    if (reader.remaining < 16) return false;
    
    final id1 = reader.readUInt32();
    reader.readInt32(); // Skip
    
    if (id1 != 0xFFFFFFFE) return false;
    
    if (reader.remaining < 8) return false;
    reader.readInt32(); // Skip
    reader.readInt32(); // Skip
    
    return true;
  }

  String _streamReadString(_BinaryReader reader) {
    final length = reader.readUInt32();
    reader.readInt32(); // Skip
    
    if (length > 0) {
      final bytes = reader.readBytes(length);
      reader.readInt32(); // Skip padding after string?
      return utf8.decode(bytes);
    } else {
      reader.readInt32(); // Skip padding
      return "";
    }
  }
}

class _BinaryReader {
  final ByteData _view;
  int _offset;
  final int _length;

  _BinaryReader(Uint8List buffer)
      : _view = ByteData.sublistView(buffer),
        _offset = 0,
        _length = buffer.length;

  int get remaining => _length - _offset;

  int readUInt32() {
    if (remaining < 4) throw Exception("EndOfStream");
    final value = _view.getUint32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  int readInt32() {
    if (remaining < 4) throw Exception("EndOfStream");
    final value = _view.getInt32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  Uint8List readBytes(int length) {
    if (remaining < length) throw Exception("EndOfStream");
    final bytes = Uint8List.view(_view.buffer, _view.offsetInBytes + _offset, length);
    _offset += length;
    return bytes;
  }
}
