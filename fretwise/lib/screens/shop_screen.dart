import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/section_header.dart';

class ShopItem {
  final String id;
  final String category;
  final String name;
  final String desc;
  final int price;
  final String icon;
  final Color color;

  const ShopItem({
    required this.id,
    required this.category,
    required this.name,
    required this.desc,
    required this.price,
    required this.icon,
    required this.color,
  });

  static const items = [
    ShopItem(id: 'streak_freeze', category: 'Power-ups', name: 'Streak Freeze', desc: 'Protect your streak for 1 missed day', price: 100, icon: '❄️', color: AppColors.blue),
    ShopItem(id: 'xp_booster', category: 'Power-ups', name: 'XP Booster', desc: 'Earn 2× XP for the next 3 sessions', price: 150, icon: '⚡️', color: AppColors.gold),
    ShopItem(id: 'streak_shield_1', category: 'Power-ups', name: 'Streak Shield', desc: 'Protect your streak for a full week', price: 300, icon: '🛡️', color: Color(0xFF6B5CE7)),
    ShopItem(id: 'star_multiplier', category: 'Boosters', name: 'Star Multiplier', desc: 'Earn 3× stars on your next practice', price: 200, icon: '⭐', color: AppColors.gold),
    ShopItem(id: 'focus_mode', category: 'Boosters', name: 'Focus Mode', desc: 'Unlock distraction-free practice UI', price: 250, icon: '🎯', color: AppColors.green),
    ShopItem(id: 'chord_master', category: 'Unlockables', name: 'Chord Master Pack', desc: 'Unlock 50 advanced chord charts', price: 500, icon: '🎸', color: AppColors.accent),
    ShopItem(id: 'backing_tracks', category: 'Unlockables', name: 'Backing Tracks', desc: '10 professional backing tracks', price: 400, icon: '🎵', color: Color(0xFFA066D0)),
  ];
}

class ShopScreen extends StatefulWidget {
  final AppTheme t;
  final void Function(String screen, {Map<String, dynamic>? props}) navigate;
  final int coins;
  final Set<String> ownedItems;
  final void Function(String id) onBuy;

  const ShopScreen({
    super.key,
    required this.t,
    required this.navigate,
    required this.coins,
    required this.ownedItems,
    required this.onBuy,
  });

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String? _toast;

  AppTheme get t => widget.t;

  void _buy(ShopItem item) {
    if (widget.ownedItems.contains(item.id)) return;
    if (widget.coins < item.price) {
      _showToast('Not enough coins!');
      return;
    }
    widget.onBuy(item.id);
    _showToast('${item.name} added!');
  }

  void _showToast(String msg) {
    setState(() => _toast = msg);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['Power-ups', 'Boosters', 'Unlockables'];

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Shop',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: t.text, fontFamily: 'Georgia')),
                        const SizedBox(height: 4),
                        Text('Power-ups & extras', style: TextStyle(fontSize: 14, color: t.textSec)),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('⭐', style: TextStyle(fontSize: 15)),
                        const SizedBox(width: 5),
                        Text('${widget.coins}',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: t.text)),
                      ],
                    ),
                  ],
                ),
              ),

              // Earn coins banner
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: t.accentSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.accent.withValues(alpha: 0.25)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.bolt, size: 18, color: t.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Earn coins by practicing',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.text)),
                            Text('Up to 150 coins per day',
                                style: TextStyle(fontSize: 12, color: t.textSec)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => widget.navigate('practicing', props: {'title': 'Wonderwall', 'artist': 'Oasis', 'bpm': 87}),
                        child: Container(
                          decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          child: const Text('Practice',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Item categories
              for (final cat in categories) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(label: cat, t: t),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            for (final item in ShopItem.items.where((i) => i.category == cat)) ...[
                              _ShopItemCard(item: item, t: t, isOwned: widget.ownedItems.contains(item.id), coins: widget.coins, onBuy: () => _buy(item)),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Toast
        if (_toast != null)
          Positioned(
            top: 70,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: t.text,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20)],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                child: Text(_toast!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.bg)),
              ),
            ),
          ),
      ],
    );
  }
}

class _ShopItemCard extends StatelessWidget {
  final ShopItem item;
  final AppTheme t;
  final bool isOwned;
  final int coins;
  final VoidCallback onBuy;

  const _ShopItemCard({
    required this.item,
    required this.t,
    required this.isOwned,
    required this.coins,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final canAfford = coins >= item.price;

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isOwned ? item.color.withValues(alpha: 0.3) : t.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: isOwned ? t.surfaceAlt : item.color.withValues(alpha: 0.094),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Text(item.icon, style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(item.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.text)),
                    if (isOwned) ...[
                      const SizedBox(width: 7),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.094),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        child: const Text('OWNED',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.green)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(item.desc, style: TextStyle(fontSize: 12, color: t.textSec)),
              ],
            ),
          ),
          GestureDetector(
            onTap: isOwned ? null : onBuy,
            child: Container(
              decoration: BoxDecoration(
                color: isOwned ? t.surfaceAlt : canAfford ? item.color : t.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: isOwned
                  ? Icon(Icons.check, size: 14, color: t.textMuted)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, size: 12, color: canAfford ? Colors.white : t.textMuted),
                        const SizedBox(width: 4),
                        Text('${item.price}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: canAfford ? Colors.white : t.textMuted,
                            )),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
