import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';
import 'song.dart';

class DiaryEntry {
  final DateTime date;
  final String title;
  final String artist;
  final int duration; // seconds
  final String userNote;

  DiaryEntry({
    required this.date,
    required this.title,
    required this.artist,
    required this.duration,
    this.userNote = '',
  });
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
      _diaryEntries[0] = DiaryEntry(
        date: e.date,
        title: e.title,
        artist: e.artist,
        duration: e.duration,
        userNote: note,
      );
      notifyListeners();
    }
  }

  //ccc
  String? _highlightedSongId;
  String? get highlightedSongId => _highlightedSongId;

  void setHighlightedSong(String? id) {
    _highlightedSongId = id;
    notifyListeners();
  }

  Future<String?> findExistingSongId(String title, String artist) async {
    final uid = currentUserId;
    final query = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('songLibrary')
        .where('title', isEqualTo: title)
        .where('artist', isEqualTo: artist)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.id;
    }
    return null;
  }

  String get currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'test_user_123';

  // 監聽 Library 歌單
  Stream<List<SongEntry>> get libraryStream {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('songLibrary')
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => SongEntry.fromFirestore(d)).toList(),
        );
  }

  // 監聽 Inspiration Feed 短影音
  Stream<List<FeedItem>> get feedStream {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('feed')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => FeedItem.fromFirestore(d)).toList(),
        );
  }

  // Library Page: 呼叫 AI 搜尋歌曲資訊
  // ... 前面的 import 不變

  // Library Page: 呼叫 AI 搜尋歌曲資訊
  // ... 其他部分不變

  // Library Page: 呼叫 AI 搜尋歌曲資訊
  Future<SongEntry?> searchSongToLibrary(String title, String artist) async {
    _isLoadingAddSong = true;
    notifyListeners();

    final existingId = await findExistingSongId(title, artist);
    if (existingId != null) {
      print('ℹ️ 歌曲已存在，準備進入練習頁面');
      _isLoadingAddSong = false;
      notifyListeners();

      // 💡 取得已存在的歌曲資料回傳
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('songLibrary')
          .doc(existingId)
          .get();
      return SongEntry.fromFirestore(doc);
    }

    try {
      // 呼叫雲端 Function
      final result = await FirebaseFunctions.instance
          .httpsCallable('searchSong')
          .call({'title': title, 'artist': artist});

      if (result.data['songId'] != null) {
        final newId = result.data['songId'];
        // 💡 取得剛新增成功的歌曲資料回傳
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('songLibrary')
            .doc(newId)
            .get();

        return SongEntry.fromFirestore(doc);
      }
    } catch (e) {
      print('⚠️ 雲端失敗，進入本地保險機制: $e');
      // ... (保留你原本 catch 裡面的保險機制程式碼即可)
    } finally {
      _isLoadingAddSong = false;
      notifyListeners();
    }
    return null;
  }

  // 2. 修正按讚取消邏輯
  Future<void> setFeedItemAction(
    String feedItemId,
    String currentAction,
    String newAction,
  ) async {
    // 如果點擊的跟原本的一樣，就取消 (變回 ignored)
    final finalAction = (currentAction == newAction) ? 'ignored' : newAction;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('feed')
        .doc(feedItemId)
        .update({'actionState': finalAction});
  }

  // 💡 新增一把鎖：用來防止使用者狂滑導致重複呼叫
  bool _isGeneratingFeed = false;
  bool get isGeneratingFeed => _isGeneratingFeed;

  // Inspiration Page: 呼叫雲端 AI 生成全新推薦
  Future<void> updateFeed() async {
    // 💡 防呆機制：如果 AI 已經在努力想歌了，就直接擋掉後續的呼叫！
    if (_isGeneratingFeed) {
      return;
    }

    _isGeneratingFeed = true;
    notifyListeners();

    try {
      print('⏳ 正在呼叫雲端 Gemini AI 生成推薦清單...');
      await FirebaseFunctions.instance.httpsCallable('updateFeed').call({});
      print('✅ 雲端 AI 成功生成推薦 Feed！');
    } catch (e) {
      print('⚠️ 雲端生成 Feed 失敗: $e');
    } finally {
      // 💡 任務完成，把鎖解開
      _isGeneratingFeed = false;
      notifyListeners();
    }
  }

  // --- Library Page: 封存、最愛狀態切換 ---
  Future<void> updateSongStatus(
    String songId,
    Map<String, dynamic> data,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('songLibrary')
          .doc(songId)
          .update(data);
    } catch (e) {
      debugPrint('更新歌曲狀態失敗: $e');
    }
  }

  void setCoins(int value) {
    _coins = value;
    notifyListeners();
  }

  bool ownsItem(String id) => _ownedItems.contains(id);
}

class AiMaterialService extends ChangeNotifier {
  Map<String, dynamic>? _currentMaterial;
  bool _isGenerating = false;

  // 供 UI 讀取目前的教材與生成狀態
  Map<String, dynamic>? get currentMaterial => _currentMaterial;
  bool get isGenerating => _isGenerating;

  Future<void> generateMaterial({
    required String songId,
    required String song,
    required String artist,
    String? preference,
  }) async {
    if (_isGenerating) return;

    _isGenerating = true;
    notifyListeners();

    debugPrint(
      '➔ [AI Service] Loading practice material for $song ($artist)...',
    );

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'test_user_123';
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('songLibrary')
          .doc(songId)
          .collection('practiceMaterials')
          .where('active', isEqualTo: true)
          .where('type', isEqualTo: 'video')
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        _currentMaterial = {
          'type': 'video',
          'title': data['title'] ?? '$song — Tutorial',
          'url': data['videoUrl'] ?? '',
        };
        debugPrint('➔ [AI Service] Loaded video: ${_currentMaterial!['url']}');
      } else {
        _currentMaterial = null;
        debugPrint(
          '➔ [AI Service] No practice material found for songId=$songId',
        );
      }
    } catch (e) {
      debugPrint('➔ [AI Service] Error loading material: $e');
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// 重置教材（例如換別首歌時）
  void reset() {
    _currentMaterial = null;
    _isGenerating = false;
    notifyListeners();
  }
}
