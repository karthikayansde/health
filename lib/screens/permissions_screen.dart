import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/health_connect_service.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  final HealthConnectService _healthService = Get.find();
  Map<String, bool> _permissions = {};
  bool _isLoading = true;
  bool _showDeniedBanner = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() => _isLoading = true);

    final perms = await _healthService.checkPermissions();

    setState(() {
      _permissions = perms;
      _isLoading = false;
      _showDeniedBanner = perms.values.any((granted) => !granted);
    });
  }

  Future<void> _requestPermissions() async {
    setState(() => _isLoading = true);

    final granted = await _healthService.requestPermissions();

    if (granted) {
      Get.offNamed('/dashboard');
    } else {
      await _checkPermissions();
      setState(() => _showDeniedBanner = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Health Connect Permissions')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_showDeniedBanner)
                  MaterialBanner(
                    backgroundColor: Colors.orange.shade100,
                    content: const Text(
                      'Some permissions were denied. Grant all permissions to use the dashboard.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            setState(() => _showDeniedBanner = false),
                        child: const Text('DISMISS'),
                      ),
                      TextButton(
                        onPressed: () async {
                          // Offer to install Health Connect if it's missing
                          await _healthService.installHealthConnect();
                        },
                        child: const Text('INSTALL HEALTH CONNECT'),
                      ),
                    ],
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'Required Permissions',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildPermissionTile(
                        'Steps',
                        _permissions['STEPS'] ?? false,
                      ),
                      _buildPermissionTile(
                        'Heart Rate',
                        _permissions['HEART_RATE'] ?? false,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Grant Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getStatusMessage(),
                        style: TextStyle(
                          color: _allGranted() ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _requestPermissions,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Request Permissions'),
                        ),
                      ),
                      if (_allGranted()) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Get.offNamed('/dashboard'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Continue to Dashboard'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPermissionTile(String name, bool granted) {
    return Card(
      child: ListTile(
        leading: Icon(
          granted ? Icons.check_circle : Icons.cancel,
          color: granted ? Colors.green : Colors.red,
        ),
        title: Text(name),
        subtitle: Text(granted ? 'Granted' : 'Not Granted'),
        trailing: Icon(
          granted ? Icons.lock_open : Icons.lock,
          color: granted ? Colors.green : Colors.grey,
        ),
      ),
    );
  }

  bool _allGranted() {
    return _permissions.isNotEmpty &&
        _permissions.values.every((granted) => granted);
  }

  String _getStatusMessage() {
    if (_allGranted()) {
      return 'All permissions granted! You can proceed to the dashboard.';
    }

    final denied = _permissions.entries
        .where((e) => !e.value)
        .map((e) => e.key)
        .toList();

    if (denied.isEmpty) {
      return 'Please request permissions to continue.';
    }

    return 'Missing permissions: ${denied.join(", ")}';
  }
}
