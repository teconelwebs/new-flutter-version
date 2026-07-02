import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/profile_api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ProfileApiService();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();

  bool _loading = true;
  bool _updating = false;
  String _phone = '';
  String _gender = '';
  String _marital = '';

  static const _genders = ['', 'Male', 'Female', 'Other'];
  static const _maritalOptions = ['', 'Single', 'Married', 'Divorced', 'Widowed'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile = await _api.fetchProfile();
      if (!mounted) return;
      if (profile == null) {
        setState(() => _loading = false);
        return;
      }
      _nameCtrl.text = profile.name;
      _emailCtrl.text = profile.email;
      _dobCtrl.text = profile.dob;
      setState(() {
        _phone = profile.phone;
        _gender = profile.gender;
        _marital = profile.maritalStatus;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDob() async {
    final existing = _parseDob(_dobCtrl.text.trim());
    final picked = await showDatePicker(
      context: context,
      initialDate: existing ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    final day = picked.day.toString().padLeft(2, '0');
    final month = picked.month.toString().padLeft(2, '0');
    setState(() => _dobCtrl.text = '$day-$month-${picked.year}');
  }

  DateTime? _parseDob(String value) {
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  Future<void> _update() async {
    final email = _emailCtrl.text.trim();
    if (email.isNotEmpty) {
      final emailOk = RegExp(r'^[a-zA-Z0-9._+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
          .hasMatch(email);
      if (!emailOk) {
        _showMessage('Please enter a valid email address');
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    final userId = prefs.getString('user_id') ?? '';
    if (token.isEmpty || userId.isEmpty) {
      _showMessage('User not authenticated');
      return;
    }

    setState(() => _updating = true);
    try {
      final error = await _api.updateProfile(
        userId: userId,
        accessToken: token,
        name: _nameCtrl.text.trim(),
        email: email,
        dobDisplay: _dobCtrl.text.trim(),
        gender: _gender,
        maritalStatus: _marital,
      );
      if (!mounted) return;
      if (error != null) {
        _showMessage(error);
        return;
      }
      await prefs.setString('user_name', _nameCtrl.text.trim());
      await prefs.setString('loginuser', _nameCtrl.text.trim());
      _showMessage('Profile updated successfully.', success: true);
    } catch (_) {
      if (mounted) _showMessage('An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  void _showMessage(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? const Color(0xFF16A34A) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0.5,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _fieldLabel('Name'),
                TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDecoration('Your name'),
                ),
                const SizedBox(height: 14),
                _fieldLabel('Mobile'),
                TextFormField(
                  initialValue: _phone,
                  enabled: false,
                  decoration: _inputDecoration('Mobile number'),
                ),
                const SizedBox(height: 14),
                _fieldLabel('Email'),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration('Email address'),
                ),
                const SizedBox(height: 14),
                _fieldLabel('Date of Birth'),
                TextField(
                  controller: _dobCtrl,
                  readOnly: true,
                  onTap: _pickDob,
                  decoration: _inputDecoration('DD-MM-YYYY').copyWith(
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                _fieldLabel('Gender'),
                DropdownButtonFormField<String>(
                  initialValue: _genders.contains(_gender) ? _gender : '',
                  items: _genders
                      .map(
                        (g) => DropdownMenuItem(
                          value: g,
                          child: Text(g.isEmpty ? 'Select gender' : g),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _gender = v ?? ''),
                  decoration: _inputDecoration('Gender'),
                ),
                const SizedBox(height: 14),
                _fieldLabel('Marital Status'),
                DropdownButtonFormField<String>(
                  initialValue: _maritalOptions.contains(_marital) ? _marital : '',
                  items: _maritalOptions
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(m.isEmpty ? 'Select status' : m),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _marital = v ?? ''),
                  decoration: _inputDecoration('Marital status'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _updating ? null : _update,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFB5404),
                    ),
                    child: _updating
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'UPDATE PROFILE',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
    );
  }
}
