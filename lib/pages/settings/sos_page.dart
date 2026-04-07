import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../services/database_service.dart';

class SosPage extends StatefulWidget {
  const SosPage({super.key});

  @override
  State<SosPage> createState() => _SosPageState();
}

class _SosPageState extends State<SosPage> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _primaryContact = TextEditingController();
  final TextEditingController _medicalNote = TextEditingController();

  @override
  void initState() {
    super.initState();
    _primaryContact.text = _db.getSetting('sos_primary_contact', defaultValue: '').toString();
    _medicalNote.text = _db.getSetting('sos_medical_note', defaultValue: '').toString();
  }

  @override
  void dispose() {
    _primaryContact.dispose();
    _medicalNote.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    await _db.saveSetting('sos_primary_contact', _primaryContact.text.trim());
    await _db.saveSetting('sos_medical_note', _medicalNote.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SOS details saved')),
    );
  }

  Future<void> _copyEmergencyMessage() async {
    final message = 'SOS: I need help now. Contact: ${_primaryContact.text.trim()}. Note: ${_medicalNote.text.trim()}';
    await Clipboard.setData(ClipboardData(text: message));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Emergency message copied to clipboard')),
    );
  }

  Future<void> _callNumber(String number) async {
    final trimmed = number.trim();
    if (trimmed.isEmpty) return;
    final uri = Uri.parse('tel:$trimmed');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open dialer on this platform')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGreen,
      appBar: AppBar(title: const Text('SOS & Safety')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.red.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emergency Quick Plan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text('1. If immediate danger, call local emergency services.'),
                  Text('2. Use the copy button below and send message quickly.'),
                  Text('3. Share your location with a trusted contact.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _primaryContact,
                    decoration: const InputDecoration(
                      labelText: 'Primary emergency contact',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _medicalNote,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Medical note (allergies, conditions, meds)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saveSettings,
                          icon: const Icon(Icons.save),
                          label: const Text('Save SOS Profile'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _copyEmergencyMessage,
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy SOS Msg'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _callNumber(_primaryContact.text),
                          icon: const Icon(Icons.call),
                          label: const Text('Call Contact'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _callNumber('112'),
                          icon: const Icon(Icons.local_hospital),
                          label: const Text('Call 112'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
