import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/song.dart';
import '../widgets/album_art.dart';
import '../widgets/progress_bar.dart';

class LibraryScreen extends StatefulWidget {
  final AppTheme t;
  final void Function(String screen, {Map<String, dynamic>? props}) navigate;
  final List<Song> extraSongs;
  final Set<String> removedLibrarySongs;
  final void Function(Song) onAddSong;

  const LibraryScreen({
    super.key,
    required this.t,
    required this.navigate,
    required this.extraSongs,
    required this.removedLibrarySongs,
    required this.onAddSong,
  });

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  Set<int> _favorites = {0, 2};
  bool _filterFavs = false;
  bool _filterArchived = false;
  String _sortBy = 'date';
  bool _sortAsc = false;
  bool _showSort = false;
  bool _showAddModal = false;
  String? _addError;
  final Set<String> _archived = {};
  final _titleCtrl = TextEditingController();
  final _artistCtrl = TextEditingController();
  String _searchQuery = '';
  final Map<String, GlobalKey> _cardKeys = {};
  String? _highlightedSong;

  AppTheme get t => widget.t;

  List<Song> get _allSongs {
    final base = Song.library.where((s) => !widget.removedLibrarySongs.contains(s.title));
    final all = [...base, ...widget.extraSongs];
    return all.where((s) => !_archived.contains(s.title)).toList();
  }

  List<Song> get _visibleSongs {
    final effectiveBase = Song.library.where((s) => !widget.removedLibrarySongs.contains(s.title));
    List<Song> all;
    if (_filterArchived) {
      all = [...effectiveBase, ...widget.extraSongs].where((s) => _archived.contains(s.title)).toList();
    } else {
      all = [...effectiveBase, ...widget.extraSongs].where((s) => !_archived.contains(s.title)).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      all = all.where((s) => s.title.toLowerCase().contains(q) || s.artist.toLowerCase().contains(q)).toList();
    }

    if (_filterFavs && !_filterArchived) {
      all = all.where((s) {
        final idx = Song.library.indexOf(s);
        return idx >= 0 && _favorites.contains(idx);
      }).toList();
    }

    all.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'date': cmp = a.lastPracticed.compareTo(b.lastPracticed); break;
        case 'progress': cmp = a.progress.compareTo(b.progress); break;
        case 'title': cmp = a.title.compareTo(b.title); break;
        case 'artist': cmp = a.artist.compareTo(b.artist); break;
        default: cmp = 0;
      }
      return _sortAsc ? cmp : -cmp;
    });
    return all;
  }

  void _scrollToSong(String title) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _cardKeys[title];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.1,
        ).then((_) {
          if (!mounted) return;
          setState(() => _highlightedSong = title);
          Future.delayed(const Duration(milliseconds: 1400), () {
            if (mounted) setState(() => _highlightedSong = null);
          });
        });
      }
    });
  }

  void _addSong() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    final effectiveBase = Song.library.where((s) => !widget.removedLibrarySongs.contains(s.title));
    final all = [...effectiveBase, ...widget.extraSongs];
    final duplicate = all.where((s) => s.title.toLowerCase() == title.toLowerCase()).firstOrNull;
    if (duplicate != null) {
      setState(() {
        _titleCtrl.clear();
        _artistCtrl.clear();
        _addError = null;
        _showAddModal = false;
      });
      _scrollToSong(duplicate.title);
      return;
    }
    final rng = Random();
    final mins = 2 + rng.nextInt(5);
    final secs = rng.nextInt(60);
    final duration = '$mins:${secs.toString().padLeft(2, '0')}';
    final progress = 5 + rng.nextInt(91);
    widget.onAddSong(Song(
      title: title,
      artist: _artistCtrl.text.trim().isEmpty ? 'Unknown Artist' : _artistCtrl.text.trim(),
      seed: Song.library.length + widget.extraSongs.length,
      duration: duration,
      progress: progress,
    ));
    setState(() {
      _titleCtrl.clear();
      _artistCtrl.clear();
      _addError = null;
      _showAddModal = false;
    });
    _scrollToSong(title);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    super.dispose();
  }

  String _sortDirectionLabel(String key) {
    switch (key) {
      case 'date': return _sortAsc ? 'Oldest first' : 'Newest first';
      case 'progress': return _sortAsc ? 'Least → Most' : 'Most → Least';
      case 'title':
      case 'artist': return _sortAsc ? 'A → Z' : 'Z → A';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final songs = _visibleSongs;

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 80),
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Library',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: t.text,
                              fontFamily: 'Georgia',
                            )),
                        const SizedBox(height: 4),
                        Text('${_allSongs.length} songs',
                            style: TextStyle(fontSize: 14, color: t.textSec)),
                      ],
                    ),
                  ),

                  // Search
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: Container(
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: t.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      child: Row(
                        children: [
                          Icon(Icons.search, size: 16, color: t.textMuted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              onChanged: (v) => setState(() => _searchQuery = v),
                              style: TextStyle(fontSize: 14, color: t.text),
                              decoration: InputDecoration(
                                hintText: 'Search songs, artists…',
                                hintStyle: TextStyle(color: t.textMuted),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Filters
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'Favorites',
                          icon: Icons.favorite,
                          active: _filterFavs,
                          t: t,
                          onTap: () => setState(() { _filterFavs = !_filterFavs; _filterArchived = false; }),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Archived',
                          icon: Icons.archive_outlined,
                          active: _filterArchived,
                          t: t,
                          activeColor: t.textMuted,
                          onTap: () => setState(() { _filterArchived = !_filterArchived; _filterFavs = false; }),
                        ),
                        if (!_filterArchived) ...[
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Sort',
                            icon: Icons.sort,
                            active: _showSort,
                            t: t,
                            onTap: () => setState(() => _showSort = !_showSort),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Sort menu
                  if (_showSort)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: t.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: t.border),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 30)],
                        ),
                        child: Column(
                          children: [
                            for (final opt in [
                              ('date', 'Date Practiced'),
                              ('progress', 'Progress'),
                              ('title', 'Title'),
                              ('artist', 'Artist'),
                            ])
                              GestureDetector(
                                onTap: () => setState(() {
                                  if (_sortBy == opt.$1) {
                                    _sortAsc = !_sortAsc;
                                  } else {
                                    _sortBy = opt.$1;
                                    _sortAsc = opt.$1 == 'title' || opt.$1 == 'artist';
                                  }
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                                  decoration: BoxDecoration(
                                    color: _sortBy == opt.$1 ? t.accentSoft : Colors.transparent,
                                    border: Border(bottom: BorderSide(color: t.borderLight)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(opt.$2,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: _sortBy == opt.$1 ? t.accent : t.text,
                                                  fontWeight: _sortBy == opt.$1 ? FontWeight.w700 : FontWeight.w400,
                                                )),
                                            if (_sortBy == opt.$1)
                                              Text(
                                                _sortDirectionLabel(opt.$1),
                                                style: TextStyle(fontSize: 11, color: t.accent),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (_sortBy == opt.$1)
                                        Icon(
                                          _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                                          size: 16,
                                          color: t.accent,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                  // Song list
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        if (songs.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text(
                                _filterArchived ? 'No archived songs.' : 'No songs yet — add one!',
                                style: TextStyle(fontSize: 14, color: t.textMuted),
                              ),
                            ),
                          ),
                        for (final s in songs) ...[
                          _SongCard(
                            key: _cardKeys.putIfAbsent(s.title, () => GlobalKey()),
                            song: s,
                            t: t,
                            isFav: Song.library.contains(s) && _favorites.contains(Song.library.indexOf(s)),
                            isArchived: _filterArchived,
                            isHighlighted: _highlightedSong == s.title,
                            onTap: () => widget.navigate('practicing', props: {
                              'title': s.title,
                              'artist': s.artist,
                              'bpm': s.bpm,
                            }),
                            onFavToggle: Song.library.contains(s)
                                ? () {
                                    final idx = Song.library.indexOf(s);
                                    setState(() {
                                      if (_favorites.contains(idx)) {
                                        _favorites = Set.from(_favorites)..remove(idx);
                                      } else {
                                        _favorites = {..._favorites, idx};
                                      }
                                    });
                                  }
                                : null,
                            onArchive: !_filterArchived
                                ? () => setState(() => _archived.add(s.title))
                                : null,
                            onUnarchive: _filterArchived
                                ? () => setState(() => _archived.remove(s.title))
                                : null,
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),

                  if (!_filterArchived)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text(
                          '← swipe left to archive',
                          style: TextStyle(fontSize: 11, color: t.textMuted),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),

        // Add Song FAB
        if (!_filterArchived)
          Positioned(
            bottom: 20,
            left: 20,
            child: GestureDetector(
              onTap: () => setState(() => _showAddModal = true),
              child: Container(
                decoration: BoxDecoration(
                  color: t.accent,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 8)],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.add, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Add Song', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),

        // Add Song Modal
        if (_showAddModal)
          GestureDetector(
            onTap: () => setState(() { _showAddModal = false; _addError = null; }),
            child: Container(
              color: Colors.black.withValues(alpha: 0.4),
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36, height: 4,
                          decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Add song to library',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.text)),
                      const SizedBox(height: 18),
                      _ModalField(
                        label: 'SONG TITLE',
                        hint: 'e.g. Stairway to Heaven',
                        controller: _titleCtrl,
                        t: t,
                        onChanged: (_) { if (_addError != null) setState(() => _addError = null); },
                      ),
                      if (_addError != null) ...[
                        const SizedBox(height: 6),
                        Text(_addError!, style: TextStyle(fontSize: 12, color: AppColors.red)),
                      ],
                      const SizedBox(height: 12),
                      _ModalField(
                        label: 'ARTIST',
                        hint: 'e.g. Led Zeppelin',
                        controller: _artistCtrl,
                        t: t,
                        onSubmit: _addSong,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _addSong,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: t.accent,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Add to Library',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final AppTheme t;
  final Color? activeColor;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.t,
    required this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? t.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: active ? color : t.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? color : t.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: active ? Colors.white : t.textSec),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : t.textSec,
                )),
          ],
        ),
      ),
    );
  }
}

class _SongCard extends StatefulWidget {
  final Song song;
  final AppTheme t;
  final bool isFav;
  final bool isArchived;
  final bool isHighlighted;
  final VoidCallback onTap;
  final VoidCallback? onFavToggle;
  final VoidCallback? onArchive;
  final VoidCallback? onUnarchive;

  const _SongCard({
    super.key,
    required this.song,
    required this.t,
    required this.isFav,
    required this.isArchived,
    required this.onTap,
    this.isHighlighted = false,
    this.onFavToggle,
    this.onArchive,
    this.onUnarchive,
  });

  @override
  State<_SongCard> createState() => _SongCardState();
}

class _SongCardState extends State<_SongCard> with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;
  double _offset = 0;
  double? _startX;
  bool _revealed = false;
  bool _pointerMoved = false;

  AppTheme get t => widget.t;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _glowAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 35),
    ]).animate(_glowCtrl);
  }

  @override
  void didUpdateWidget(_SongCard old) {
    super.didUpdateWidget(old);
    if (widget.isHighlighted && !old.isHighlighted) {
      _glowCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.song.progress > 0 ? 120 : 80,
      child: Stack(
        children: [
          // Archive action behind
          if (widget.onArchive != null)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 72,
              child: GestureDetector(
                onTap: widget.onArchive,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.archive_outlined, size: 20, color: Colors.white),
                      SizedBox(height: 3),
                      Text('Archive', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),

          // Card
          AnimatedContainer(
            duration: _startX != null ? Duration.zero : const Duration(milliseconds: 200),
            transform: Matrix4.translationValues(_offset, 0, 0),
            child: Listener(
              onPointerDown: (_) => _pointerMoved = false,
              onPointerMove: (e) { if (e.delta.dy.abs() > 2) _pointerMoved = true; },
              child: GestureDetector(
              onHorizontalDragStart: (d) => setState(() => _startX = d.globalPosition.dx),
              onHorizontalDragUpdate: (d) {
                if (_startX == null) return;
                final dx = d.globalPosition.dx - _startX!;
                if (dx < 0) setState(() => _offset = dx.clamp(-80, 0));
              },
              onHorizontalDragEnd: (_) {
                setState(() {
                  if (_offset < -40) {
                    _offset = -72;
                    _revealed = true;
                  } else {
                    _offset = 0;
                    _revealed = false;
                  }
                  _startX = null;
                });
              },
              onTap: () {
                if (_pointerMoved) return;
                if (_revealed) {
                  setState(() { _offset = 0; _revealed = false; });
                } else {
                  widget.onTap();
                }
              },
              child: AnimatedBuilder(
                animation: _glowAnim,
                builder: (context, child) => Container(
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Color.lerp(t.border, t.accent, _glowAnim.value)!,
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4),
                    BoxShadow(
                      color: t.accent.withValues(alpha: 0.45 * _glowAnim.value),
                      blurRadius: 18 * _glowAnim.value,
                      spreadRadius: 2 * _glowAnim.value,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        AlbumArt(seed: widget.song.seed, size: 46, radius: 13),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.song.title,
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.text),
                                  overflow: TextOverflow.ellipsis),
                              Text(
                                '${widget.song.artist} · ${widget.song.duration}',
                                style: TextStyle(fontSize: 12, color: t.textSec),
                              ),
                            ],
                          ),
                        ),
                        if (widget.isArchived && widget.onUnarchive != null)
                          GestureDetector(
                            onTap: widget.onUnarchive,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: t.border),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              child: Text('Restore',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: t.textSec)),
                            ),
                          )
                        else if (widget.onFavToggle != null)
                          GestureDetector(
                            onTap: widget.onFavToggle,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                widget.isFav ? Icons.favorite : Icons.favorite_border,
                                size: 18,
                                color: widget.isFav ? AppColors.red : t.textMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (widget.song.progress > 0) ...[
                      const SizedBox(height: 12),
                      ProgressBar(progress: widget.song.progress / 100, t: t, height: 4),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.song.progress == 100 ? 'Completed' : 'In progress',
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.song.progress == 100 ? AppColors.green : t.textMuted,
                            ),
                          ),
                          Text('${widget.song.progress}%',
                              style: TextStyle(fontSize: 11, color: t.textMuted)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          ),
        ),
        ],
      ),
    );
  }
}

class _ModalField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final AppTheme t;
  final VoidCallback? onSubmit;
  final ValueChanged<String>? onChanged;

  const _ModalField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.t,
    this.onSubmit,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: t.textMuted,
              letterSpacing: 0.07 * 12,
            )),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: TextStyle(fontSize: 15, color: t.text),
          onSubmitted: (_) => onSubmit?.call(),
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: t.textMuted),
            filled: true,
            fillColor: t.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.accent),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
