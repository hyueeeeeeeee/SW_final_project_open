import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/album_art.dart';

class InspirationScreen extends StatefulWidget {
  final AppTheme t;
  final void Function(String screen, {Map<String, dynamic>? props}) navigate;

  const InspirationScreen({super.key, required this.t, required this.navigate});

  @override
  State<InspirationScreen> createState() => _InspirationScreenState();
}

class _InspirationScreenState extends State<InspirationScreen> {
  int _current = 0;
  bool _playing = true;

  AppTheme get t => widget.t;

  static const _songs = [
    (title: 'Wish You Were Here', artist: 'Pink Floyd', genre: 'Classic Rock', bpm: 98, seed: 6, desc: 'Iconic 12-string acoustic intro — great for fingerpicking practice.'),
    (title: 'Blackbird', artist: 'The Beatles', genre: 'Folk / Rock', bpm: 96, seed: 1, desc: 'Beautiful fingerstyle piece using open G tuning. Beginner-friendly.'),
    (title: 'Hotel California', artist: 'Eagles', genre: 'Soft Rock', bpm: 75, seed: 2, desc: 'Legendary outro solo with smooth bends and clean tone.'),
  ];

  static const _palettes = [
    (from: Color(0xFF1A2A1A), to: Color(0xFF0D1A0D), accent: Color(0xFF4A7C59)),
    (from: Color(0xFF1A1A2A), to: Color(0xFF0D0D1A), accent: Color(0xFF4A5C7C)),
    (from: Color(0xFF2A1A0D), to: Color(0xFF1A0D05), accent: Color(0xFFC96A3A)),
  ];

  @override
  Widget build(BuildContext context) {
    final song = _songs[_current];
    final pal = _palettes[_current];

    return Column(
      children: [
        // Video area
        Expanded(
          child: GestureDetector(
            onHorizontalDragEnd: (d) {
              if (d.primaryVelocity == null) return;
              if (d.primaryVelocity! < -300 && _current < _songs.length - 1) {
                setState(() => _current++);
              } else if (d.primaryVelocity! > 300 && _current > 0) {
                setState(() => _current--);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [pal.from, pal.to],
                ),
              ),
              child: Stack(
                children: [
                  // Shimmer lines
                  Positioned.fill(
                    child: CustomPaint(painter: _ShimmerPainter()),
                  ),

                  // Glow blob
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 200, height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: pal.accent.withValues(alpha: 0.18),
                          boxShadow: [BoxShadow(color: pal.accent.withValues(alpha: 0.3), blurRadius: 60, spreadRadius: 20)],
                        ),
                      ),
                    ),
                  ),

                  // Album art faded
                  Positioned(
                    top: 0, bottom: 0, left: 0, right: 0,
                    child: Center(
                      child: Opacity(
                        opacity: 0.22,
                        child: AlbumArt(seed: song.seed, size: 180, radius: 32),
                      ),
                    ),
                  ),

                  // Counter badge
                  Positioned(
                    top: 16, right: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      child: Text(
                        '${_current + 1} / ${_songs.length}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),

                  // Play/pause
                  Center(
                    child: GestureDetector(
                      onTap: () => setState(() => _playing = !_playing),
                      child: Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.18),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                        ),
                        child: Icon(
                          _playing ? Icons.pause : Icons.play_arrow,
                          size: 24, color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // Song info at bottom
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(song.title,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text('${song.artist} · ${song.genre}',
                              style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7))),
                          const SizedBox(height: 6),
                          Text(song.desc,
                              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.55), height: 1.5)),
                        ],
                      ),
                    ),
                  ),

                  // Peek hints
                  if (_current < _songs.length - 1)
                    Positioned(
                      right: 0, top: 0, bottom: 0,
                      child: Container(
                        width: 14,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                        ),
                      ),
                    ),
                  if (_current > 0)
                    Positioned(
                      left: 0, top: 0, bottom: 0,
                      child: Container(
                        width: 14,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Dot indicators
        Container(
          color: t.bg,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_songs.length, (i) => GestureDetector(
              onTap: () => setState(() => _current = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _current ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == _current ? t.accent : t.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            )),
          ),
        ),

        // CTAs
        Container(
          color: t.bg,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => widget.navigate('practicing', props: {
                    'title': song.title,
                    'artist': song.artist,
                    'bpm': song.bpm,
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text("Let's practice",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => widget.navigate('library'),
                child: Text('Go to my library',
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: t.textSec,
                      decoration: TextDecoration.underline,
                      decorationColor: t.border,
                    )),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.015)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => false;
}
