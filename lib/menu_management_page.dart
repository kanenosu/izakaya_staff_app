import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/custom_bottom_nav_bar.dart'; // 追加

/// 管理画面：メニューの追加、削除、並び替えが可能（ドリンクはsubCategory別）
class AdminMenuManagementPage extends StatefulWidget {
  const AdminMenuManagementPage({Key? key}) : super(key: key);

  @override
  _AdminMenuManagementPageState createState() =>
      _AdminMenuManagementPageState();
}

class _AdminMenuManagementPageState extends State<AdminMenuManagementPage> {
  static const List<String> categories = [
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
  static const List<String> drinkSubs = [
    'ビール',
    'サワー',
    'ハイボール',
    '日本酒',
    '焼酎',
    'ワイン',
    'ソフトドリンク',
    'その他',
  ];

  String _selectedCategory = categories.first;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < -200) {
            // 予約画面があればここに
          } else if (details.primaryVelocity! > 200) {
            Navigator.pushReplacementNamed(context, '/inventory');
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'メニュー管理',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          elevation: 0,
        ),
        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: 3,
          onTap: (index) {
            switch (index) {
              case 0:
                // 予約画面へ（未実装なら何もしない or 実装時に追加）
                break;
              case 1:
                Navigator.pushReplacementNamed(context, '/');
                break;
              case 2:
                Navigator.pushReplacementNamed(context, '/inventory');
                break;
              case 3:
                // 今いる画面なので何もしない
                break;
            }
          },
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: DropdownButton<String>(
                value: _selectedCategory,
                isExpanded: true,
                items:
                    categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                // Firestore から全メニューを取得し、内部でカテゴリフィルター
                stream:
                    FirebaseFirestore.instance
                        .collection('menu_items')
                        .orderBy('order')
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting ||
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  // 選択中カテゴリでフィルタリング
                  final allDocs = snapshot.data!.docs;
                  final docs =
                      allDocs
                          .where(
                            (doc) =>
                                doc.data()['category'] == _selectedCategory,
                          )
                          .toList();

                  // ドリンクは subCategory ごとに表示
                  if (_selectedCategory == 'ドリンク') {
                    final Map<
                      String,
                      List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    >
                    subMap = {};
                    for (var doc in docs) {
                      final sub = doc.data()['subCategory'] as String? ?? 'その他';
                      subMap.putIfAbsent(sub, () => []).add(doc);
                    }
                    final subs = [
                      ...drinkSubs.where((s) => subMap.containsKey(s)),
                      ...subMap.keys.where((k) => !drinkSubs.contains(k)),
                    ];
                    return ListView(
                      padding: const EdgeInsets.all(8),
                      children:
                          subs.map((sub) {
                            final list = subMap[sub]!;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    sub,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                ReorderableListView(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  onReorder: (oldIndex, newIndex) async {
                                    if (newIndex > oldIndex) newIndex--;
                                    final moved = list.removeAt(oldIndex);
                                    list.insert(newIndex, moved);
                                    final batch =
                                        FirebaseFirestore.instance.batch();
                                    for (var i = 0; i < list.length; i++) {
                                      batch.update(list[i].reference, {
                                        'order': i,
                                      });
                                    }
                                    await batch.commit();
                                    setState(() {});
                                  },
                                  children: [
                                    for (var i = 0; i < list.length; i++)
                                      ListTile(
                                        key: ValueKey(list[i].id),
                                        title: Text(
                                          list[i].data()['name'] as String,
                                        ),
                                        subtitle: Text(
                                          '¥${list[i].data()['price']}',
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed: () async {
                                            final ok = await showDialog<bool>(
                                              context: context,
                                              builder:
                                                  (c) => AlertDialog(
                                                    title: const Text('削除確認'),
                                                    content: const Text(
                                                      '本当に削除しますか？',
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed:
                                                            () => Navigator.pop(
                                                              c,
                                                              false,
                                                            ),
                                                        child: const Text(
                                                          'キャンセル',
                                                        ),
                                                      ),
                                                      TextButton(
                                                        onPressed:
                                                            () => Navigator.pop(
                                                              c,
                                                              true,
                                                            ),
                                                        child: const Text(
                                                          '削除',
                                                          style: TextStyle(
                                                            color: Colors.red,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                            );
                                            if (ok == true) {
                                              await list[i].reference.delete();
                                              setState(() {});
                                            }
                                          },
                                        ),
                                        onTap: () => _showEditDialog(list[i]),
                                      ),
                                  ],
                                ),
                              ],
                            );
                          }).toList(),
                    );
                  }

                  // その他カテゴリ
                  return ReorderableListView(
                    onReorder: (oldIndex, newIndex) async {
                      if (newIndex > oldIndex) newIndex--;
                      final moved = docs.removeAt(oldIndex);
                      docs.insert(newIndex, moved);
                      final batch = FirebaseFirestore.instance.batch();
                      for (var i = 0; i < docs.length; i++) {
                        batch.update(docs[i].reference, {'order': i});
                      }
                      await batch.commit();
                      setState(() {});
                    },
                    children: [
                      for (var doc in docs)
                        ListTile(
                          key: ValueKey(doc.id),
                          title: Text(doc.data()['name'] as String),
                          subtitle: Text('¥${doc.data()['price']}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder:
                                    (c) => AlertDialog(
                                      title: const Text('削除確認'),
                                      content: const Text('本当に削除しますか？'),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(c, false),
                                          child: const Text('キャンセル'),
                                        ),
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(c, true),
                                          child: const Text(
                                            '削除',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                              );
                              if (ok == true) {
                                await doc.reference.delete();
                                setState(() {});
                              }
                            },
                          ),
                          onTap: () => _showEditDialog(doc),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 新規追加ダイアログ
  void _showAddDialog() {
    String name = '';
    String priceStr = '';
    String category = _selectedCategory;
    String subCategory = drinkSubs.first;
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('新規メニュー追加'),
            content: StatefulBuilder(
              builder:
                  (c, setState) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        decoration: const InputDecoration(labelText: '名前'),
                        onChanged: (v) => name = v,
                      ),
                      TextField(
                        decoration: const InputDecoration(labelText: '価格'),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => priceStr = v,
                      ),
                      DropdownButton<String>(
                        value: category,
                        isExpanded: true,
                        items:
                            categories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => setState(() => category = v!),
                      ),
                      if (category == 'ドリンク')
                        DropdownButton<String>(
                          value: subCategory,
                          isExpanded: true,
                          items:
                              drinkSubs
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) => setState(() => subCategory = v!),
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
                  final price = int.tryParse(priceStr) ?? 0;
                  final col = FirebaseFirestore.instance.collection(
                    'menu_items',
                  );
                  final snap = await col.get();
                  await col.add({
                    'name': name,
                    'price': price,
                    'category': category,
                    'subCategory': category == 'ドリンク' ? subCategory : null,
                    'order': snap.docs.length,
                  });
                  Navigator.pop(ctx);
                  setState(() {});
                },
                child: const Text('追加'),
              ),
            ],
          ),
    );
  }

  /// 編集ダイアログ
  void _showEditDialog(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    String name = doc.data()['name'] as String;
    String priceStr = (doc.data()['price'] as int).toString();
    String category = doc.data()['category'] as String;
    String subCategory =
        doc.data()['subCategory'] as String? ?? drinkSubs.first;
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('メニュー編集'),
            content: StatefulBuilder(
              builder:
                  (c, setState) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: TextEditingController(text: name),
                        decoration: const InputDecoration(labelText: '名前'),
                        onChanged: (v) => name = v,
                      ),
                      TextField(
                        controller: TextEditingController(text: priceStr),
                        decoration: const InputDecoration(labelText: '価格'),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => priceStr = v,
                      ),
                      DropdownButton<String>(
                        value: category,
                        isExpanded: true,
                        items:
                            categories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => setState(() => category = v!),
                      ),
                      if (category == 'ドリンク')
                        DropdownButton<String>(
                          value: subCategory,
                          isExpanded: true,
                          items:
                              drinkSubs
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) => setState(() => subCategory = v!),
                        ),
                    ],
                  ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder:
                        (c) => AlertDialog(
                          title: const Text('削除確認'),
                          content: const Text('本当に削除しますか？'),
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
                  if (ok == true) {
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
                  final price = int.tryParse(priceStr) ?? 0;
                  await doc.reference.update({
                    'name': name,
                    'price': price,
                    'category': category,
                    'subCategory': category == 'ドリンク' ? subCategory : null,
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
