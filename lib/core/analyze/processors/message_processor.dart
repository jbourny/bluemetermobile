import 'dart:typed_data';

abstract class IMessageProcessor {
  void process(Uint8List payload);
}
