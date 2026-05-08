class Song {
  final String title;
  final String artist;
  final String duration;
  final int progress;
  final int lastPracticed;
  final int seed;
  final int bpm;
  final String bars;

  const Song({
    required this.title,
    required this.artist,
    this.duration = '?:??',
    this.progress = 0,
    this.lastPracticed = 0,
    this.seed = 0,
    this.bpm = 87,
    this.bars = 'Bars 1–8',
  });

  Song copyWith({int? progress, int? lastPracticed}) => Song(
        title: title,
        artist: artist,
        duration: duration,
        progress: progress ?? this.progress,
        lastPracticed: lastPracticed ?? this.lastPracticed,
        seed: seed,
        bpm: bpm,
        bars: bars,
      );

  static const library = [
    Song(title: 'Wonderwall', artist: 'Oasis', duration: '3:28', progress: 80, lastPracticed: 3, seed: 0, bpm: 87),
    Song(title: 'Blackbird', artist: 'The Beatles', duration: '2:18', progress: 45, lastPracticed: 1, seed: 1, bpm: 96),
    Song(title: 'Hotel California', artist: 'Eagles', duration: '6:30', progress: 20, lastPracticed: 7, seed: 2, bpm: 75),
    Song(title: "Knockin' on Heaven's Door", artist: 'Bob Dylan', duration: '2:31', progress: 100, lastPracticed: 2, seed: 3, bpm: 72),
    Song(title: 'Nothing Else Matters', artist: 'Metallica', duration: '6:28', progress: 10, lastPracticed: 14, seed: 4, bpm: 69),
    Song(title: 'Horse With No Name', artist: 'America', duration: '4:10', progress: 60, lastPracticed: 5, seed: 5, bpm: 120),
    Song(title: 'Wish You Were Here', artist: 'Pink Floyd', duration: '5:34', progress: 35, lastPracticed: 10, seed: 6, bpm: 98),
    Song(title: 'More Than Words', artist: 'Extreme', duration: '5:55', progress: 55, lastPracticed: 4, seed: 7, bpm: 84),
  ];

  static const inspiration = [
    Song(title: 'Wish You Were Here', artist: 'Pink Floyd', seed: 6, bpm: 98),
    Song(title: 'Blackbird', artist: 'The Beatles', seed: 1, bpm: 96),
    Song(title: 'Hotel California', artist: 'Eagles', seed: 2, bpm: 75),
  ];
}
