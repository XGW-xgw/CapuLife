import 'dart:convert';
import 'dart:typed_data';

const int wireVarint = 0;
const int wireFixed64 = 1;
const int wireLen = 2;
const int wireStartGroup = 3;
const int wireEndGroup = 4;
const int wireFixed32 = 5;

/// Minimal protobuf wire writer mirroring the original Tieba client.
class ProtoWriter {
  ProtoWriter();

  final BytesBuilder _buffer = BytesBuilder(copy: false);

  void _tag(int field, int wire) => _varint((field << 3) | wire);

  void _varint(int value) {
    var v = value;
    while (v > 0x7f) {
      _buffer.addByte((v & 0x7f) | 0x80);
      v = v >> 7;
    }
    _buffer.addByte(v & 0x7f);
  }

  void int32(int field, int? value, [bool emitZero = false]) {
    if (value == null) return;
    if (!emitZero && value == 0) return;
    _tag(field, wireVarint);
    _varint(value);
  }

  void int64(int field, int? value, [bool emitZero = false]) =>
      int32(field, value, emitZero);

  void uint32(int field, int? value, [bool emitZero = false]) =>
      int32(field, value, emitZero);

  void boolean(int field, bool? value, [bool emitFalse = false]) {
    if (value == null) return;
    if (!emitFalse && !value) return;
    _tag(field, wireVarint);
    _varint(value ? 1 : 0);
  }

  void doubleValue(int field, double? value, [bool emitZero = false]) {
    if (value == null) return;
    if (!emitZero && value == 0) return;
    _tag(field, wireFixed64);
    final data = ByteData(8)..setFloat64(0, value, Endian.little);
    _buffer.add(data.buffer.asUint8List());
  }

  void string(int field, String? value, [bool emitEmpty = false]) {
    if (value == null) return;
    if (!emitEmpty && value.isEmpty) return;
    final data = Uint8List.fromList(utf8.encode(value));
    _tag(field, wireLen);
    _varint(data.length);
    _buffer.add(data);
  }

  void bytesField(int field, List<int>? value, [bool emitEmpty = false]) {
    if (value == null) return;
    if (!emitEmpty && value.isEmpty) return;
    _tag(field, wireLen);
    _varint(value.length);
    _buffer.add(value);
  }

  void message(int field, List<int>? value, [bool emitEmpty = false]) =>
      bytesField(field, value, emitEmpty);

  void subMessage(int field, void Function(ProtoWriter writer) encode) {
    final nested = ProtoWriter();
    encode(nested);
    message(field, nested.toBytes(), true);
  }

  Uint8List toBytes() => _buffer.toBytes();
}

class ProtoReader {
  ProtoReader(this._bytes, [this._pos = 0, int? end])
      : _end = end ?? _bytes.length;

  final Uint8List _bytes;
  int _pos;
  final int _end;

  bool get isAtEnd => _pos >= _end;

  ({int tag, int wireType})? nextField() {
    if (_pos >= _end) return null;
    final key = readVarint();
    if (key == 0) {
      _pos = _end;
      return null;
    }
    return (tag: key >> 3, wireType: key & 7);
  }

  int readVarint() {
    var result = 0;
    var shift = 0;
    while (_pos < _end && shift < 64) {
      final byte = _bytes[_pos];
      _pos += 1;
      result |= (byte & 0x7f) << shift;
      if ((byte & 0x80) == 0) return result;
      shift += 7;
    }
    return result;
  }

  int readInt32() {
    final value = readVarint();
    return value > 0x7fffffff ? value - 0x100000000 : value;
  }

  int readUint32() => readVarint() & 0xffffffff;

  int readInt64() => readVarint();

  bool readBool() => readVarint() != 0;

  double readDouble() {
    if (_pos + 8 > _end) {
      _pos = _end;
      return 0;
    }
    final view = ByteData.sublistView(_bytes, _pos, _pos + 8);
    _pos += 8;
    return view.getFloat64(0, Endian.little);
  }

  Uint8List readBytes() {
    final length = readVarint();
    if (length <= 0 || _pos >= _end) return Uint8List(0);
    final actualEnd = (_pos + length).clamp(_pos, _end);
    final slice = Uint8List.sublistView(_bytes, _pos, actualEnd);
    _pos = actualEnd;
    return slice;
  }

  String readString() {
    final bytes = readBytes();
    if (bytes.isEmpty) return '';
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return '';
    }
  }

  ProtoReader readSubReader() {
    final length = readVarint();
    if (length <= 0 || _pos >= _end) return ProtoReader(_bytes, _end, _end);
    final start = _pos;
    final actualEnd = (_pos + length).clamp(start, _end);
    _pos = actualEnd;
    return ProtoReader(_bytes, start, actualEnd);
  }

  void skip(int wireType) {
    if (wireType == wireVarint) {
      readVarint();
    } else if (wireType == wireFixed64) {
      _pos = (_pos + 8).clamp(0, _end);
    } else if (wireType == wireLen) {
      final length = readVarint();
      if (length > 0) _pos = (_pos + length).clamp(0, _end);
    } else if (wireType == wireFixed32) {
      _pos = (_pos + 4).clamp(0, _end);
    } else if (wireType == wireStartGroup) {
      while (!isAtEnd) {
        final field = nextField();
        if (field == null || field.wireType == wireEndGroup) break;
        skip(field.wireType);
      }
    } else if (wireType == wireEndGroup) {
      // Nothing.
    } else {
      _pos = _end;
    }
  }

  void forEachField(bool Function(int tag, int wireType, ProtoReader reader) handler) {
    while (!isAtEnd) {
      final field = nextField();
      if (field == null) break;
      final consumed = handler(field.tag, field.wireType, this);
      if (!consumed) skip(field.wireType);
    }
  }
}