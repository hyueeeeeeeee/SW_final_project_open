import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';
import 'song.dart';

// ======= 保留給「雨蓁」的假日記結構 (等她寫好 Session Firebase 再拿掉) =======
class DiaryEntry {
  final DateTime date;
  final String title;
  final String artist;
  final int duration; // seconds
  final String userNote;

  DiaryEntry({required this.date, required this.title, required this.artist, required this.duration, this.userNote = ''});
}
// =====================================================================

class AppState extends ChangeNotifier {
  bool _darkMode = false;
  bool _isLoadingAddSong = false;
  
  // 保留給商城、Profile 的舊狀態
  int _coins = 340; 
  Set<String> _ownedItems = {'streak_shield_1'};
  final List<DiaryEntry> _diaryEntries = []; 

  bool get darkMode => _darkMode;
  Color get accent => AppColors.accent;
  bool get isLoadingAddSong => _isLoadingAddSong;
  AppTheme get theme => AppTheme(isDark: _darkMode);

  int get coins => _coins;
  Set<String> get ownedItems => Set.unmodifiable(_ownedItems);
  List<DiaryEntry> get diaryEntries => List.unmodifiable(_diaryEntries);

  void toggleDarkMode() {
    _darkMode = !_darkMode;
    notifyListeners();
  }

  // --- 保留給其他同學的舊有狀態邏輯 ---
  void spendCoins(int amount) {
    _coins -= amount;
    notifyListeners();
  }
  
  void addOwnedItem(String id) {
    _ownedItems = {..._ownedItems, id};
    notifyListeners();
  }
  
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

  // --- 💡 巧君專屬區：Firebase & AI Workflows ---
  
  String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? 'test_user_123';

  // 監聽 Library 歌單
  Stream<List<SongEntry>> get libraryStream {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('songLibrary')
        .snapshots()
        .map((snap) => snap.docs.map((d) => SongEntry.fromFirestore(d)).toList());
  }

  // 監聽 Inspiration Feed 短影音
  Stream<List<FeedItem>> get feedStream {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('feed')
        .snapshots()
        .map((snap) => snap.docs.map((d) => FeedItem.fromFirestore(d)).toList());
  }

  // Library Page: 呼叫 AI 搜尋歌曲資訊
 // ... 前面的 import 不變

// Library Page: 呼叫 AI 搜尋歌曲資訊
// ... 其他部分不變

// Library Page: 呼叫 AI 搜尋歌曲資訊
  Future<void> searchSongToLibrary(String title, String artist) async {
    _isLoadingAddSong = true;
    notifyListeners();
    try {
      // 呼叫雲端 Function
      final result = await FirebaseFunctions.instance.httpsCallable('searchSong').call({
        'title': title,
        'artist': artist,
      });
      
      // 💡 雲端成功回傳後，印出真實的教學影片連結！
      print('----------------------------------------');
      print('✅ 雲端 AI 成功找到教學影片！');
      print('🎵 歌曲: $title');
      print('🔗 真實教學連結: ${result.data['videoUrl']}');
      print('----------------------------------------');
      
    } catch (e) {
      print('⚠️ 雲端失敗，進入本地保險機制: $e');
      // ... (保留你原本 catch 裡面的保險機制程式碼即可)
    } finally {
      _isLoadingAddSong = false;
      notifyListeners();
    }
  }

  // 2. 修正按讚取消邏輯
  Future<void> setFeedItemAction(String feedItemId, String currentAction, String newAction) async {
    // 如果點擊的跟原本的一樣，就取消 (變回 ignored)
    final finalAction = (currentAction == newAction) ? 'ignored' : newAction;
    
    await FirebaseFirestore.instance
        .collection('users').doc(currentUserId)
        .collection('feed').doc(feedItemId)
        .update({'actionState': finalAction});
  }

  // 3. 增加更多 Inspiration 模擬資料 (且皆為可播放網址)
  Future<void> updateFeed() async {
    try {
      await FirebaseFunctions.instance.httpsCallable('updateFeed').call({});
    } catch (e) {
      print('⚠️ AI 報錯，生成多筆模擬 Feed...');
      final List<Map<String, dynamic>> mockFeed = [
        {
          'title': 'Wish You Were Here',
          'artist': 'Pink Floyd',
          'genre': 'Classic Rock',
          'videoUrl': 'https://www.youtube.com/watch?v=2K4tH19V28E',
          'description': 'AI 推薦：練習 12 弦吉他手感的經典曲目。',
          'actionState': 'ignored'
        },
        {
          'title': 'Wonderwall',
          'artist': 'Oasis',
          'genre': 'Britpop',
          'videoUrl': 'https://www.youtube.com/watch?v=FPD-9-T_Wos',
          'description': 'AI 推薦：最適合初學者的刷奏練習。',
          'actionState': 'ignored'
        },
        {
          'title': 'Blackbird',
          'artist': 'The Beatles',
          'genre': 'Folk',
          'videoUrl': 'https://www.youtube.com/watch?v=mYpXn-P8y_4',
          'description': 'AI 推薦：精進指彈技巧的必備練習曲。',
          'actionState': 'ignored'
        },
        {
          'title': 'Hotel California',
          'artist': 'Eagles',
          'genre': 'Classic Rock',
          'videoUrl': 'https://www.youtube.com/watch?v=itfL0Lp34L4',
          'description': 'AI 推薦：練習電吉他推弦與旋律感的經典。',
          'actionState': 'ignored'
        },
        {
          'title': 'Iris',
          'artist': 'Goo Goo Dolls',
          'genre': 'Alt Rock',
          'videoUrl': 'https://www.youtube.com/watch?v=NdYWuo9OqAM',
          'description': 'AI 推薦：獨特的調弦法，適合挑戰進階技巧。',
          'actionState': 'ignored'
        }
      ];

      for (var item in mockFeed) {
        await FirebaseFirestore.instance
            .collection('users').doc(currentUserId)
            .collection('feed').add(item);
      }
    }
  }
  // Library Page: 封存、最愛狀態切換
  Future<void> updateSongStatus(String songId, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('songLibrary')
        .doc(songId)
        .update(data);
  }
}