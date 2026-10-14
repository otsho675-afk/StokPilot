import 'package:flutter/material.dart';
import '../widgets/ui.dart';
import 'settings_page.dart';

class CatalogManagementPage extends StatelessWidget {
  const CatalogManagementPage({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PageTitle(
        title: 'Kategori ve birimler',
        subtitle: 'Ürün kategorilerini, ölçü birimlerini ve KDV oranlarını yönetin.',
      ),
      MasterData(
        title: 'Kategoriler',
        collection: 'categories',
        subtitle: 'Ürünleri gruplayın ve aramayı kolaylaştırın.',
        icon: Icons.category_outlined,
      ),
      SizedBox(height: 16),
      MasterData(
        title: 'Birimler',
        collection: 'units',
        subtitle: 'Adet, koli, paket, kilogram, litre...',
        icon: Icons.straighten_outlined,
      ),
      SizedBox(height: 16),
      MasterData(
        title: 'KDV oranları',
        collection: 'taxRates',
        subtitle: 'Ürünler için vergi oranları.',
        icon: Icons.percent_outlined,
      ),
    ],
  );
}
