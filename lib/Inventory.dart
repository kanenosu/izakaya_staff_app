import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/custom_bottom_nav_bar.dart'; // 追加

/// 在庫管理ページ：カテゴリ別フィルタ＋アイテム毎閾値設定＋在庫数増減＋優先表示
class InventoryManagementPage extends StatefulWidget {
  const InventoryManagementPage({Key? key}) : super(key: key);

  @override
  _InventoryManagementPageState createState() =>
      _InventoryManagementPageState();
}

class _InventoryManagementPageState extends State<InventoryManagementPage> {
  String _filterCategory = 'All';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < -200) {
            Navigator.pushReplacementNamed(context, '/menu');
          } else if (details.primaryVelocity! > 200) {
            Navigator.pushReplacementNamed(context, '/');
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            '在庫管理',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 28),
              tooltip: '在庫アイテム追加',
              onPressed: _showAddDialog,
            ),
          ],
          elevation: 0,
        ),
        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: 2,
          onTap: (index) {
            switch (index) {
              case 0:
                // 予約画面へ（未実装なら何もしない or 実装時に追加）
                break;
              case 1:
                Navigator.pushReplacementNamed(context, '/');
                break;
              case 2:
                // 今いる画面なので何もしない
                break;
              case 3:
                Navigator.pushReplacementNamed(context, '/menu');
                break;
            }
          },
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream:
              FirebaseFirestore.instance
                  .collection('inventory_items')
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return Center(child: Text('エラー: ${snapshot.error}'));
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());

            final allDocs = snapshot.data!.docs;
            final cats = <String>{
              for (var d in allDocs) d.data()['category'] as String? ?? '',
            };
            final filterCats = ['All', ...cats.toList()..sort()];

            var docs =
                _filterCategory == 'All'
                    ? List.of(allDocs)
                    : allDocs
                        .where((d) => d.data()['category'] == _filterCategory)
                        .toList();

            docs.sort((a, b) {
              final da = a.data();
              final db = b.data();
              final aQty = (da['quantity'] as num?)?.toInt() ?? 0;
              final bQty = (db['quantity'] as num?)?.toInt() ?? 0;
              final aTh = (da['threshold'] as num?)?.toInt() ?? 0;
              final bTh = (db['threshold'] as num?)?.toInt() ?? 0;
              final aBelow = aQty <= aTh ? 0 : 1;
              final bBelow = bQty <= bTh ? 0 : 1;
              if (aBelow != bBelow) return aBelow.compareTo(bBelow);
              return da['name'].toString().compareTo(db['name'].toString());
            });

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _filterCategory,
                          isExpanded: true,
                          borderRadius: BorderRadius.circular(16),
                          items:
                              filterCats
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (v) => setState(() => _filterCategory = v!),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child:
                      docs.isEmpty
                          ? const Center(
                            child: Text(
                              'アイテムがありません',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                          : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            itemCount: docs.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final doc = docs[index];
                              final data = doc.data();
                              final name = data['name'] as String? ?? '';
                              final category =
                                  data['category'] as String? ?? '';
                              final qty =
                                  (data['quantity'] as num?)?.toInt() ?? 0;
                              final unit = data['unit'] as String? ?? '';
                              final th =
                                  (data['threshold'] as num?)?.toInt() ?? 0;
                              final isLow = qty <= th;

                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                color:
                                    isLow
                                        ? Colors.red[50]
                                        : Theme.of(context).colorScheme.surface,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        isLow
                                            ? Colors.red[200]
                                            : Colors.blue[100],
                                    child: Icon(
                                      isLow ? Icons.warning : Icons.inventory_2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isLow
                                              ? Colors.red[700]
                                              : Colors.black87,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '$category  • 在庫: $qty $unit  (閾値: $th)',
                                    style: TextStyle(
                                      color:
                                          isLow
                                              ? Colors.red[400]
                                              : Colors.grey[700],
                                      fontSize: 13,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: Colors.blue,
                                        ),
                                        onPressed:
                                            qty > 0
                                                ? () => doc.reference.update({
                                                  'quantity':
                                                      FieldValue.increment(-1),
                                                })
                                                : null,
                                        tooltip: '減らす',
                                      ),
                                      Text(
                                        '$qty',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                          color: Colors.blue,
                                        ),
                                        onPressed:
                                            () => doc.reference.update({
                                              'quantity': FieldValue.increment(
                                                1,
                                              ),
                                            }),
                                        tooltip: '増やす',
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.green,
                                        ),
                                        onPressed: () => _showEditDialog(doc),
                                        tooltip: '編集',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showAddDialog() {
    String name = '';
    String category = '';
    String qtyStr = '';
    String unit = '';
    String thStr = '0';
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('在庫アイテム追加'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: 'アイテム名'),
                    onChanged: (v) => name = v,
                  ),
                  TextField(
                    decoration: const InputDecoration(labelText: 'カテゴリ'),
                    onChanged: (v) => category = v,
                  ),
                  TextField(
                    decoration: const InputDecoration(labelText: '数量'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => qtyStr = v,
                  ),
                  TextField(
                    decoration: const InputDecoration(labelText: '単位'),
                    onChanged: (v) => unit = v,
                  ),
                  TextField(
                    decoration: const InputDecoration(labelText: '閾値'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => thStr = v,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final qty = int.tryParse(qtyStr) ?? 0;
                  final th = int.tryParse(thStr) ?? 0;
                  await FirebaseFirestore.instance
                      .collection('inventory_items')
                      .add({
                        'name': name,
                        'category': category,
                        'quantity': qty,
                        'unit': unit,
                        'threshold': th,
                      });
                  Navigator.pop(ctx);
                },
                child: const Text('追加'),
              ),
            ],
          ),
    );
  }

  void _showEditDialog(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    var data = doc.data();
    String name = data['name'] as String? ?? '';
    String category = data['category'] as String? ?? '';
    String qtyStr = (data['quantity'] as num?)?.toString() ?? '';
    String unit = data['unit'] as String? ?? '';
    String thStr = (data['threshold'] as num?)?.toString() ?? '';
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('在庫アイテム編集'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: TextEditingController(text: name),
                    decoration: const InputDecoration(labelText: 'アイテム名'),
                    onChanged: (v) => name = v,
                  ),
                  TextField(
                    controller: TextEditingController(text: category),
                    decoration: const InputDecoration(labelText: 'カテゴリ'),
                    onChanged: (v) => category = v,
                  ),
                  TextField(
                    controller: TextEditingController(text: qtyStr),
                    decoration: const InputDecoration(labelText: '数量'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => qtyStr = v,
                  ),
                  TextField(
                    controller: TextEditingController(text: unit),
                    decoration: const InputDecoration(labelText: '単位'),
                    onChanged: (v) => unit = v,
                  ),
                  TextField(
                    controller: TextEditingController(text: thStr),
                    decoration: const InputDecoration(labelText: '閾値'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => thStr = v,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder:
                        (c) => AlertDialog(
                          title: const Text('削除確認'),
                          content: const Text('このアイテムを完全に削除しますか？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('キャンセル'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text(
                                '削除',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                  );
                  if (confirm == true) {
                    await doc.reference.delete();
                    Navigator.pop(ctx);
                    setState(() {});
                  }
                },
                child: const Text('削除', style: TextStyle(color: Colors.red)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final qty = int.tryParse(qtyStr) ?? 0;
                  final th = int.tryParse(thStr) ?? 0;
                  await doc.reference.update({
                    'name': name,
                    'category': category,
                    'quantity': qty,
                    'unit': unit,
                    'threshold': th,
                  });
                  Navigator.pop(ctx);
                  setState(() {});
                },
                child: const Text('保存'),
              ),
            ],
          ),
    );
  }
}
