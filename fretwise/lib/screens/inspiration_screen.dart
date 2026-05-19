import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/album_art.dart';
import '../models/song.dart';

class InspirationScreen extends StatefulWidget {
  final AppTheme t;
  final void Function(String screen, {Map<String, dynamic>? props}) navigate;
  final List<Song> extraSongs;
  final Set<String> removedLibrarySongs;
  final void Function(Song) onAddSong;
  final void Function(String title) onRemoveSong;

  const InspirationScreen({
    super.key,
    required this.t,
    required this.navigate,
    required this.extraSongs,
    required this.removedLibrarySongs,
    required this.onAddSong,
    required this.onRemoveSong,
  });

  @override
  State<InspirationScreen> createState() => _InspirationScreenState();
}

class _InspirationScreenState extends State<InspirationScreen> {
  int _current = 0;
  bool _playing = true;

  AppTheme get t => widget.t;

  bool _isInLibrary(String title) {
    final key = title.toLowerCase();
    if (widget.extraSongs.any((s) => s.title.toLowerCase() == key)) return true;
    if (widget.removedLibrarySongs.contains(title)) return false;
    return Song.library.any((s) => s.title.toLowerCase() == key);
  }

  void _handleButtonTap(BuildContext context, ({String title, String artist, String genre, int bpm, int seed, String desc}) song) {
    final title = song.title;

    if (!_isInLibrary(title)) {
      final rng = Random();
      final mins = 2 + rng.nextInt(5);
      final secs = rng.nextInt(60);
      widget.onAddSong(Song(
        title: title,
        artist: song.artist,
        seed: song.seed,
        bpm: song.bpm,
        duration: '$mins:${secs.toString().padLeft(2, '0')}',
        progress: 5 + rng.nextInt(91),
      ));
      setState(() {});
      return;
    }

    final isExtra = widget.extraSongs.any((s) => s.title.toLowerCase() == title.toLowerCase());
    if (isExtra) {
      widget.onRemoveSong(title);
      setState(() {});
      return;
    }

    // Base library song — confirm before removing
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from library?'),
        content: Text('"$title" will be removed from your library.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onRemoveSong(title);
              setState(() {});
            },
            child: Text('Remove', style: TextStyle(color: widget.t.accent)),
          ),
        ],
      ),
    );
  }

  static const _songs = [
    (title: 'Wish You Were Here', artist: 'Pink Floyd', genre: 'Classic Rock', bpm: 98, seed: 6, desc: 'Iconic 12-string acoustic intro — great for fingerpicking practice.'),
    (title: 'Blackbird', artist: 'The Beatles', genre: 'Folk / Rock', bpm: 96, seed: 1, desc: 'Beautiful fingerstyle piece using open G tuning. Beginner-friendly.'),
    (title: 'Hotel California', artist: 'Eagles', genre: 'Soft Rock', bpm: 75, seed: 2, desc: 'Legendary outro solo with smooth bends and clean tone.'),
    (title: 'Stairway to Heaven', artist: 'Led Zeppelin', genre: 'Hard Rock', bpm: 82, seed: 8, desc: 'Timeless fingerpicked arpeggio intro — every guitarist\'s milestone.'),
  ];

  static const _palettes = [
    (from: Color(0xFF1A2A1A), to: Color(0xFF0D1A0D), accent: Color(0xFF4A7C59)),
    (from: Color(0xFF1A1A2A), to: Color(0xFF0D0D1A), accent: Color(0xFF4A5C7C)),
    (from: Color(0xFF2A1A0D), to: Color(0xFF1A0D05), accent: Color(0xFFC96A3A)),
    (from: Color(0xFF1A0D2A), to: Color(0xFF0D051A), accent: Color(0xFF7A4AC9)),
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
                      padding: const EdgeInsets.fromLTRB(20, 40, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(song.title,
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                              ),
                              const SizedBox(width: 14),
                              _AddToLibraryButton(
                                inLibrary: _isInLibrary(song.title),
                                onTap: () => _handleButtonTap(context, song),
                              ),
                            ],
                          ),
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

class _AddToLibraryButton extends StatelessWidget {
  final bool inLibrary;
  final VoidCallback onTap;

  const _AddToLibraryButton({required this.inLibrary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: inLibrary
              ? CustomPaint(
                  size: const Size(24, 24),
                  painter: const _CheckCirclePainter(),
                )
              : const Icon(Icons.add, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _CheckCirclePainter extends CustomPainter {
  const _CheckCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      Paint()..color = Colors.white,
    );

    final path = Path()
      ..moveTo(size.width * 0.24, size.height * 0.50)
      ..lineTo(size.width * 0.42, size.height * 0.68)
      ..lineTo(size.width * 0.76, size.height * 0.32);

    canvas.drawPath(
      path,
      Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.13
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_CheckCirclePainter old) => false;
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
