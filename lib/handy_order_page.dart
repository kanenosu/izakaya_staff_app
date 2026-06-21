import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'services/whisper_service.dart';

/// カート用モデル
class CartItem {
  final String name;
  final int price;
  int qty;
  CartItem({required this.name, required this.price, this.qty = 1});
}

/// ハンディ注文ページ
///
/// maki_menu の入力形式を踏襲：
///  - カテゴリ見出し付きのカードグリッド
///  - カードをタップでカートへ追加（ハプティックフィードバック付き）
///  - 画面下部のバーから注文確認モーダルを開き、数量を ± で調整
///  - まとめて Firestore（tables/{席ID}/orders）へ送信＝席ごとに保存
///  - 音声認識（Whisper）デモボタン
class HandyOrderPage extends StatefulWidget {
  final String tableId;
  const HandyOrderPage({Key? key, required this.tableId}) : super(key: key);

  @override
  State<HandyOrderPage> createState() => _HandyOrderPageState();
}

class _HandyOrderPageState extends State<HandyOrderPage> {
  final List<CartItem> _cart = [];
  String? _selectedCategory; // null = すべて表示
  bool _isSending = false;

  final WhisperService _whisper = WhisperService();
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _menuDocs = [];

  // 固定カテゴリ順
  static const _fixedCategories = [
    'ドリンク',
    '焼き物',
    '一品料理',
    'おつまみ',
    'サラダ',
    '鍋',
    'トッピング',
    '〆メニュー',
    'デザート',
    'その他',
  ];

  // ドリンク内サブカテゴリ順
  static const _drinkOrder = [
    'ビール',
    'サワー',
    'ハイボール',
    '日本酒',
    '焼酎',
    'ワイン',
    'ソフトドリンク',
    'その他',
  ];

  int get _totalCount => _cart.fold(0, (s, e) => s + e.qty);
  int get _totalPrice => _cart.fold(0, (s, e) => s + e.price * e.qty);

  @override
  void dispose() {
    _whisper.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.tableId,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('注文入力'),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('menu_items')
            .orderBy('category')
            .orderBy('order')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          _menuDocs = snapshot.data!.docs;

          // カテゴリでグルーピング
          final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
              grouped = {};
          for (var doc in _menuDocs) {
            final cat = doc.data()['category'] as String? ?? 'その他';
            grouped.putIfAbsent(cat, () => []).add(doc);
          }

          final categories =
              _fixedCategories.where(grouped.containsKey).toList()
                ..addAll(grouped.keys.where((c) => !_fixedCategories.contains(c)));

          final visibleCategories = _selectedCategory == null
              ? categories
              : categories.where((c) => c == _selectedCategory).toList();

          return Column(
            children: [
              _buildCategoryChips(categories),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                  children: [
                    for (final cat in visibleCategories)
                      _buildCategorySection(cat, grouped[cat]!),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===== カテゴリ選択チップ =====
  Widget _buildCategoryChips(List<String> categories) {
    final chips = <String?>[null, ...categories]; // null = すべて
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = chips[i];
          final selected = _selectedCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected ? AppColors.ink : AppColors.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.ink : AppColors.line,
                ),
              ),
              child: Text(
                cat ?? 'すべて',
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.inkSoft,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ===== カテゴリセクション =====
  Widget _buildCategorySection(
    String category,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(category),
        if (category == 'ドリンク')
          ..._buildDrinkSubSections(items)
        else
          _buildGrid(items),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDrinkSubSections(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> drinkItems,
  ) {
    final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
        subGrouped = {};
    for (var doc in drinkItems) {
      final sub = doc.data()['subCategory'] as String? ?? 'その他';
      subGrouped.putIfAbsent(sub, () => []).add(doc);
    }
    final sortedSubCats = [
      ..._drinkOrder.where(subGrouped.containsKey),
      ...subGrouped.keys.where((k) => !_drinkOrder.contains(k)),
    ];
    return [
      for (final sub in sortedSubCats) ...[
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8, left: 2),
          child: Text(
            sub,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.inkSoft,
            ),
          ),
        ),
        _buildGrid(subGrouped[sub]!),
      ],
    ];
  }

  Widget _buildGrid(List<QueryDocumentSnapshot<Map<String, dynamic>>> items) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        childAspectRatio: 3 / 2.05,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final data = items[index].data();
        final name = data['name'] as String? ?? '';
        final price = (data['price'] as num?)?.toInt() ?? 0;
        return _buildMenuCard(name, price);
      },
    );
  }

  // ===== メニューカード =====
  Widget _buildMenuCard(String name, int price) {
    final displayName = _extractBaseName(name);
    final inCart = _cart.firstWhere(
      (e) => e.name == displayName,
      orElse: () => CartItem(name: '', price: 0, qty: 0),
    );
    final count = inCart.name.isEmpty ? 0 : inCart.qty;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          _addToCart(displayName, price, 1);
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: count > 0 ? AppColors.accent : AppColors.line,
              width: count > 0 ? 1.6 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.ink,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      '¥$price',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                if (count > 0)
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===== 下部バー（音声＋注文確認） =====
  Widget _buildBottomBar() {
    final hasItems = _cart.isNotEmpty;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            // 音声認識（Whisper デモ）ボタン
            _MicButton(onTap: _startVoiceDemo),
            const SizedBox(width: 12),
            // 注文確認ボタン
            Expanded(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: hasItems ? 1 : 0.45,
                child: Material(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: hasItems ? _openCart : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 15,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$_totalCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            '注文を確認',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '¥${_totalPrice.toString()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== カートモーダル =====
  void _openCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            void refresh() {
              setModalState(() {});
              setState(() {});
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.82,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                    child: Row(
                      children: [
                        const Text(
                          '注文リスト',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'テーブル ${widget.tableId}',
                          style: const TextStyle(
                            color: AppColors.inkSoft,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 16),
                  Flexible(
                    child: _cart.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(40),
                            child: Text(
                              'カートは空です',
                              style: TextStyle(color: AppColors.inkSoft),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _cart.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx, i) =>
                                _cartRow(i, refresh),
                          ),
                  ),
                  const Divider(height: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Row(
                      children: [
                        const Text(
                          '合計',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '¥$_totalPrice',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        OutlinedButton(
                          onPressed: _cart.isEmpty
                              ? null
                              : () {
                                  setState(() => _cart.clear());
                                  Navigator.pop(ctx);
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.inkSoft,
                            side: const BorderSide(color: AppColors.line),
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('クリア'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (_cart.isEmpty || _isSending)
                                ? null
                                : () => _sendBatchOrders(ctx, refresh),
                            icon: _isSending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.2,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded, size: 18),
                            label: Text(_isSending ? '送信中...' : 'まとめて送信'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SafeArea(top: false, child: const SizedBox(height: 4)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _cartRow(int i, VoidCallback refresh) {
    final item = _cart[i];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '¥${item.price}',
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          _qtyButton(Icons.remove, () {
            if (item.qty <= 1) {
              _cart.removeAt(i);
            } else {
              item.qty--;
            }
            refresh();
          }),
          SizedBox(
            width: 34,
            child: Text(
              '${item.qty}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.ink,
              ),
            ),
          ),
          _qtyButton(Icons.add, () {
            item.qty++;
            refresh();
          }),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Text(
              '¥${item.price * item.qty}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.background,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.line),
        ),
        child: Icon(icon, size: 18, color: AppColors.ink),
      ),
    );
  }

  // ===== 音声認識デモ =====
  Future<void> _startVoiceDemo() async {
    if (_menuDocs.isEmpty) return;
    final candidates = _menuDocs
        .map((d) => _extractBaseName(d.data()['name'] as String? ?? ''))
        .where((n) => n.isNotEmpty)
        .toList();

    final recognized = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _VoiceDemoSheet(
        whisper: _whisper,
        candidates: candidates,
      ),
    );

    if (recognized == null || !mounted) return;

    // 認識結果に対応するメニューを検索
    final match = _menuDocs.firstWhere(
      (d) => _extractBaseName(d.data()['name'] as String? ?? '') == recognized,
      orElse: () => _menuDocs.first,
    );
    final price = (match.data()['price'] as num?)?.toInt() ?? 0;
    _addToCart(recognized, price, 1);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        content: Text('🎤 音声認識（デモ）：「$recognized」を追加しました'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ===== ユーティリティ =====
  void _addToCart(String name, int price, int qty) {
    setState(() {
      final idx = _cart.indexWhere((e) => e.name == name);
      if (idx >= 0) {
        _cart[idx].qty += qty;
      } else {
        _cart.add(CartItem(name: name, price: price, qty: qty));
      }
    });
  }

  String _extractBaseName(String name) {
    final idx = name.indexOf('(');
    return idx >= 0 ? name.substring(0, idx).trim() : name.trim();
  }

  Future<void> _sendBatchOrders(
    BuildContext sheetCtx,
    VoidCallback refreshModal,
  ) async {
    _isSending = true;
    refreshModal();
    try {
      final batch = FirebaseFirestore.instance.batch();
      final col = FirebaseFirestore.instance
          .collection('tables')
          .doc(widget.tableId)
          .collection('orders');
      for (var item in _cart) {
        final doc = col.doc();
        batch.set(doc, {
          'item': item.name,
          'price': item.price,
          'qty': item.qty,
          'status': '未提供',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      if (!mounted) return;
      setState(() {
        _cart.clear();
        _isSending = false;
      });
      Navigator.pop(sheetCtx);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.served,
          content: Text('注文を送信しました'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _isSending = false;
      refreshModal();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('送信に失敗しました: $e')),
      );
    }
  }
}

/// 下部バーのマイクボタン
class _MicButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MicButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      shape: const CircleBorder(side: BorderSide(color: AppColors.line)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 52,
          height: 52,
          child: Icon(Icons.mic_none_rounded, color: AppColors.ink, size: 26),
        ),
      ),
    );
  }
}

/// 音声認識デモ用のボトムシート
///
/// 「聞き取り中」→「認識中」→ 結果（候補からランダム）を返す。
class _VoiceDemoSheet extends StatefulWidget {
  final WhisperService whisper;
  final List<String> candidates;
  const _VoiceDemoSheet({required this.whisper, required this.candidates});

  @override
  State<_VoiceDemoSheet> createState() => _VoiceDemoSheetState();
}

enum _VoicePhase { listening, recognizing }

class _VoiceDemoSheetState extends State<_VoiceDemoSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  _VoicePhase _phase = _VoicePhase.listening;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _run();
  }

  Future<void> _run() async {
    await widget.whisper.startRecording();
    // 「聞き取り中」を演出
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    setState(() => _phase = _VoicePhase.recognizing);
    final result = await widget.whisper.stopAndTranscribe(widget.candidates);
    if (!mounted) return;
    Navigator.pop(context, result);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listening = _phase == _VoicePhase.listening;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),
          // パルスするマイク
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              final scale = listening ? 1 + _pulse.value * 0.25 : 1.0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  if (listening)
                    Container(
                      width: 110 * scale,
                      height: 110 * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent
                            .withValues(alpha: 0.12 * (1 - _pulse.value)),
                      ),
                    ),
                  child!,
                ],
              );
            },
            child: Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent,
              ),
              child: Icon(
                listening ? Icons.mic_rounded : Icons.graphic_eq_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            listening ? '聞き取り中…' : '認識中…',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Whisper 音声認識（デモ）',
            style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 4),
          const Text(
            '※ これはデモ表示です。実際の音声は処理されません。',
            style: TextStyle(fontSize: 11, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}
