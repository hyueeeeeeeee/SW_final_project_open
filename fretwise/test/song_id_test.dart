import 'package:flutter_test/flutter_test.dart';
import 'package:fretwise/utils/song_id.dart';

void main() {
  test('makeSongId produces slug-like id', () {
    final id = makeSongId('Wonderwall', 'Oasis');
    expect(id, 'wonderwall--oasis');

    final id2 = makeSongId('Hello, World!', 'Artist & Co');
    expect(id2, 'hello__world_--artist___co');
  });
}
