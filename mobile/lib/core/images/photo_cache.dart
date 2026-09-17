import 'dart:convert';
import 'dart:typed_data';

/// Reuse byte identity for Flutter's image cache; bound retained source + bytes.
class PhotoCache {
  static final shared = PhotoCache();
  final int maxBytes;
  PhotoCache({this.maxBytes = 24 * 1024 * 1024});
  final _entries = <String, Uint8List>{};
  int _bytes = 0;
  int get retainedBytes => _bytes;
  Uint8List decode(String value) {
    final cached = _entries.remove(value);
    if (cached != null) {
      _entries[value] = cached;
      return cached;
    }
    final bytes = base64Decode(value);
    final cost = value.length * 2 + bytes.length;
    if (cost > maxBytes) return bytes;
    while (_bytes + cost > maxBytes && _entries.isNotEmpty) {
      final key = _entries.keys.first;
      _bytes -= key.length * 2 + _entries.remove(key)!.length;
    }
    _entries[value] = bytes;
    _bytes += cost;
    return bytes;
  }

  void clear() {
    _entries.clear();
    _bytes = 0;
  }
}
