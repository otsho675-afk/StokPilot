import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/smart_inventory.dart';
import '../services/app_api.dart';
import 'ui.dart';

class InventoryAlertSelection {
  const InventoryAlertSelection(this.alert, this.product);

  final InventoryAlert alert;
  final QueryDocumentSnapshot<Map<String, dynamic>> product;
}

class InventoryAlertButton extends StatelessWidget {
  const InventoryAlertButton({super.key, required this.onSelected});

  final ValueChanged<InventoryAlertSelection> onSelected;

  Future<void> _showAlerts(
    BuildContext context,
    List<InventoryAlertSelection> alerts,
  ) async {
    final height = MediaQuery.sizeOf(context).height;
    Widget content(BuildContext routeContext) => Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: (height * .72).clamp(280, 540),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 10),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_outlined, color: green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Hatırlatıcılar (${alerts.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.pop(routeContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: line),
            Expanded(
              child:
                  alerts.isEmpty
                      ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Şu an stok veya fiyat hatırlatıcısı yok.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: muted),
                          ),
                        ),
                      )
                      : ListView.separated(
                        itemCount: alerts.length,
                        separatorBuilder:
                            (_, _) => const Divider(height: 1, color: line),
                        itemBuilder: (context, index) {
                          final selection = alerts[index];
                          final stock = selection.alert.kind == 'stock';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  stock ? const Color(0xFFFFF1DB) : softGreen,
                              child: Icon(
                                stock
                                    ? Icons.inventory_2_outlined
                                    : Icons.price_change_outlined,
                                color: stock ? amber : green,
                              ),
                            ),
                            title: Text(
                              selection.alert.productName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(selection.alert.message),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => Navigator.pop(routeContext, selection),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );

    final selected =
        MediaQuery.sizeOf(context).width < 600
            ? await showModalBottomSheet<InventoryAlertSelection>(
              context: context,
              useSafeArea: true,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: content,
            )
            : await showDialog<InventoryAlertSelection>(
              context: context,
              builder:
                  (routeContext) => Dialog(
                    insetPadding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: content(routeContext),
                    ),
                  ),
            );
    if (selected != null) onSelected(selected);
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: AppApi.instance.watch('products'),
    builder:
        (
          context,
          products,
        ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream:
              AppApi.instance.collection('settings').doc('alerts').snapshots(),
          builder: (context, settings) {
            final preferences =
                settings.data?.data() ?? const <String, dynamic>{};
            final days =
                (preferences['priceReminderDays'] as num?)?.toInt() ?? 45;
            final stockEnabled = preferences['lowStockAlerts'] != false;
            final documents = {
              for (final doc
                  in products.data?.docs ??
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                doc.id: doc,
            };
            final entries = documents.values.map((doc) {
              final data = Map<String, dynamic>.from(doc.data());
              final date = data['priceChangedAt'] ?? data['createdAt'];
              if (date is Timestamp) data['priceChangedAt'] = date.toDate();
              return MapEntry(doc.id, data);
            });
            final alerts =
                inventoryAlerts(
                      entries,
                      now: DateTime.now(),
                      priceReminderDays: days,
                    )
                    .where((alert) => stockEnabled || alert.kind != 'stock')
                    .map(
                      (alert) => InventoryAlertSelection(
                        alert,
                        documents[alert.productId]!,
                      ),
                    )
                    .toList();
            return IconButton(
              tooltip:
                  alerts.isEmpty
                      ? 'Hatırlatıcılar'
                      : '${alerts.length} hatırlatıcı',
              onPressed: () => _showAlerts(context, alerts),
              icon: Badge(
                isLabelVisible: alerts.isNotEmpty,
                label: Text(alerts.length > 99 ? '99+' : '${alerts.length}'),
                child: const Icon(Icons.notifications_none_rounded),
              ),
            );
          },
        ),
  );
}
