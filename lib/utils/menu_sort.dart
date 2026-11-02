import 'package:cloud_firestore/cloud_firestore.dart';

typedef MenuDoc = QueryDocumentSnapshot<Map<String, dynamic>>;

/// メニューの表示順を返す。
///
/// [overrides] は並び替え直後に Firestore の反映を待たずに画面へ反映するための
/// ローカル上書き値（docId → order）。
/// `order` 未設定のメニュー（インポート直後など）は末尾に回す。
int menuOrderOf(MenuDoc doc, [Map<String, int>? overrides]) {
  final local = overrides?[doc.id];
  if (local != null) return local;
  final v = doc.data()['order'];
  return v is num ? v.toInt() : 1 << 30;
}

/// `order` 昇順（同値は名前順）で並べた新しいリストを返す。
///
/// Firestore の `orderBy('order')` は `order` フィールドを持たないドキュメントを
/// 結果から除外してしまうため、取得後にクライアント側で並べ替える。
List<MenuDoc> sortMenuDocs(
  Iterable<MenuDoc> docs, [
  Map<String, int>? overrides,
]) {
  final list = docs.toList();
  list.sort((a, b) {
    final c = menuOrderOf(a, overrides).compareTo(menuOrderOf(b, overrides));
    if (c != 0) return c;
    final an = a.data()['name'] as String? ?? '';
    final bn = b.data()['name'] as String? ?? '';
    return an.compareTo(bn);
  });
  return list;
}
