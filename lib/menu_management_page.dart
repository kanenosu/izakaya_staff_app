import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'utils/menu_sort.dart';
import 'widgets/custom_bottom_nav_bar.dart';

/// 管理画面：メニューの追加・編集・削除・並び替え
///
/// 並び替えはカテゴリ単位（ドリンクはサブカテゴリ単位）で行い、
/// 結果は各メニューの `order` フィールドに WriteBatch で一括保存する。
/// ここで決めた順番がハンディ注文画面の表示順になる。
class AdminMenuManagementPage extends StatefulWidget {
  const AdminMenuManagementPage({super.key});

  @override
  State<AdminMenuManagementPage> createState() =>
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

  final _col = FirebaseFirestore.instance.collection('menu_items');

  String _selectedCategory = categories.first;

  /// 直近のスナップショット（新規追加時の order 計算に使う）
  List<MenuDoc> _allDocs = [];

  /// 並び替え直後のローカル上書き（docId → order）。
  /// Firestore 反映前に一瞬元の順に戻る「ちらつき」を防ぐ。
  final Map<String, int> _localOrder = {};

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity;
        if (v != null && v > 200) {
          Navigator.pushReplacementNamed(context, '/inventory');
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('メニュー管理')),
        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: 3,
          onTap: (index) {
            switch (index) {
              case 1:
                Navigator.pushReplacementNamed(context, '/');
                break;
              case 2:
                Navigator.pushReplacementNamed(context, '/inventory');
                break;
            }
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddDialog,
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('メニュー追加'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: DropdownButton<String>(
                value: _selectedCategory,
                isExpanded: true,
                items: categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  Icon(Icons.drag_indicator, size: 16, color: AppColors.inkSoft),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'ハンドルをドラッグして並び替え（ハンディ注文の表示順に反映）',
                      style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                // orderBy('order') は order 未設定のメニューを除外するため使わず、
                // 全件取得してクライアント側で並べ替える
                stream: _col.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  _allDocs = snapshot.data!.docs;
                  _pruneLocalOrder();

                  final docs = sortMenuDocs(
                    _allDocs.where(
                      (d) => d.data()['category'] == _selectedCategory,
                    ),
                    _localOrder,
                  );

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'このカテゴリにメニューはありません',
                        style: TextStyle(color: AppColors.inkSoft),
                      ),
                    );
                  }

                  // ドリンクはサブカテゴリごとに並び替え
                  if (_selectedCategory == 'ドリンク') {
                    final Map<String, List<MenuDoc>> subMap = {};
                    for (final doc in docs) {
                      final sub = doc.data()['subCategory'] as String? ?? 'その他';
                      subMap.putIfAbsent(sub, () => []).add(doc);
                    }
                    final subs = [
                      ...drinkSubs.where(subMap.containsKey),
                      ...subMap.keys.where((k) => !drinkSubs.contains(k)),
                    ];
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                      children: [
                        for (final sub in subs) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                            child: Text(
                              sub,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          _buildReorderableList(subMap[sub]!, nested: true),
                        ],
                      ],
                    );
                  }

                  return _buildReorderableList(docs);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== 並び替えリスト =====

  Widget _buildReorderableList(List<MenuDoc> items, {bool nested = false}) {
    return ReorderableListView.builder(
      shrinkWrap: nested,
      physics: nested ? const NeverScrollableScrollPhysics() : null,
      padding: nested
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(12, 4, 12, 96),
      // 既定のハンドル（PCでは右端・スマホでは長押し）は使わず、
      // 左端のハンドルから即ドラッグできるようにする
      buildDefaultDragHandles: false,
      itemCount: items.length,
      onReorder: (oldIndex, newIndex) => _onReorder(items, oldIndex, newIndex),
      proxyDecorator: (child, index, animation) => Material(
        elevation: 6,
        color: Colors.transparent,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(14),
        child: child,
      ),
      itemBuilder: (context, i) => _buildMenuTile(items[i], i),
    );
  }

  Widget _buildMenuTile(MenuDoc doc, int index) {
    final data = doc.data();
    return Padding(
      key: ValueKey(doc.id),
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.line),
          ),
          contentPadding: const EdgeInsets.only(left: 4, right: 4),
          leading: ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Icon(Icons.drag_indicator, color: AppColors.inkSoft),
            ),
          ),
          title: Text(
            data['name'] as String? ?? '',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text('¥${data['price'] ?? 0}'),
          trailing: IconButton(
            tooltip: '削除',
            icon: const Icon(Icons.delete_outline, color: AppColors.accent),
            onPressed: () => _confirmAndDelete(doc),
          ),
          onTap: () => _showEditDialog(doc),
        ),
      ),
    );
  }

  /// ドラッグ確定時：表示を即更新し、変わった order だけを一括保存
  Future<void> _onReorder(
    List<MenuDoc> items,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex--;
    if (newIndex == oldIndex) return;
    HapticFeedback.selectionClick();

    final reordered = [...items];
    reordered.insert(newIndex, reordered.removeAt(oldIndex));

    setState(() {
      for (var i = 0; i < reordered.length; i++) {
        _localOrder[reordered[i].id] = i;
      }
    });

    final batch = FirebaseFirestore.instance.batch();
    for (var i = 0; i < reordered.length; i++) {
      if (menuOrderOf(reordered[i]) != i) {
        batch.update(reordered[i].reference, {'order': i});
      }
    }
    try {
      await batch.commit();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        for (final d in reordered) {
          _localOrder.remove(d.id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('並び替えの保存に失敗しました: $e')),
      );
    }
  }

  /// Firestore 側に反映済みの上書きを取り除く
  void _pruneLocalOrder() {
    if (_localOrder.isEmpty) return;
    final byId = {for (final d in _allDocs) d.id: d};
    _localOrder.removeWhere((id, order) {
      final doc = byId[id];
      return doc == null || menuOrderOf(doc) == order;
    });
  }

  /// 指定カテゴリ（ドリンクはサブカテゴリ）の末尾に置くための order
  int _nextOrder(String category, String? subCategory) {
    var maxOrder = -1;
    for (final d in _allDocs) {
      final data = d.data();
      if (data['category'] != category) continue;
      if (category == 'ドリンク' &&
          (data['subCategory'] as String? ?? 'その他') != subCategory) {
        continue;
      }
      final o = data['order'];
      if (o is num && o.toInt() > maxOrder) maxOrder = o.toInt();
    }
    return maxOrder + 1;
  }

  // ===== 削除 =====

  Future<bool> _confirmAndDelete(MenuDoc doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${doc.data()['name']}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await doc.reference.delete();
      return true;
    }
    return false;
  }

  // ===== 新規追加 =====

  void _showAddDialog() {
    String name = '';
    String priceStr = '';
    String category = _selectedCategory;
    String subCategory = drinkSubs.first;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新規メニュー追加'),
        content: StatefulBuilder(
          builder: (c, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: '名前',
                  helperText: '略称は「正式名(略称1、略称2)」の形式で入力',
                ),
                onChanged: (v) => name = v,
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(labelText: '価格'),
                keyboardType: TextInputType.number,
                onChanged: (v) => priceStr = v,
              ),
              DropdownButton<String>(
                value: category,
                isExpanded: true,
                items: categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setDialogState(() => category = v!),
              ),
              if (category == 'ドリンク')
                DropdownButton<String>(
                  value: subCategory,
                  isExpanded: true,
                  items: drinkSubs
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => subCategory = v!),
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
              if (name.trim().isEmpty) return;
              final sub = category == 'ドリンク' ? subCategory : null;
              await _col.add({
                'name': name.trim(),
                'price': int.tryParse(priceStr) ?? 0,
                'category': category,
                'subCategory': sub,
                // 追加先カテゴリの末尾に並べる
                'order': _nextOrder(category, sub),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  // ===== 編集 =====

  void _showEditDialog(MenuDoc doc) {
    final data = doc.data();
    final nameCtrl = TextEditingController(text: data['name'] as String? ?? '');
    final priceCtrl = TextEditingController(
      text: '${(data['price'] as num?)?.toInt() ?? 0}',
    );
    final originalCategory = data['category'] as String? ?? categories.first;
    final originalSub = data['subCategory'] as String?;
    String category = originalCategory;
    String subCategory = originalSub ?? drinkSubs.first;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('メニュー編集'),
        content: StatefulBuilder(
          builder: (c, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '名前'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: '価格'),
                keyboardType: TextInputType.number,
              ),
              DropdownButton<String>(
                value: category,
                isExpanded: true,
                items: categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setDialogState(() => category = v!),
              ),
              if (category == 'ドリンク')
                DropdownButton<String>(
                  value: subCategory,
                  isExpanded: true,
                  items: drinkSubs
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => subCategory = v!),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (await _confirmAndDelete(doc) && ctx.mounted) {
                Navigator.pop(ctx);
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
              final sub = category == 'ドリンク' ? subCategory : null;
              final update = <String, dynamic>{
                'name': nameCtrl.text.trim(),
                'price': int.tryParse(priceCtrl.text) ?? 0,
                'category': category,
                'subCategory': sub,
              };
              // カテゴリを移動した場合は移動先の末尾へ
              if (category != originalCategory || sub != originalSub) {
                update['order'] = _nextOrder(category, sub);
              }
              await doc.reference.update(update);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
