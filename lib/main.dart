import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Firebase 初期化用
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore 操作用
import 'handy_order_page.dart'; // ダブルタップで飛ぶハンディ注文画面
import 'payment_history_page.dart'; // 会計履歴画面
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

// アプリのエントリポイント
void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Flutter と Firebase の連携準備
  await Firebase.initializeApp(); // Firebase 初期化
  runApp(MyApp()); // アプリ起動
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '居酒屋スタッフアプリ',
      theme: ThemeData(primarySwatch: Colors.red),
      initialRoute: '/',
      routes: {
        '/': (context) => OrderManagementPage(),
        '/history': (context) => PaymentHistoryPage(),
      },
    );
  }
}

// 注文管理ページ：テーブル一覧をグリッド表示
class OrderManagementPage extends StatelessWidget {
  final List<String> tableIds = const [
    'F1',
    'F2',
    'F3',
    'F4',
    'F5',
    'F6',
    'T1',
    'T3',
    'K1',
    'K3',
    'K7',
    '外1',
    '外2',
    '外3',
    '黒',
    '宝',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('注文管理'),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            tooltip: '会計履歴',
            onPressed: () => Navigator.pushNamed(context, '/history'),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: '予約',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: '注文'),
          BottomNavigationBarItem(icon: Icon(Icons.store), label: '在庫'),
        ],
        currentIndex: 1,
      ),
      body: MasonryGridView.count(
        crossAxisCount: 3, // 横3列
        mainAxisSpacing: 8, // 行間
        crossAxisSpacing: 8, // 列間
        padding: const EdgeInsets.only(top: 16, bottom: 80),
        itemCount: tableIds.length,
        itemBuilder:
            (context, index) => TableOrdersWidget(tableId: tableIds[index]),
      ),
    );
  }
}

// 各テーブルの注文ステータスを表示するカード
class TableOrdersWidget extends StatefulWidget {
  final String tableId;
  const TableOrdersWidget({required this.tableId, Key? key}) : super(key: key);

  @override
  State<TableOrdersWidget> createState() => _TableOrdersWidgetState();
}

class _TableOrdersWidgetState extends State<TableOrdersWidget> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('tables')
              .doc(widget.tableId)
              .collection('orders')
              .orderBy('timestamp')
              .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return SizedBox();
        final docs = snap.data!.docs;

        // サーブ済みと未提供をアイテムごとにカウント
        final Map<String, int> servedCount = {};
        final Map<String, int> pendingCount = {};
        for (var d in docs) {
          final data = d.data();
          final name = data['item'] as String;
          final q = data['qty'] as int? ?? 1;
          if (data['status'] == '未提供') {
            pendingCount[name] = (pendingCount[name] ?? 0) + q;
          } else {
            servedCount[name] = (servedCount[name] ?? 0) + q;
          }
        }

        // 最後の注文からの経過時間（分）
        final lastTs =
            docs.isNotEmpty ? docs.last.data()['timestamp'].toDate() : null;
        final durationStr =
            lastTs != null
                ? '${DateTime.now().difference(lastTs).inMinutes}分前'
                : '--';

        return GestureDetector(
          onTap: () => _showDetailOverlay(context),
          onDoubleTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => HandyOrderPage(tableId: widget.tableId),
              ),
            );
          },
          child: Card(
            margin: const EdgeInsets.all(6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: 120),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.tableId,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(durationStr, style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 飲み放題＆コースは常に表示
                    ...docs
                        .map((d) => d.data()['item'] as String)
                        .where(
                          (name) =>
                              name.contains('飲み放題') || name.contains('コース'),
                        )
                        .toSet()
                        .map(
                          (name) => Text(
                            name,
                            style: TextStyle(fontSize: 14, color: Colors.blue),
                          ),
                        ),
                    // 未提供のリスト
                    ...pendingCount.entries.map(
                      (e) => Text(
                        '${e.key}×${e.value}',
                        style: TextStyle(fontSize: 14, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 詳細ダイアログ：全注文リストと会計ボタン
  void _showDetailOverlay(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('テーブル${widget.tableId} 詳細'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream:
                    FirebaseFirestore.instance
                        .collection('tables')
                        .doc(widget.tableId)
                        .collection('orders')
                        .orderBy('timestamp')
                        .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data!.docs;

                  // → qty も乗じて小計を計算
                  final subtotal = docs.fold<int>(0, (sum, d) {
                    final data = d.data();
                    final price = data['price'] as int? ?? 0;
                    final qty = data['qty'] as int? ?? 1;
                    return sum + price * qty;
                  });
                  final taxedTotal = (subtotal * 1.1).round();

                  return Column(
                    children: [
                      Expanded(
                        child: ListView(
                          children:
                              docs.map((d) {
                                final data = d.data();
                                final item = data['item'] as String;
                                final price = data['price'] as int? ?? 0;
                                final qty = data['qty'] as int? ?? 1;
                                final ts =
                                    (data['timestamp'] as Timestamp).toDate();
                                final timeStr =
                                    '${ts.hour}:${ts.minute.toString().padLeft(2, '0')}';
                                final isServed = data['status'] == '提供済み';

                                return ListTile(
                                  // 左側にチェックボックス＋数量を並べる
                                  leading: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: isServed,
                                        onChanged: (checked) {
                                          d.reference.update({
                                            'status': checked! ? '提供済み' : '未提供',
                                          });
                                        },
                                      ),
                                      Text(
                                        '×$qty',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  title: Text(item), // 商品名
                                  subtitle: Text('¥$price ・ $timeStr'), // 価格＋時間
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                      const Divider(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '小計 ¥$subtotal （税込 ¥$taxedTotal）',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('閉じる'),
              ),
              ElevatedButton(
                child: const Text('会計'),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: ctx,
                    builder: (confirmCtx) {
                      return AlertDialog(
                        title: const Text('会計確認'),
                        content: const Text('本当に会計を確定しますか？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(confirmCtx, false),
                            child: const Text('キャンセル'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(confirmCtx, true),
                            child: const Text('確定'),
                          ),
                        ],
                      );
                    },
                  );
                  if (confirmed != true) return;

                  final orderSnap =
                      await FirebaseFirestore.instance
                          .collection('tables')
                          .doc(widget.tableId)
                          .collection('orders')
                          .get();
                  final items =
                      orderSnap.docs.map((d) {
                        final data = d.data();
                        return {
                          'item': data['item'],
                          'price': data['price'],
                          'status': data['status'],
                          'timestamp': data['timestamp'],
                        };
                      }).toList();
                  final batch = FirebaseFirestore.instance.batch();
                  final batchRef =
                      FirebaseFirestore.instance.collection('payments').doc();
                  batch.set(batchRef, {
                    'tableId': widget.tableId,
                    'paidAt': FieldValue.serverTimestamp(),
                    'items': items,
                  });
                  for (var d in orderSnap.docs) {
                    batch.delete(d.reference);
                  }
                  await batch.commit();

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('会計確定しました！')));
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
    );
  }
}
