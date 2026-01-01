import 'dart:typed_data';

class ByteReader {
  final ByteData _view;
  int _offset;
  final int _length;

  ByteReader(Uint8List buffer, [int offset = 0])
      : _view = ByteData.sublistView(buffer),
        _offset = offset,
        _length = buffer.length;

  int get remaining => _length - _offset;
  int get offset => _offset;

  bool tryPeekUInt32BE(List<int> outValue) {
    if (remaining < 4) {
      return false;
    }
    outValue[0] = _view.getUint32(_offset, Endian.big);
    return true;
  }

  int readUInt32BE() {
    if (remaining < 4) throw Exception("EndOfStream");
    final value = _view.getUint32(_offset, Endian.big);
    _offset += 4;
    return value;
  }

  int peekUInt32BE() {
    if (remaining < 4) throw Exception("EndOfStream");
    return _view.getUint32(_offset, Endian.big);
  }

  int readUInt16BE() {
    if (remaining < 2) throw Exception("EndOfStream");
    final value = _view.getUint16(_offset, Endian.big);
    _offset += 2;
    return value;
  }

  int readUInt8() {
    if (remaining < 1) throw Exception("EndOfStream");
    final value = _view.getUint8(_offset);
    _offset += 1;
    return value;
  }

  BigInt readUInt64BE() {
    if (remaining < 8) throw Exception("EndOfStream");
    final value = _view.getUint64(_offset, Endian.big);
    _offset += 8;
    return BigInt.from(value); // Dart int is 64-bit, but BigInt is safer for unsigned 64-bit logic if needed
  }

  Uint8List readBytes(int count) {
    if (remaining < count) throw Exception("EndOfStream");
    final bytes = _view.buffer.asUint8List(_view.offsetInBytes + _offset, count);
    _offset += count;
    return bytes;
  }
  
  void skip(int count) {
    if (remaining < count) throw Exception("EndOfStream");
    _offset += count;
  }
}
