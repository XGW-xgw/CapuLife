import 'dart:convert';
import 'dart:math' as math;

List<int> utf8Bytes(String input) => utf8.encode(input);

String bytesToHex(List<int> bytes) => bytes
    .map((byte) => (byte & 0xff).toRadixString(16).padLeft(2, '0'))
    .join();

String md5Hex(String input) => bytesToHex(md5Bytes(utf8Bytes(input)));
String md5Upper(String input) => md5Hex(input).toUpperCase();

List<int> md5Bytes(List<int> input) {
  const shifts = [
    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
    5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
    4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
    6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
  ];
  final k = List<int>.generate(
    64,
    (i) => (math.sin(i + 1).abs() * 4294967296).floor() & 0xffffffff,
  );
  final data = [...input];
  final bitLength = data.length * 8;
  data.add(0x80);
  while (data.length % 64 != 56) {
    data.add(0);
  }
  final high = (bitLength ~/ 4294967296) & 0xffffffff;
  final low = bitLength & 0xffffffff;
  data.addAll([
    low & 0xff,
    (low >>> 8) & 0xff,
    (low >>> 16) & 0xff,
    (low >>> 24) & 0xff,
    high & 0xff,
    (high >>> 8) & 0xff,
    (high >>> 16) & 0xff,
    (high >>> 24) & 0xff,
  ]);
  var a0 = 0x67452301;
  var b0 = 0xefcdab89;
  var c0 = 0x98badcfe;
  var d0 = 0x10325476;
  for (var offset = 0; offset < data.length; offset += 64) {
    final m = List<int>.filled(16, 0);
    for (var i = 0; i < 16; i += 1) {
      final p = offset + i * 4;
      m[i] =
          (data[p] |
              (data[p + 1] << 8) |
              (data[p + 2] << 16) |
              (data[p + 3] << 24)) &
          0xffffffff;
    }
    var a = a0;
    var b = b0;
    var c = c0;
    var d = d0;
    for (var i = 0; i < 64; i += 1) {
      int f;
      int g;
      if (i < 16) {
        f = (b & c) | (~b & d);
        g = i;
      } else if (i < 32) {
        f = (d & b) | (~d & c);
        g = (5 * i + 1) % 16;
      } else if (i < 48) {
        f = b ^ c ^ d;
        g = (3 * i + 5) % 16;
      } else {
        f = c ^ (b | (~d & 0xffffffff));
        g = (7 * i) % 16;
      }
      final sum = (a + f + k[i] + m[g]) & 0xffffffff;
      final temp = d;
      d = c;
      c = b;
      b = (b + rotl32(sum, shifts[i])) & 0xffffffff;
      a = temp;
    }
    a0 = (a0 + a) & 0xffffffff;
    b0 = (b0 + b) & 0xffffffff;
    c0 = (c0 + c) & 0xffffffff;
    d0 = (d0 + d) & 0xffffffff;
  }
  final out = <int>[];
  for (final word in [a0, b0, c0, d0]) {
    out.addAll([
      word & 0xff,
      (word >>> 8) & 0xff,
      (word >>> 16) & 0xff,
      (word >>> 24) & 0xff,
    ]);
  }
  return out;
}

int rotl32(int value, int shift) {
  final v = value & 0xffffffff;
  final s = shift & 31;
  if (s == 0) return v;
  return ((v << s) | (v >>> (32 - s))) & 0xffffffff;
}

int rotr32(int value, int shift) {
  final v = value & 0xffffffff;
  final s = shift & 31;
  if (s == 0) return v;
  return ((v >>> s) | (v << (32 - s))) & 0xffffffff;
}

List<int> sha1Bytes(String input) {
  final bytes = utf8Bytes(input);
  final bitLength = bytes.length * 8;
  final data = [...bytes];
  data.add(0x80);
  while (data.length % 64 != 56) {
    data.add(0);
  }
  final high = (bitLength ~/ 4294967296) & 0xffffffff;
  final low = bitLength & 0xffffffff;
  data.addAll([
    (high >>> 24) & 0xff,
    (high >>> 16) & 0xff,
    (high >>> 8) & 0xff,
    high & 0xff,
    (low >>> 24) & 0xff,
    (low >>> 16) & 0xff,
    (low >>> 8) & 0xff,
    low & 0xff,
  ]);
  final w = List<int>.filled(80, 0);
  var h0 = 0x67452301;
  var h1 = 0xefcdab89;
  var h2 = 0x98badcfe;
  var h3 = 0x10325476;
  var h4 = 0xc3d2e1f0;
  for (var offset = 0; offset < data.length; offset += 64) {
    for (var i = 0; i < 16; i += 1) {
      final p = offset + i * 4;
      w[i] =
          ((data[p] << 24) |
              (data[p + 1] << 16) |
              (data[p + 2] << 8) |
              data[p + 3]) &
          0xffffffff;
    }
    for (var i = 16; i < 80; i += 1) {
      w[i] = rotl32(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
    }
    var a = h0;
    var b = h1;
    var c = h2;
    var d = h3;
    var e = h4;
    for (var i = 0; i < 80; i += 1) {
      int f;
      int k;
      if (i < 20) {
        f = (b & c) | (~b & d);
        k = 0x5a827999;
      } else if (i < 40) {
        f = b ^ c ^ d;
        k = 0x6ed9eba1;
      } else if (i < 60) {
        f = (b & c) | (b & d) | (c & d);
        k = 0x8f1bbcdc;
      } else {
        f = b ^ c ^ d;
        k = 0xca62c1d6;
      }
      final temp = (rotl32(a, 5) + f + e + k + w[i]) & 0xffffffff;
      e = d;
      d = c;
      c = rotl32(b, 30);
      b = a;
      a = temp;
    }
    h0 = (h0 + a) & 0xffffffff;
    h1 = (h1 + b) & 0xffffffff;
    h2 = (h2 + c) & 0xffffffff;
    h3 = (h3 + d) & 0xffffffff;
    h4 = (h4 + e) & 0xffffffff;
  }
  final out = <int>[];
  for (final word in [h0, h1, h2, h3, h4]) {
    out.addAll([
      (word >>> 24) & 0xff,
      (word >>> 16) & 0xff,
      (word >>> 8) & 0xff,
      word & 0xff,
    ]);
  }
  return out;
}

String base64Utf8(String input) => base64Encode(utf8Bytes(input));

int crc32(List<int> bytes, [int offset = 0, int? length]) {
  final end = length == null ? bytes.length : offset + length;
  var crc = 0xffffffff;
  for (var i = offset; i < end; i += 1) {
    crc ^= bytes[i] & 0xff;
    for (var j = 0; j < 8; j += 1) {
      crc = (crc & 1) != 0 ? (0xedb88320 ^ (crc >>> 1)) : (crc >>> 1);
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

int xxHash32(List<int> bytes, [int seed = 0]) {
  const prime1 = 0x9e3779b1;
  const prime2 = 0x85ebca77;
  const prime3 = 0xc2b2ae3d;
  const prime4 = 0x27d4eb2f;
  const prime5 = 0x165667b1;
  int u(int x) => x & 0xffffffff;
  int mul(int a, int b) => (a * b) & 0xffffffff;
  int read(int i) =>
      (bytes[i] |
          (bytes[i + 1] << 8) |
          (bytes[i + 2] << 16) |
          (bytes[i + 3] << 24)) &
      0xffffffff;
  final len = bytes.length;
  var v1 = u(seed + prime1 + prime2);
  var v2 = u(seed + prime2);
  var v3 = u(seed);
  var v4 = u(seed - prime1);
  var p = 0;
  if (len >= 16) {
    final limit = len - 16;
    while (p <= limit) {
      v1 = mul(rotl32(u(v1 + mul(read(p), prime2)), 13), prime1);
      v2 = mul(rotl32(u(v2 + mul(read(p + 4), prime2)), 13), prime1);
      v3 = mul(rotl32(u(v3 + mul(read(p + 8), prime2)), 13), prime1);
      v4 = mul(rotl32(u(v4 + mul(read(p + 12), prime2)), 13), prime1);
      p += 16;
    }
  }
  var h32 = len > 16
      ? u(rotl32(v1, 1) + rotl32(v2, 7) + rotl32(v3, 12) + rotl32(v4, 18))
      : u(v3 + prime5);
  h32 = u(h32 + len);
  while (p <= len - 4) {
    h32 = mul(rotl32(u(h32 + mul(read(p), prime3)), 17), prime4);
    p += 4;
  }
  while (p < len) {
    h32 = mul(rotl32(u(h32 + mul(bytes[p] & 0xff, prime5)), 11), prime1);
    p += 1;
  }
  h32 = mul(h32 ^ (h32 >>> 15), prime2);
  h32 = mul(h32 ^ (h32 >>> 13), prime3);
  return u(h32 ^ (h32 >>> 16));
}

List<int> heliosHash(List<int> bytes) {
  final buf = List<int>.filled(bytes.length + 25, 0);
  for (var i = 0; i < bytes.length; i += 1) {
    buf[i] = bytes[i];
  }
  var lo = 0xffffffff;
  var hi = 0xff;
  void writeResult(int offset) {
    buf[offset] = lo & 0xff;
    buf[offset + 1] = (lo >>> 8) & 0xff;
    buf[offset + 2] = (lo >>> 16) & 0xff;
    buf[offset + 3] = (lo >>> 24) & 0xff;
    buf[offset + 4] = hi & 0xff;
  }

  int getSlice(int start) {
    if (start == 0) return lo;
    if (start == 1) return ((lo >>> 1) | (hi << 31)) & 0xffffffff;
    if (start == 7) return ((lo >>> 7) | (hi << 25)) & 0xffffffff;
    if (start == 8) return ((lo >>> 8) | (hi << 24)) & 0xffffffff;
    return 0;
  }

  void setSlice(int start, int slice) {
    if (start == 0) {
      lo = slice & 0xffffffff;
      return;
    }
    if (start == 1) {
      lo = ((lo & 1) | ((slice & 0x7fffffff) << 1)) & 0xffffffff;
      hi = ((hi & 0xfe) | ((slice >>> 31) & 1)) & 0xffffffff;
      return;
    }
    if (start == 7) {
      lo = ((lo & 0x7f) | ((slice & 0x1ffffff) << 7)) & 0xffffffff;
      hi = ((hi & 0x80) | ((slice >>> 25) & 0x7f)) & 0xffffffff;
      return;
    }
    if (start == 8) {
      lo = ((lo & 0xff) | ((slice & 0xffffff) << 8)) & 0xffffffff;
      hi = (slice >>> 24) & 0xff;
    }
  }

  writeResult(bytes.length);
  final encoders = [
    (true, 8, 0),
    (false, 0, 1),
    (false, 1, 1),
    (true, 7, 1),
  ];
  for (var i = 0; i < encoders.length; i += 1) {
    final (useCrc, start, flag) = encoders[i];
    final len = bytes.length + (i + 1) * 5;
    final sliceBytes = buf.sublist(0, len);
    final value = useCrc ? crc32(sliceBytes) : xxHash32(sliceBytes);
    var slice = getSlice(start);
    slice = flag == 0 ? (slice & value) : (slice ^ value);
    setSlice(start, slice);
    writeResult(len);
  }
  return [
    lo & 0xff,
    (lo >>> 8) & 0xff,
    (lo >>> 16) & 0xff,
    (lo >>> 24) & 0xff,
    hi & 0xff,
  ];
}

String heliosBase32Encode(List<int> bytes) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567=';
  final out = StringBuffer();
  final blocks = (bytes.length / 5).ceil();
  for (var i = 0; i < blocks; i += 1) {
    final s = List<int>.filled(5, 0);
    var valid = 5;
    for (var k = 0; k < 5; k += 1) {
      final index = i * 5 + k;
      if (index < bytes.length) {
        s[k] = bytes[index] & 0xff;
      } else {
        s[k] = 0;
        valid -= 1;
      }
    }
    final dt = <int, int>{1: 6, 2: 4, 3: 3, 4: 1, 5: 0}[valid] ?? -1;
    final parts = [
      (s[0] >>> 3) & 31,
      ((s[0] & 7) << 2) | ((s[1] >>> 6) & 3),
      (s[1] >>> 1) & 31,
      ((s[1] & 1) << 4) | ((s[2] >>> 4) & 15),
      ((s[2] & 15) << 1) | ((s[3] >>> 7) & 1),
      (s[3] >>> 2) & 31,
      ((s[3] & 3) << 3) | ((s[4] >>> 5) & 7),
      s[4] & 31,
    ];
    for (var k = 0; k < parts.length - dt; k += 1) {
      out.write(alphabet[parts[k]]);
    }
  }
  return out.toString();
}

String baseCuid(String androidId) => md5Upper('com.baidu$androidId');

String finalCuid(String androidId, [String imei = '000000000000000']) {
  final effective = imei.isEmpty ? '0' : imei;
  return '${baseCuid(androidId)}|${effective.split('').reversed.join()}';
}

String newCuid(String androidId) {
  final cuid = baseCuid(androidId);
  return '$cuid|V${heliosBase32Encode(heliosHash(utf8Bytes(cuid)))}';
}

String tiebaAid({required String androidId, required String uuid}) {
  final effective = androidId.isEmpty ? '000000000' : androidId;
  final sha1 = sha1Bytes('com.helios$effective$uuid');
  final raw = 'A00-${heliosBase32Encode(sha1)}-';
  return raw + heliosBase32Encode(heliosHash(utf8Bytes(raw)));
}

String calculateTiebaSign(String sortedRaw) => md5Upper('${sortedRaw}tiebaclient!!!');

String encodeSignedFormBody(Map<String, String> params) {
  final pairs = params.entries
      .map((entry) => '${entry.key}=${entry.value}')
      .toList()
    ..sort();
  final sign = calculateTiebaSign(pairs.join(''));
  final encoded = params.entries
      .map(
        (entry) =>
            '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
      )
      .toList()
    ..sort();
  encoded.add('sign=$sign');
  return encoded.join('&');
}

String signMultipartFields(Map<String, String> fields) {
  final sorted = fields.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return calculateTiebaSign(
    sorted.map((entry) => '${entry.key}=${entry.value}').join(),
  );
}