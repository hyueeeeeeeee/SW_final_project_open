import 'package:flutter/material.dart';

class AlbumArt extends StatelessWidget {
  final int seed;
  final double size;
  final double radius;

  const AlbumArt({super.key, required this.seed, this.size = 46, this.radius = 13});

  static const _palettes = [
    [Color(0xFF8B4513), Color(0xFFD2691E)],
    [Color(0xFF2F4F7F), Color(0xFF4682B4)],
    [Color(0xFF556B2F), Color(0xFF8FBC8F)],
    [Color(0xFF8B008B), Color(0xFFDA70D6)],
    [Color(0xFFB8860B), Color(0xFFDAA520)],
    [Color(0xFF8B0000), Color(0xFFCD5C5C)],
    [Color(0xFF006400), Color(0xFF32CD32)],
    [Color(0xFF191970), Color(0xFF6495ED)],
  ];

  static const _notes = ['♩', '♪', '♫', '♬'];

  @override
  Widget build(BuildContext context) {
    final palette = _palettes[seed % _palettes.length];
    final bg = palette[0];
    final fg = palette[1];
    final note = _notes[seed % _notes.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Stack(
        children: [
          Positioned(
            left: size * 0.17,
            top: size * 0.17,
            child: Container(
              width: size * 0.65,
              height: size * 0.65,
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(size * 0.13),
              ),
            ),
          ),
          Center(
            child: Text(
              note,
              style: TextStyle(fontSize: size * 0.39, color: fg, fontFamily: 'serif'),
            ),
          ),
        ],
      ),
    );
  }
}
