import 'dart:typed_data';

/// Pure Dart CRC32 implementation for Shazam binary signatures.
class Crc32 {
  static final List<int> _table = _generateTable();

  static List<int> _generateTable() {
    final table = List<int>.filled(256, 0);
    for (int i = 0; i < 256; i++) {
      int c = i;
      for (int k = 0; k < 8; k++) {
        if ((c & 1) != 0) {
          c = 0xedb88320 ^ (c >>> 1);
        } else {
          c = c >>> 1;
        }
      }
      table[i] = c;
    }
    return table;
  }

  static int compute(Uint8List bytes, int offset, int length) {
    int crc = 0xffffffff;
    final end = offset + length;
    for (int i = offset; i < end; i++) {
      crc = _table[(crc ^ bytes[i]) & 0xff] ^ (crc >>> 8);
    }
    return crc ^ 0xffffffff;
  }
}
