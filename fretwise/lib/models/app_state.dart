import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/song.dart';

class DiaryEntry {
  final DateTime date;
  final String title;
  final String artist;
  final int duration; // seconds
  final String userNote;

  DiaryEntry({required this.date, required this.title, required this.artist, required this.duration, this.userNote = ''});
}

class AppState extends ChangeNotifier {
  bool _darkMode = false;
  int _coins = 340;
  Set<String> _ownedItems = {'streak_shield_1'};
  final List<Song> _extraSongs = [];
  final Set<String> _removedLibrarySongs = {};
  final List<DiaryEntry> _diaryEntries = [];

  bool get darkMode => _darkMode;
  Color get accent => AppColors.accent;
  int get coins => _coins;
  Set<String> get ownedItems => Set.unmodifiable(_ownedItems);
  List<Song> get extraSongs => List.unmodifiable(_extraSongs);
  Set<String> get removedLibrarySongs => Set.unmodifiable(_removedLibrarySongs);
  List<DiaryEntry> get diaryEntries => List.unmodifiable(_diaryEntries);

  void addDiaryEntry(DiaryEntry entry) {
    _diaryEntries.insert(0, entry);
    notifyListeners();
  }

  void updateLatestDiaryNote(String note) {
    if (_diaryEntries.isNotEmpty) {
      final e = _diaryEntries[0];
      _diaryEntries[0] = DiaryEntry(date: e.date, title: e.title, artist: e.artist, duration: e.duration, userNote: note);
      notifyListeners();
    }
  }

  void addSong(Song song) {
    final isBase = Song.library.any((s) => s.title.toLowerCase() == song.title.toLowerCase());
    if (isBase) {
      _removedLibrarySongs.remove(song.title);
    } else {
      _extraSongs.add(song);
    }
    notifyListeners();
  }

  void removeSongByTitle(String title) {
    final extraIdx = _extraSongs.indexWhere((s) => s.title.toLowerCase() == title.toLowerCase());
    if (extraIdx >= 0) {
      _extraSongs.removeAt(extraIdx);
    } else {
      _removedLibrarySongs.add(title);
    }
    notifyListeners();
  }

  AppTheme get theme => AppTheme(isDark: _darkMode);

  void toggleDarkMode() {
    _darkMode = !_darkMode;
    notifyListeners();
  }

  void setCoins(int value) {
    _coins = value;
    notifyListeners();
  }

  void spendCoins(int amount) {
    _coins -= amount;
    notifyListeners();
  }

  void addOwnedItem(String id) {
    _ownedItems = {..._ownedItems, id};
    notifyListeners();
  }

  bool ownsItem(String id) => _ownedItems.contains(id);
}
