import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_lock_service.dart';

/// Settings screen for configuring App Lock (PIN/Biometric)
class AppLockSettingsScreen extends StatefulWidget {
  const AppLockSettingsScreen({super.key});

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  final AppLockService _lockService = AppLockService();

  bool _isLoading = true;
  bool _appLockEnabled = false;
  bool _useBiometrics = true;
  bool _biometricAvailable = false;
  bool _pinSet = false;
  String _biometricTypeName = 'Biometrics';
  int _lockTimeout = 30;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final appLockEnabled = await _lockService.isAppLockEnabled();
    final useBiometrics = await _lockService.shouldUseBiometrics();
    final biometricAvailable = await _lockService.isBiometricAvailable();
    final biometricName = await _lockService.getBiometricTypeName();
    final pinSet = await _lockService.isPinSet();
    final lockTimeout = await _lockService.getLockTimeout();

    setState(() {
      _appLockEnabled = appLockEnabled;
      _useBiometrics = useBiometrics;
      _biometricAvailable = biometricAvailable;
      _biometricTypeName = biometricName;
      _pinSet = pinSet;
      _lockTimeout = lockTimeout;
      _isLoading = false;
    });
  }

  Future<void> _toggleAppLock(bool value) async {
    if (value && !_pinSet) {
      // Must set PIN first
      final pinSet = await _showSetPinDialog();
      if (!pinSet) return;
    }

    await _lockService.setAppLockEnabled(value);
    setState(() {
      _appLockEnabled = value;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(value ? Icons.lock : Icons.lock_open, color: Colors.white),
              const SizedBox(width: 8),
              Text(value ? 'App Lock enabled' : 'App Lock disabled'),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleBiometrics(bool value) async {
    await _lockService.setUseBiometrics(value);
    setState(() {
      _useBiometrics = value;
    });
  }

  Future<void> _setLockTimeout(int seconds) async {
    await _lockService.setLockTimeout(seconds);
    setState(() {
      _lockTimeout = seconds;
    });
    if (mounted) Navigator.pop(context);
  }

  Future<bool> _showSetPinDialog() async {
    String pin = '';
    String confirmPin = '';
    bool isConfirming = false;
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.pin, color: Color(0xFFF97316)),
              const SizedBox(width: 12),
              Text(isConfirming ? 'Confirm PIN' : 'Set PIN'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isConfirming
                    ? 'Enter your PIN again to confirm'
                    : 'Enter a 4-6 digit PIN',
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 20),
              TextField(
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) {
                  if (isConfirming) {
                    confirmPin = value;
                  } else {
                    pin = value;
                  }
                  setDialogState(() {
                    errorText = null;
                  });
                },
                decoration: InputDecoration(
                  counterText: '',
                  errorText: errorText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFF97316),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!isConfirming) {
                  if (pin.length < 4) {
                    setDialogState(() {
                      errorText = 'PIN must be at least 4 digits';
                    });
                    return;
                  }
                  setDialogState(() {
                    isConfirming = true;
                    errorText = null;
                  });
                } else {
                  if (confirmPin != pin) {
                    setDialogState(() {
                      errorText = 'PINs do not match';
                    });
                    return;
                  }
                  await _lockService.setPin(pin);
                  if (context.mounted) Navigator.pop(context, true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
              ),
              child: Text(isConfirming ? 'Confirm' : 'Next'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      setState(() {
        _pinSet = true;
      });
    }

    return result ?? false;
  }

  void _showTimeoutPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Lock Timeout',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            _buildTimeoutOption(0, 'Immediately'),
            _buildTimeoutOption(30, '30 seconds'),
            _buildTimeoutOption(60, '1 minute'),
            _buildTimeoutOption(300, '5 minutes'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeoutOption(int seconds, String label) {
    final isSelected = _lockTimeout == seconds;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? const Color(0xFFF97316) : const Color(0xFF6B7280),
      ),
      title: Text(label),
      onTap: () => _setLockTimeout(seconds),
    );
  }

  String _formatTimeout(int seconds) {
    if (seconds == 0) return 'Immediately';
    if (seconds < 60) return '$seconds seconds';
    final minutes = seconds ~/ 60;
    return '$minutes minute${minutes > 1 ? 's' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFF97316)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'App Lock',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFFF97316),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFFF97316),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enable App Lock
            _buildSwitchTile(
              icon: Icons.lock_outline,
              title: 'Enable App Lock',
              subtitle: 'Require authentication to open the app',
              value: _appLockEnabled,
              onChanged: _toggleAppLock,
            ),

            const SizedBox(height: 24),

            // Biometrics Option (only if available and lock enabled)
            if (_biometricAvailable) ...[
              _buildSwitchTile(
                icon: _biometricTypeName == 'Face ID'
                    ? Icons.face
                    : Icons.fingerprint,
                title: 'Use $_biometricTypeName',
                subtitle: 'Unlock with $_biometricTypeName instead of PIN',
                value: _useBiometrics,
                onChanged: _appLockEnabled ? _toggleBiometrics : null,
                enabled: _appLockEnabled,
              ),
              const SizedBox(height: 24),
            ],

            // Change PIN
            _buildActionTile(
              icon: Icons.pin,
              title: 'Change PIN',
              subtitle: _pinSet ? 'Update your current PIN' : 'Set a new PIN',
              onTap: _appLockEnabled ? _showSetPinDialog : null,
              enabled: _appLockEnabled,
            ),

            const SizedBox(height: 24),

            // Lock Timeout
            _buildActionTile(
              icon: Icons.timer_outlined,
              title: 'Lock Timeout',
              subtitle: _formatTimeout(_lockTimeout),
              onTap: _appLockEnabled ? _showTimeoutPicker : null,
              enabled: _appLockEnabled,
            ),

            const SizedBox(height: 32),

            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFF97316).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFFF97316),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'When enabled, you\'ll need to authenticate after the app has been in the background for the timeout duration.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool)? onChanged,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 24, color: const Color(0xFFF97316)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeColor: const Color(0xFFF97316),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 24, color: const Color(0xFFF97316)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF6B7280)),
            ],
          ),
        ),
      ),
    );
  }
}
