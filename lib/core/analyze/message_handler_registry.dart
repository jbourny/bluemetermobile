import 'package:flutter/foundation.dart';

import '../state/data_storage.dart';
import 'processors/message_processor.dart';
import 'processors/sync_near_entities_processor.dart';
import 'processors/sync_container_data_processor.dart';
import 'processors/sync_container_dirty_data_processor.dart';
import 'processors/delta_info_processors.dart';
import 'processors/team_matching_processor.dart';

class MessageHandlerRegistry {
  final Map<int, IMessageProcessor> _processors = {};

  // Method IDs
  static const int _methodSyncNearEntities = 0x00000006;
  static const int _methodSyncContainerData = 0x00000015;
  static const int _methodSyncContainerDirtyData = 0x00000016;
  static const int _methodSyncToMeDeltaInfo = 0x0000002E;
  static const int _methodSyncNearDeltaInfo = 0x0000002D;
  static const int _methodTeamMatching = 0x0000002B;

  MessageHandlerRegistry(DataStorage storage) {
    _processors[_methodSyncNearEntities] = SyncNearEntitiesProcessor(storage);
    _processors[_methodSyncContainerData] = SyncContainerDataProcessor(storage);
    _processors[_methodSyncContainerDirtyData] = SyncContainerDirtyDataProcessor(storage);
    _processors[_methodSyncToMeDeltaInfo] = SyncToMeDeltaInfoProcessor(storage);
    _processors[_methodSyncNearDeltaInfo] = SyncNearDeltaInfoProcessor(storage);
    _processors[_methodTeamMatching] = TeamMatchingProcessor(storage);
  }

  IMessageProcessor? getProcessor(int methodId) {
    return _processors[methodId];
  }
}
