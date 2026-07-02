import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../home/presentation/home_screen.dart';

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  static const routeName = AppRoutes.address;

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final _houseCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _cityCtrl = TextEditingController(text: 'Indore');

  @override
  void dispose() {
    _houseCtrl.dispose();
    _areaCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery address')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Where should we deliver?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add your address once. You can edit it later from profile.',
            style: TextStyle(color: Color(0xFF6E7380)),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _houseCtrl,
            decoration: const InputDecoration(labelText: 'House / Flat / Building'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _areaCtrl,
            decoration: const InputDecoration(labelText: 'Area / Landmark'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cityCtrl,
            decoration: const InputDecoration(labelText: 'City'),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.my_location_rounded),
            label: const Text('Use current location'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pushReplacementNamed(HomeScreen.routeName);
            },
            child: const Text('Save & Continue'),
          ),
        ],
      ),
    );
  }
}
