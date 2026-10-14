import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'auth_page.dart';
import 'paywall_page.dart';
import 'legal_page.dart';
import '../services/app_api.dart';
import '../widgets/ui.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const PageTitle(
        title: 'İşletme ayarları',
        subtitle:
            'Hesap, abonelik ve işletme tercihlerini yönetin.',
      ),
      const _AlertSettings(),
      const SizedBox(height: 18),
      DataPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Üyelik ve abonelik',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              'Ücretsiz planda 50 ürün • StokPilot Pro sınırsız ürün • Türkiye hedefi 50 TL/ay',
            ),
            const SizedBox(height: 10),
            FilledButton.tonal(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PaywallPage()),
                  ),
              child: const Text('Pro aylık aboneliği görüntüle'),
            ),
            if (FirebaseAuth.instance.currentUser?.isAnonymous ?? false) ...[
              const SizedBox(height: 10),
              const Text(
                'Misafir hesabını kalıcı hesaba bağla (mevcut veriler korunur):',
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      try {
                        await AuthActions.google(link: true);
                        if (context.mounted) {
                          notify(context, 'Google hesabına bağlandı.');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          notify(
                            context,
                            AuthActions.errorMessage(e),
                            error: true,
                          );
                        }
                      }
                    },
                    child: const Text('Google ile bağla'),
                  ),
                  if (kIsWeb || Platform.isIOS)
                    OutlinedButton(
                      onPressed: () async {
                        try {
                          await AuthActions.apple(link: true);
                          if (context.mounted) {
                            notify(context, 'Apple hesabına bağlandı.');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            notify(
                              context,
                              AuthActions.errorMessage(e),
                              error: true,
                            );
                          }
                        }
                      },
                      child: const Text('Apple ile bağla'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 18),
      DataPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Veri ve güvenlik',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 7),
            const Text(
              'Veriler Firebase Firestore üzerinde hesabınıza ait işletme alanında saklanır. Kullanıcılar diğer işletmelerin kayıtlarını okuyamaz. Stok ve cari hareketleri Firestore transaction ile kaydedilir. Her hesap sadece kendi verilerine erişebilir.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => const LegalPage(privacy: true),
                        ),
                      ),
                  child: const Text('Gizlilik'),
                ),
                TextButton(
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => const LegalPage(privacy: false),
                        ),
                      ),
                  child: const Text('Koşullar'),
                ),
                OutlinedButton(
                  onPressed: () => requestAccountDeletion(context),
                  child: const Text(
                    'Hesabı kalıcı sil',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

class _AlertSettings extends StatelessWidget {
  const _AlertSettings();

  Future<void> _save(BuildContext context, int days, bool lowStock) async {
    try {
      await AppApi.instance.collection('settings').doc('alerts').set({
        'priceReminderDays': days,
        'lowStockAlerts': lowStock,
      });
    } catch (error) {
      if (context.mounted) {
        notify(context, 'Hatırlatıcı kaydedilemedi: $error', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => DataPanel(
    child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: AppApi.instance.collection('settings').doc('alerts').snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final days = (data['priceReminderDays'] as num?)?.toInt() ?? 45;
        final lowStock = data['lowStockAlerts'] != false;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Akıllı hatırlatıcılar',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              'Stok ve güncellenmeyen fiyatları Ürünler ekranında gösterir.',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey('price-days-$days'),
              initialValue: days,
              decoration: const InputDecoration(
                labelText: 'Fiyat kontrol aralığı',
              ),
              items:
                  const [30, 45, 60, 90, 180]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value gün'),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) _save(context, value, lowStock);
              },
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Kritik stok uyarıları'),
              value: lowStock,
              onChanged: (value) => _save(context, days, value),
            ),
          ],
        );
      },
    ),
  );
}

class MasterData extends StatelessWidget {
  const MasterData({
    required this.title,
    required this.collection,
    required this.subtitle,
    required this.icon,
  });
  final String title, collection, subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => DataPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: green),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              icon: const Icon(Icons.add),
              tooltip: 'Yeni ekle',
              onPressed: () => masterDialog(context, collection),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: AppApi.instance.watch(collection),
          builder: (context, snap) {
            if (!snap.hasData) return const LinearProgressIndicator();
            if (snap.data!.docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(10),
                child: Text('Henüz kayıt yok. + ile ekleyin.'),
              );
            }
            return Column(
              children:
                  snap.data!.docs
                      .map(
                        (d) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(d.data()['name'] ?? ''),
                          subtitle:
                              collection == 'units'
                                  ? Text('Sembol: ${d.data()['symbol'] ?? ''}')
                                  : (collection == 'taxRates'
                                      ? Text(
                                        'Oran: %${((d.data()['rateBps'] ?? 0) / 100).toStringAsFixed(2)}',
                                      )
                                      : null),
                          trailing: PopupMenuButton<String>(
                            onSelected: (choice) async {
                              if (choice == 'edit') {
                                masterDialog(context, collection, item: d);
                              } else if (choice == 'delete' &&
                                  await confirm(
                                    context,
                                    'Silinsin mi?',
                                    'Bu kayıt bir ürüne bağlıysa eski kayıtlarda referansı kalabilir.',
                                  )) {
                                try {
                                  await AppApi.instance
                                      .collection(collection)
                                      .doc(d.id)
                                      .delete();
                                } catch (e) {
                                  if (context.mounted) {
                                    notify(context, '$e', error: true);
                                  }
                                }
                              }
                            },
                            itemBuilder:
                                (ctx) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Düzenle'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Sil'),
                                  ),
                                ],
                          ),
                        ),
                      )
                      .toList(),
            );
          },
        ),
      ],
    ),
  );
}

Future<void> masterDialog(
  BuildContext context,
  String collection, {
  QueryDocumentSnapshot<Map<String, dynamic>>? item,
}) async {
  final data = item?.data();
  final name = TextEditingController(text: data?['name'] ?? ''),
      other = TextEditingController(
        text:
            collection == 'units'
                ? (data?['symbol'] ?? '')
                : (data == null
                    ? '20'
                    : ((data['rateBps'] ?? 0) / 100).toString().replaceAll(
                      '.',
                      ',',
                    )),
      );
  bool saving = false;
  await showOwnedDialog<void>(
    context: context,
    controllers: [name, other],
    builder:
        (dc) => StatefulBuilder(
          builder:
              (context, update) => ResponsiveFormDialog(
                title: Text(item == null ? 'Yeni kayıt' : 'Kaydı düzenle'),
                content: SizedBox(
                  width: 360,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: name,
                        decoration: InputDecoration(
                          labelText:
                              collection == 'taxRates'
                                  ? 'KDV adı (ör. Genel %20)'
                                  : 'Ad *',
                        ),
                      ),
                      if (collection != 'categories') ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: other,
                          keyboardType:
                              collection == 'taxRates'
                                  ? TextInputType.number
                                  : TextInputType.text,
                          decoration: InputDecoration(
                            labelText:
                                collection == 'units'
                                    ? 'Sembol (ör. ad, kg, koli)'
                                    : 'KDV oranı (%)',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dc),
                    child: const Text('İptal'),
                  ),
                  FilledButton(
                    onPressed:
                        saving
                            ? null
                            : () async {
                              try {
                                if (name.text.trim().isEmpty) {
                                  throw const FormatException('Ad zorunlu.');
                                }
                                final values = <String, dynamic>{
                                  'name': name.text.trim(),
                                };
                                if (collection == 'units') {
                                  values['symbol'] = other.text.trim();
                                }
                                if (collection == 'taxRates') {
                                  final rate = double.tryParse(
                                    other.text.replaceAll(',', '.'),
                                  );
                                  if (rate == null ||
                                      !rate.isFinite ||
                                      rate < 0 ||
                                      rate > 100) {
                                    throw const FormatException(
                                      'KDV 0 ile 100 arasında olmalı.',
                                    );
                                  }
                                  values['rateBps'] = (rate * 100).round();
                                }
                                update(() => saving = true);
                                if (item == null) {
                                  await AppApi.instance.create(
                                    collection,
                                    values,
                                  );
                                } else {
                                  await AppApi.instance.edit(
                                    collection,
                                    item.id,
                                    values,
                                  );
                                }
                                if (dc.mounted) Navigator.pop(dc);
                              } catch (e) {
                                if (context.mounted) {
                                  notify(context, '$e', error: true);
                                }
                                update(() => saving = false);
                              }
                            },
                    child: const Text('Kaydet'),
                  ),
                ],
              ),
        ),
  );
}
