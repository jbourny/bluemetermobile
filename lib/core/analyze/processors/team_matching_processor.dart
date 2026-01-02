import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import '../../protocol/blue_protocol.dart';
import '../../state/data_storage.dart';
import 'message_processor.dart';

class TeamMatchingProcessor implements IMessageProcessor {
  final DataStorage _storage;

  TeamMatchingProcessor(this._storage);

  @override
  void process(Uint8List payload) {
    try {
      final charTeam = CharTeam.fromBuffer(payload);
      
      // Just logging for now as per C# implementation
      // "Queue pop detection is now handled by Return message burst detection"
      
      if (kDebugMode) {
        final teamId = charTeam.hasTeamId() ? charTeam.teamId.toString() : "NULL";
        final leaderId = charTeam.hasLeaderId() ? charTeam.leaderId.toString() : "NULL";
        final teamNum = charTeam.hasTeamNum() ? charTeam.teamNum.toString() : "NULL";
        final isMatching = charTeam.hasIsMatching() ? charTeam.isMatching.toString() : "NULL";
        final memberCount = charTeam.teamMemberData.length;
        final charIds = charTeam.charIds.join(", ");
        
        debugPrint("[BM] CharTeam - TeamId: $teamId, LeaderId: $leaderId, TeamNum: $teamNum, IsMatching: $isMatching, MemberCount: $memberCount, CharIds: [$charIds]");
      }
      
    } catch (e) {
      debugPrint("[BM] Error processing CharTeam: $e");
    }
  }
}
