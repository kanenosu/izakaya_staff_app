import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// カート用モデル
class CartItem {
  final String name;
  final int price;
  int qty;
  CartItem({required this.name, required this.price, this.qty = 1});
}

/// ハンディ注文ページ：固定カテゴリ順＋ドリンク内subカテゴリ順＋仮リスト＋一括送信
class HandyOrderPage extends StatefulWidget {
  final String tableId;
  const HandyOrderPage({Key? key, required this.tableId}) : super(key: key);

  @override
  _HandyOrderPageState createState() => _HandyOrderPageState();
}

class _HandyOrderPageState extends State<HandyOrderPage>
    with SingleTickerProviderStateMixin {
  List<CartItem> _cart = [];
  bool _isDragging = false;
  int _dragQty = 1;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(title: Text('テーブル${widget.tableId} 注文')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
        FirebaseFirestore.instance
            .collection('menu_items')
            .orderBy('category')
            .orderBy('order')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          // カテゴリでグルーピング
          final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
          grouped = {};
          for (var doc in docs) {
            final cat = doc.data()['category'] as String? ?? 'その他';
            grouped.putIfAbsent(cat, () => []).add(doc);
          }

          // 固定カテゴリ順を定義
          final fixedCategories = [
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
          // 存在しないカテゴリは除外
          final categories =
          fixedCategories.where((c) => grouped.containsKey(c)).toList();

          return DefaultTabController(
            length: categories.length,
            child: Column(
              children: [
                // カテゴリタブ
                Material(
                  color: Theme.of(context).primaryColor,
                  child: TabBar(
                    isScrollable: true,
                    tabs: categories.map((c) => Tab(text: c)).toList(),
                  ),
                ),
                // メニュー表示
                Expanded(
                  child: TabBarView(
                    children:
                    categories.map((cat) {
                      // ドリンク：subCategoryを固定順で表示
                      if (cat == 'ドリンク') {
                        final drinkItems = grouped['ドリンク']!;
                        // subCategoryでグルーピング
                        final Map<
                            String,
                            List<QueryDocumentSnapshot<Map<String, dynamic>>>
                        >
                        subGrouped = {};
                        for (var doc in drinkItems) {
                          final sub =
                              doc.data()['subCategory'] as String? ?? 'その他';
                          subGrouped.putIfAbsent(sub, () => []).add(doc);
                        }
                        // ドリンク内の表示順を定義
                        final drinkOrder = [
                          'ビール',
                          'サワー',
                          'ハイボール',
                          '日本酒',
                          '焼酎',
                          'ワイン',
                          'ソフトドリンク',
                          'その他',
                        ];
                        // 並べ替え
                        final sortedSubCats = [
                          ...drinkOrder.where(
                                (d) => subGrouped.containsKey(d),
                          ),
                          ...subGrouped.keys.where(
                                (k) => !drinkOrder.contains(k),
                          ),
                        ];

                        return ListView(
                          padding: const EdgeInsets.all(8),
                          children:
                          sortedSubCats.map((subCat) {
                            final items = subGrouped[subCat]!;
                            return Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    subCat,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                GridView.builder(
                                  physics:
                                  const NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.only(
                                    bottom: 12,
                                  ),
                                  gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 160,
                                    childAspectRatio: 3 / 2,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                                  itemCount: items.length,
                                  itemBuilder: (context, index) {
                                    final data = items[index].data();
                                    final name = data['name'] as String;
                                    final price = data['price'] as int;
                                    return _buildMenuCard(name, price);
                                  },
                                ),
                              ],
                            );
                          }).toList(),
                        );
                      }

                      // その他カテゴリは通常グリッド
                      final items = grouped[cat]!;
                      return GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 160,
                          childAspectRatio: 3 / 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final data = items[index].data();
                          final name = data['name'] as String;
                          final price = data['price'] as int;
                          return _buildMenuCard(name, price);
                        },
                      );
                    }).toList(),
                  ),
                ),
                // 仮リスト表示：List形式
                SizedBox(
                  height: screenHeight * 0.35,
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          color: Colors.grey[100],
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: _cart.length,
                            itemBuilder: (ctx, i) {
                              final item = _cart[i];
                              return ListTile(
                                title: Text(item.name),
                                subtitle: Text('¥${item.price} × ${item.qty}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed:
                                      () => setState(() => _cart.removeAt(i)),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: ElevatedButton(
                          onPressed: _cart.isEmpty ? null : _sendBatchOrders,
                          child: const Text('まとめて送信'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// メニューカード構築
  Widget _buildMenuCard(String name, int price) {
    return GestureDetector(
      onTap: () => _addToCart(name, price, 1),
      onLongPressStart: (_) {
        setState(() {
          _isDragging = true;
          _dragQty = 1;
        });
      },
      onHorizontalDragUpdate: (d) {
        if (!_isDragging) return;
        setState(() {
          _dragQty = (_dragQty + (d.delta.dx > 0 ? 1 : -1)).clamp(1, 99);
        });
      },
      onLongPressEnd: (_) {
        if (_isDragging) {
          _addToCart(name, price, _dragQty);
          setState(() => _isDragging = false);
        }
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('¥$price'),
              if (_isDragging)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '×$_dragQty',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _addToCart(String name, int price, int qty) {
    setState(() {
      final idx = _cart.indexWhere((e) => e.name == name);
      if (idx >= 0) {
        _cart[idx].qty += qty;
      } else {
        _cart.add(CartItem(name: name, price: price, qty: qty));
      }
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$name を $qty 個、仮リストに追加')));
  }

  /// 仮リスト一括送信
  Future<void> _sendBatchOrders() async {
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
    setState(() => _cart.clear());
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('全ての注文を送信しました')));
  }
}
