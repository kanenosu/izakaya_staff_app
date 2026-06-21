// lib/payment_history_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentHistoryPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('会計履歴')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance
                .collection('payments') // 会計バッチを保存したコレクション
                .orderBy('paidAt', descending: true)
                .snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) return Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return Center(child: Text('会計履歴がありません'));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final doc = docs[i];
              final data = doc.data();
              final tableId = data['tableId'] as String? ?? '不明';

              final paidAtTs =
                  (data['paidAt'] as Timestamp?)?.toDate() ?? DateTime.now();
              final y = paidAtTs.year.toString();
              final m = paidAtTs.month.toString().padLeft(2, '0');
              final d = paidAtTs.day.toString().padLeft(2, '0');
              final hh = paidAtTs.hour.toString().padLeft(2, '0');
              final mm = paidAtTs.minute.toString().padLeft(2, '0');
              final paidAtStr = '$y/$m/$d $hh:$mm';

              // items は会計バッチ作成時に保存したリスト
              final items = List<Map<String, dynamic>>.from(
                data['items'] as List? ?? [],
              );
              final total = items.fold<int>(
                0,
                (sum, e) => sum + (e['price'] as int? ?? 0),
              );

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text('テーブル $tableId'),
                  subtitle: Text('$paidAtStr   合計 ¥$total'),
                  onTap: () {
                    // 詳細ダイアログを表示
                    showDialog(
                      context: context,
                      builder:
                          (_) => AlertDialog(
                            title: Text('テーブル $tableId の会計詳細'),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: ListView(
                                children:
                                    items.map((e) {
                                      final name = e['item'] as String? ?? '不明';
                                      final price = e['price'] as int? ?? 0;
                                      final ts =
                                          (e['timestamp'] as Timestamp?)
                                              ?.toDate() ??
                                          DateTime.now();
                                      final timeStr =
                                          '${ts.hour}:${ts.minute.toString().padLeft(2, '0')}';
                                      return ListTile(
                                        title: Text(name),
                                        subtitle: Text('¥$price   $timeStr'),
                                      );
                                    }).toList(),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('閉じる'),
                              ),
                            ],
                          ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
