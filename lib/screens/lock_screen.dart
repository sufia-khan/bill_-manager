import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_lock_service.dart';

/// Lock screen that appears when app lock is enabled
/// Supports both biometric and PIN authentication
class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final AppLockService _lockService = AppLockService();
  String _enteredPin = '';
  bool _isLoading = true;
  bool _biometricAvailable = false;
  bool _useBiometrics = false;
  String _biometricTypeName = 'Biometrics';
  bool _showError = false;
  int _failedAttempts = 0;
  static const int _maxAttempts = 5;

  @override
  void initState() {
    super.initState();
    _initLockScreen();
  }

  Future<void> _initLockScreen() async {
    final biometricAvailable = await _lockService.isBiometricAvailable();
    final useBiometrics = await _lockService.shouldUseBiometrics();
    final biometricName = await _lockService.getBiometricTypeName();

    setState(() {
      _biometricAvailable = biometricAvailable;
      _useBiometrics = useBiometrics;
      _biometricTypeName = biometricName;
      _isLoading = false;
    });

    // Auto-trigger biometric if available and enabled
    if (biometricAvailable && useBiometrics) {
      _authenticateWithBiometrics();
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    final success = await _lockService.authenticateWithBiometrics();
    if (success) {
      await _lockService.clearBackgroundTime();
      widget.onUnlocked();
    }
  }

  void _onKeyPressed(String key) {
    HapticFeedback.lightImpact();

    if (_enteredPin.length < 6) {
      setState(() {
        _enteredPin += key;
        _showError = false;
      });

      // Auto-verify when 4+ digits entered
      if (_enteredPin.length >= 4) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _showError = false;
      });
    }
  }

  Future<void> _verifyPin() async {
    final isValid = await _lockService.verifyPin(_enteredPin);

    if (isValid) {
      await _lockService.clearBackgroundTime();
      widget.onUnlocked();
    } else {
      setState(() {
        _failedAttempts++;
        _showError = true;
        _enteredPin = '';
      });

      HapticFeedback.heavyImpact();

      if (_failedAttempts >= _maxAttempts) {
        // Show lockout message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Too many failed attempts. Please try again later.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1F2937),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1F2937),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // App Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF97316),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.receipt_long,
                color: Colors.white,
                size: 40,
              ),
            ),

            const SizedBox(height: 24),

            // Title
            const Text(
              'BillMinder',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Enter your PIN to unlock',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),

            const SizedBox(height: 40),

            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                final isFilled = index < _enteredPin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled
                        ? (_showError ? Colors.red : const Color(0xFFF97316))
                        : Colors.white.withValues(alpha: 0.3),
                    border: Border.all(
                      color: _showError
                          ? Colors.red
                          : Colors.white.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                );
              }),
            ),

            if (_showError) ...[
              const SizedBox(height: 16),
              Text(
                'Incorrect PIN. ${_maxAttempts - _failedAttempts} attempts remaining.',
                style: const TextStyle(fontSize: 14, color: Colors.red),
              ),
            ],

            const Spacer(),

            // Keypad
            _buildKeypad(),

            const SizedBox(height: 20),

            // Biometric button
            if (_biometricAvailable && _useBiometrics)
              TextButton.icon(
                onPressed: _authenticateWithBiometrics,
                icon: Icon(
                  _biometricTypeName == 'Face ID'
                      ? Icons.face
                      : Icons.fingerprint,
                  color: Colors.white,
                ),
                label: Text(
                  'Use $_biometricTypeName',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3']),
        const SizedBox(height: 16),
        _buildKeypadRow(['4', '5', '6']),
        const SizedBox(height: 16),
        _buildKeypadRow(['7', '8', '9']),
        const SizedBox(height: 16),
        _buildKeypadRow(['', '0', 'backspace']),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((key) {
        if (key.isEmpty) {
          return const SizedBox(width: 80);
        }

        if (key == 'backspace') {
          return _buildKeypadButton(
            child: const Icon(Icons.backspace_outlined, color: Colors.white),
            onPressed: _onBackspace,
          );
        }

        return _buildKeypadButton(
          child: Text(
            key,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          onPressed: () => _onKeyPressed(key),
        );
      }).toList(),
    );
  }

  Widget _buildKeypadButton({
    required Widget child,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
