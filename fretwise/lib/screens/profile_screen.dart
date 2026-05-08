import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/section_header.dart';
import 'shop_screen.dart';

class ProfileScreen extends StatefulWidget {
  final AppTheme t;
  final void Function(String screen, {Map<String, dynamic>? props}) navigate;
  final int coins;
  final Set<String> ownedItems;

  const ProfileScreen({
    super.key,
    required this.t,
    required this.navigate,
    required this.coins,
    required this.ownedItems,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _showItemsPage = false;
  bool _showNameEdit = false;
  String _userName = 'Alex Johnson';
  final _nameCtrl = TextEditingController();

  AppTheme get t => widget.t;

  List<ShopItem> get _purchasedItems =>
      ShopItem.items.where((i) => widget.ownedItems.contains(i.id)).toList();

  static const _achievements = [
    ('🔥', '12-Day\nStreak'),
    ('🎸', 'First\nSong'),
    ('⭐', '1K\nXP'),
    ('🏆', '10\nSongs'),
    ('💎', 'Level\n7'),
  ];

  static const _diary = [
    (date: 'May 3, 2026', songs: ['Wonderwall – 22 min', 'Blackbird – 8 min'], note: 'Chord transitions feeling smoother today!', xp: '+85 XP'),
    (date: 'May 2, 2026', songs: ['Hotel California – 30 min'], note: 'Struggled with the solo part, need to slow down.', xp: '+95 XP'),
    (date: 'Apr 30, 2026', songs: ['Wish You Were Here – 20 min', "Knockin' On Heaven's Door – 15 min"], note: 'Great session! Both songs almost complete.', xp: '+110 XP'),
    (date: 'Apr 29, 2026', songs: ['Nothing Else Matters – 25 min'], note: 'Starting to get the fingerpicking pattern.', xp: '+80 XP'),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 80),
          child: Column(
            children: [
              // Avatar + name
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                child: Column(
                  children: [
                    Container(
                      width: 84, height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [t.accent, t.accentMid],
                        ),
                        boxShadow: [BoxShadow(color: t.accent.withValues(alpha: 0.3), blurRadius: 20)],
                      ),
                      child: const Center(
                        child: Text('A', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_userName,
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: t.text, fontFamily: 'Georgia')),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            _nameCtrl.text = _userName;
                            setState(() => _showNameEdit = true);
                          },
                          child: Icon(Icons.settings, size: 16, color: t.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('Guitar enthusiast · Level 7', style: TextStyle(fontSize: 13, color: t.textSec)),
                    const SizedBox(height: 16),

                    // Stat badges
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _StatBadge(icon: Icons.local_fire_department, value: '12', label: 'Streak', color: AppColors.red, t: t),
                        const SizedBox(width: 10),
                        _StatBadge(icon: Icons.access_time, value: '48h', label: 'Practice', color: AppColors.accent, t: t),
                        const SizedBox(width: 10),
                        _StatBadge(emoji: '⭐', value: '${widget.coins}', label: 'Stars', t: t),
                      ],
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Divider(color: t.border, height: 1),
              ),

              // Badges
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(label: 'Badges', t: t),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: _achievements.map((a) => Expanded(
                          child: Column(
                            children: [
                              Container(
                                width: 52, height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: t.surface,
                                  border: Border.all(color: t.border, width: 1.5),
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)],
                                ),
                                child: Center(child: Text(a.$1, style: const TextStyle(fontSize: 24))),
                              ),
                              const SizedBox(height: 6),
                              Text(a.$2,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: t.textSec, height: 1.3)),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Divider(color: t.border, height: 1),
              ),

              // My Items
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      label: 'My Items',
                      action: 'More',
                      onAction: () => setState(() => _showItemsPage = true),
                      t: t,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: t.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: t.border),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)],
                        ),
                        child: Column(
                          children: [
                            if (_purchasedItems.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Center(child: Text('No items yet — visit the Shop!', style: TextStyle(fontSize: 13, color: t.textMuted))),
                              )
                            else
                              for (int i = 0; i < _purchasedItems.length.clamp(0, 3); i++) ...[
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38, height: 38,
                                        decoration: BoxDecoration(color: t.accentSoft, borderRadius: BorderRadius.circular(11)),
                                        child: Center(child: Text(_purchasedItems[i].icon, style: const TextStyle(fontSize: 20))),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(_purchasedItems[i].name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.text)),
                                          Text(_purchasedItems[i].category, style: TextStyle(fontSize: 12, color: t.textSec)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (i < _purchasedItems.length.clamp(0, 3) - 1)
                                  Divider(color: t.borderLight, height: 1, indent: 14, endIndent: 14),
                              ],
                            Divider(color: t.borderLight, height: 1),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: GestureDetector(
                                onTap: () => widget.navigate('shop'),
                                child: Row(
                                  children: [
                                    Icon(Icons.storefront_outlined, size: 14, color: t.accent),
                                    const SizedBox(width: 6),
                                    Text('Go to Shop', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.accent)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Divider(color: t.border, height: 1),
              ),

              // Practice Diary
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(label: 'Practice Diary', t: t),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          for (final entry in _diary) ...[
                            Container(
                              decoration: BoxDecoration(
                                color: t.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: t.border),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)],
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(entry.date, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.text)),
                                      Text(entry.xp, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.green)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  for (final song in entry.songs) ...[
                                    Row(
                                      children: [
                                        Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: t.accent)),
                                        const SizedBox(width: 7),
                                        Text(song, style: TextStyle(fontSize: 13, color: t.textSec)),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                  ],
                                  Divider(color: t.borderLight, height: 10),
                                  Row(
                                    children: [
                                      Container(
                                        width: 22, height: 22,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF1A7A5E), Color(0xFF2EAD85)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                        child: const Icon(Icons.chat_bubble_outline, size: 11, color: Colors.white),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '"${entry.note}"',
                                          style: TextStyle(fontSize: 13, color: t.textSec, fontStyle: FontStyle.italic, height: 1.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // My Items subpage
        if (_showItemsPage)
          _ItemsPage(t: t, navigate: widget.navigate, items: _purchasedItems, onBack: () => setState(() => _showItemsPage = false)),

        // Name edit modal
        if (_showNameEdit)
          GestureDetector(
            onTap: () => setState(() => _showNameEdit = false),
            child: Container(
              color: Colors.black.withValues(alpha: 0.4),
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: t.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
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
                      Text('Change Name', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.text)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameCtrl,
                        autofocus: true,
                        style: TextStyle(fontSize: 15, color: t.text),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: t.surfaceAlt,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.border)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_nameCtrl.text.trim().isNotEmpty) {
                              setState(() { _userName = _nameCtrl.text.trim(); _showNameEdit = false; });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: t.accent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Save', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
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

class _StatBadge extends StatelessWidget {
  final IconData? icon;
  final String? emoji;
  final String value;
  final String label;
  final Color? color;
  final AppTheme t;

  const _StatBadge({this.icon, this.emoji, required this.value, required this.label, required this.t, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: t.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          if (emoji != null)
            Text(emoji!, style: const TextStyle(fontSize: 13))
          else if (icon != null)
            Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.text)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: t.textSec)),
        ],
      ),
    );
  }
}

class _ItemsPage extends StatelessWidget {
  final AppTheme t;
  final void Function(String screen, {Map<String, dynamic>? props}) navigate;
  final List<ShopItem> items;
  final VoidCallback onBack;

  const _ItemsPage({required this.t, required this.navigate, required this.items, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: t.bg,
      child: Column(
        children: [
          Container(
            color: t.surface,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onBack,
                  child: Icon(Icons.arrow_back, size: 22, color: t.text),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('My Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.text))),
                GestureDetector(
                  onTap: () => navigate('shop'),
                  child: Container(
                    decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    child: const Text('Shop', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Items & power-ups purchased from the shop.', style: TextStyle(fontSize: 13, color: t.textSec)),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    Center(child: Text('No items yet — visit the Shop!', style: TextStyle(fontSize: 14, color: t.textMuted)))
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: t.border),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < items.length; i++) ...[
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46, height: 46,
                                    decoration: BoxDecoration(color: t.accentSoft, borderRadius: BorderRadius.circular(13)),
                                    child: Center(child: Text(items[i].icon, style: const TextStyle(fontSize: 22))),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(items[i].name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.text)),
                                        const SizedBox(height: 2),
                                        Text(items[i].desc, style: TextStyle(fontSize: 12, color: t.textSec)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.094), borderRadius: BorderRadius.circular(6)),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    child: const Text('OWNED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.green)),
                                  ),
                                ],
                              ),
                            ),
                            if (i < items.length - 1) Divider(color: t.borderLight, height: 1),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
